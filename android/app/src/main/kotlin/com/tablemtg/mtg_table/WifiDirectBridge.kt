package com.tablemtg.mtg_table

import android.Manifest
import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pInfo
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

/// Groupe Wi-Fi Direct pour quatre téléphones, quand le Wi-Fi du lieu les isole.
class WifiDirectBridge(private val activity: FlutterActivity) {
    private val handler = Handler(Looper.getMainLooper())
    private var manager: WifiP2pManager? = null
    private var channel: WifiP2pManager.Channel? = null
    private var receiver: BroadcastReceiver? = null
    private var pending: MethodChannel.Result? = null
    private var afterPermission: (() -> Unit)? = null
    private var permissionResult: MethodChannel.Result? = null
    private var timeout: Runnable? = null

    fun handle(call: String, result: MethodChannel.Result, address: String?): Boolean {
        when (call) {
            "directStart" -> ensure(result) { startGroup(result) }
            "directDiscover" -> ensure(result) { discover(result) }
            "directConnect" -> {
                val target = address
                if (target.isNullOrEmpty()) {
                    result.error("failed", "adresse", null)
                } else {
                    ensure(result) { connect(target, result) }
                }
            }
            "directStop", "stopTableNet" -> {
                stop()
                result.success(null)
            }
            else -> return false
        }
        return true
    }

    fun onPermissionResult(requestCode: Int, grants: IntArray) {
        if (requestCode != requestCodeId) return
        val block = afterPermission
        afterPermission = null
        val granted = grants.isNotEmpty() && grants.all { it == PackageManager.PERMISSION_GRANTED }
        if (!granted) {
            permissionResult?.error("denied", "permission", null)
            permissionResult = null
            return
        }
        permissionResult = null
        block?.invoke()
    }

    fun stop() {
        cancelPending(null)
        val p2p = manager
        val link = channel
        if (p2p != null && link != null) {
            p2p.cancelConnect(link, null)
            p2p.removeGroup(link, null)
        }
        unregister()
    }

    private fun ensure(result: MethodChannel.Result, block: () -> Unit) {
        val missing = missingPermissions()
        if (missing.isEmpty()) {
            block()
            return
        }
        afterPermission = block
        permissionResult = result
        activity.requestPermissions(missing.toTypedArray(), requestCodeId)
    }

