package com.tablemtg.mtg_table

import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicast: WifiManager.MulticastLock? = null
    private val direct by lazy { WifiDirectBridge(this) }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        direct.onPermissionResult(requestCode, grantResults)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lifestack/net")
            .setMethodCallHandler { call, result ->
                if (direct.handle(
                        call.method,
                        result,
                        call.argument<String>("address"),
                    )
                ) {
                    return@setMethodCallHandler
                }
                if (call.method == "tether") {
                    val intent = Intent("android.settings.TETHER_SETTINGS")
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        startActivity(intent)
                    } catch (_: Exception) {
                        startActivity(
                            Intent(Settings.ACTION_WIRELESS_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                    }
                    result.success(null)
                    return@setMethodCallHandler
                }
                if (call.method != "multicast") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                val lock = multicast ?: wifi.createMulticastLock("lifestack").also {
                    it.setReferenceCounted(false)
                    multicast = it
                }
                if (call.argument<Boolean>("on") == true) {
                    if (!lock.isHeld) lock.acquire()
                } else if (lock.isHeld) {
                    lock.release()
                }
                result.success(null)
            }
    }
}