    private fun missingPermissions(): List<String> {
        val need = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= 33) {
            if (activity.checkSelfPermission(Manifest.permission.NEARBY_WIFI_DEVICES)
                != PackageManager.PERMISSION_GRANTED
            ) {
                need += Manifest.permission.NEARBY_WIFI_DEVICES
            }
        } else if (activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            need += Manifest.permission.ACCESS_FINE_LOCATION
        }
        return need
    }

    @SuppressLint("MissingPermission")
    private fun startGroup(result: MethodChannel.Result) {
        val p2p = p2p() ?: return fail(result, "unsupported")
        val link = p2pChannel(p2p) ?: return fail(result, "unsupported")
        hold(result)
        p2p.removeGroup(link, object : WifiP2pManager.ActionListener {
            override fun onSuccess() = create(p2p, link)
            override fun onFailure(reason: Int) = create(p2p, link)
        })
    }

    @SuppressLint("MissingPermission")
    private fun create(p2p: WifiP2pManager, link: WifiP2pManager.Channel) {
        p2p.createGroup(link, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                readOwner(p2p, link, 0)
            }

            override fun onFailure(reason: Int) {
                finish(null, "failed")
            }
        })
    }

    @SuppressLint("MissingPermission")
    private fun readOwner(p2p: WifiP2pManager, link: WifiP2pManager.Channel, attempt: Int) {
        p2p.requestConnectionInfo(link) { info ->
            val address = ownerAddress(info)
            if (address == null && attempt < 5) {
                handler.postDelayed({ readOwner(p2p, link, attempt + 1) }, 400)
                return@requestConnectionInfo
            }
            p2p.requestGroupInfo(link) { group ->
                val payload = hashMapOf<String, String?>(
                    "address" to (address ?: "192.168.49.1"),
                    "ssid" to group?.networkName,
                    "pass" to if (Build.VERSION.SDK_INT >= 29) group?.passphrase else null,
                )
                finish(payload, null)
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun discover(result: MethodChannel.Result) {
        val p2p = p2p() ?: return fail(result, "unsupported")
        val link = p2pChannel(p2p) ?: return fail(result, "unsupported")
        hold(result)
        register()
        p2p.discoverPeers(link, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                handler.postDelayed({
                    p2p.requestPeers(link) { list ->
                        val found = ArrayList<Map<String, String>>()
                        for (device in list.deviceList) {
                            val name = device.deviceName?.takeIf { it.isNotBlank() }
                                ?: device.deviceAddress
                            found += mapOf(
                                "name" to name,
                                "address" to device.deviceAddress,
                            )
                        }
                        finish(found, null)
                    }
                }, 3500)
            }

            override fun onFailure(reason: Int) {
                finish(null, "failed")
            }
        })
    }

    @SuppressLint("MissingPermission")
    private fun connect(address: String, result: MethodChannel.Result) {
        val p2p = p2p() ?: return fail(result, "unsupported")
        val link = p2pChannel(p2p) ?: return fail(result, "unsupported")
        hold(result)
        register()
        val config = WifiP2pConfig().apply { deviceAddress = address }
        p2p.connect(link, config, object : WifiP2pManager.ActionListener {
            override fun onSuccess() = Unit

            override fun onFailure(reason: Int) {
                finish(null, "failed")
            }
        })
    }

    private fun p2p(): WifiP2pManager? {
        val existing = manager
        if (existing != null) return existing
        val resolved = activity.applicationContext.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
        manager = resolved
        return resolved
    }

    private fun p2pChannel(p2p: WifiP2pManager): WifiP2pManager.Channel? {
        val existing = channel
        if (existing != null) return existing
        val opened = p2p.initialize(activity, activity.mainLooper, null) ?: return null
        channel = opened
        return opened
    }

    private fun register() {
        if (receiver != null) return
        val filter = IntentFilter().apply {
            addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
        }
        val next = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION) return
                val info = parcelInfo(intent) ?: return
                if (!info.groupFormed) return
                val owner = ownerAddress(info) ?: return
                if (pending != null) finish(owner, null)
            }
        }
        receiver = next
        if (Build.VERSION.SDK_INT >= 33) {
            activity.registerReceiver(next, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            activity.registerReceiver(next, filter)
        }
    }

    private fun unregister() {
        val current = receiver ?: return
        receiver = null
        try {
            activity.unregisterReceiver(current)
        } catch (_: Exception) {
            // Déjà retiré.
        }
    }

    private fun parcelInfo(intent: Intent): WifiP2pInfo? {
        return if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(WifiP2pManager.EXTRA_WIFI_P2P_INFO, WifiP2pInfo::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(WifiP2pManager.EXTRA_WIFI_P2P_INFO)
        }
    }

    private fun ownerAddress(info: WifiP2pInfo?): String? {
        val host = info?.groupOwnerAddress?.hostAddress ?: return null
        return host.substringBefore('%')
    }

    private fun hold(result: MethodChannel.Result) {
        cancelPending("busy")
        pending = result
        val job = Runnable { finish(null, "timeout") }
        timeout = job
        handler.postDelayed(job, 20000)
    }

    private fun finish(value: Any?, error: String?) {
        val current = pending ?: return
        pending = null
        timeout?.let(handler::removeCallbacks)
        timeout = null
        if (error == null) current.success(value) else current.error(error, error, null)
    }

    private fun fail(result: MethodChannel.Result, code: String) {
        result.error(code, code, null)
    }

    private fun cancelPending(error: String?) {
        val current = pending ?: return
        pending = null
        timeout?.let(handler::removeCallbacks)
        timeout = null
        if (error != null) current.error(error, error, null)
    }

    companion object {
        private const val requestCodeId = 4817
    }
}
