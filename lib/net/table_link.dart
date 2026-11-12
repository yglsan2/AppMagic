import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mtg_table/data/app_log.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/net/table_relay.dart';

/// Un message de table (snapshot compris) tient dans cette taille.
/// Au-delà, le pair est écarté : un flux sans fin ne remplit pas la mémoire.
const maxTableMessageBytes = 2 * 1024 * 1024;

const tableDiscoveryPort = 28741;

/// Quatre téléphones, sans le Wi-Fi du lieu.
const directPhoneCap = 4;

const directTablePort = 28742;

String _fullStatus(int? limit) {
  if (limit == directPhoneCap) {
    return 'Ce groupe isolé est plein (4 téléphones). '
        'Le Wi-Fi du lieu ou le salon en ligne prend la suite.';
  }
  final count = limit ?? maxTablePlayers;
  final phones = count <= 1 ? 'téléphone' : 'téléphones';
  return 'Cette table est pleine ($count $phones).';
}

enum TablePath { lan, direct, online }

class DirectPeer {
  const DirectPeer({required this.name, required this.address});

  final String name;
  final String address;
}

const _netChannel = MethodChannel('lifestack/net');

/// Le téléphone qui reprend la table si celui qui l’a ouverte disparaît.
/// Le plus petit identifiant encore là devient l’hôte. Tout le monde calcule
/// le même, donc un seul reprend.
String tableSuccessor(List<String> roster, String fallenHost, String me) {
  final alive = [
    for (final id in roster)
      if (id != fallenHost && id.isNotEmpty) id,
  ];
  if (!alive.contains(me)) alive.add(me);
  alive.sort();
  return alive.first;
}

/// Fusionne deux éditions parties du même instant.
/// Les nombres s’ajoutent (delta), le reste prend la valeur locale si elle a changé.
Map<String, dynamic> mergeSessions({
  required Map<String, dynamic> base,
  required Map<String, dynamic> mine,
  required Map<String, dynamic> host,
}) {
  final merged = jsonDecode(jsonEncode(host)) as Map<String, dynamic>;
  final baseGame = _game(base);
  final myGame = _game(mine);
  final hostGame = _game(merged);
  if (baseGame == null || myGame == null || hostGame == null) return merged;

  final basePlayers = _players(baseGame);
  final myPlayers = _players(myGame);
  final hostPlayers = _players(hostGame);
  final byId = <String, Map<String, dynamic>>{};
  for (final player in hostPlayers) {
    final id = player['id'];
    if (id is String) byId[id] = player;
  }
  for (final player in myPlayers) {
    final id = player['id'];
    if (id is! String) continue;
    final before = basePlayers.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == id,
      orElse: () => null,
    );
    final current = byId[id];
    if (current == null) {
      hostPlayers.add(jsonDecode(jsonEncode(player)) as Map<String, dynamic>);
      continue;
    }
    if (before == null) {
      byId[id] = jsonDecode(jsonEncode(player)) as Map<String, dynamic>;
      continue;
    }
    _overlayPlayer(current, before, player);
  }
  final removed = [
    for (final player in basePlayers)
      if (player['id'] is String &&
          !myPlayers.any((item) => item['id'] == player['id']))
        player['id'] as String,
  ];
  hostPlayers.removeWhere((player) => removed.contains(player['id']));
  hostGame['players'] = hostPlayers;

  for (final key in [
    'monarchId',
    'initiativeId',
    'activeIndex',
    'turnCount',
    'roundNumber',
    'dayState',
    'seatShift',
  ]) {
    if (myGame[key] != baseGame[key]) hostGame[key] = myGame[key];
  }
  merged['lifeLog'] = _unionTape(host['lifeLog'], mine['lifeLog']);
  merged['cmdDamageLog'] = _unionTape(host['cmdDamageLog'], mine['cmdDamageLog']);
  return merged;
}

/// Réunit deux bandes. Le même identifiant ne compte qu’une fois.
/// S’il est annulé d’un côté, il reste annulé.
List<dynamic> _unionTape(Object? hostRaw, Object? mineRaw) {
  final byId = <String, Map<String, dynamic>>{};
  final order = <String>[];
  void take(Object? raw) {
    if (raw is! List) return;
    for (final item in raw) {
      if (item is! Map) continue;
      final event = Map<String, dynamic>.from(item);
      final id = event['id'];
      final key = id is String && id.isNotEmpty ? id : jsonEncode(event);
      final previous = byId[key];
      if (previous == null) {
        order.add(key);
        byId[key] = event;
        continue;
      }
      if (event['retracted'] == true || previous['retracted'] == true) {
        event['retracted'] = true;
      }
      byId[key] = event;
    }
  }

  take(hostRaw);
  take(mineRaw);
  final events = [for (final key in order) byId[key]!];
  events.sort((a, b) {
    final left = a['atMs'];
    final right = b['atMs'];
    final aMs = left is int ? left : 0;
    final bMs = right is int ? right : 0;
    return bMs.compareTo(aMs);
  });
  return events;
}

Map<String, dynamic>? _game(Map<String, dynamic> session) {
  final game = session['game'];
  if (game is Map<String, dynamic>) return game;
  if (game is Map) return Map<String, dynamic>.from(game);
  return null;
}

List<Map<String, dynamic>> _players(Map<String, dynamic> game) {
  final raw = game['players'];
  if (raw is! List) return [];
  return [
    for (final item in raw)
      if (item is Map<String, dynamic>)
        item
      else if (item is Map)
        Map<String, dynamic>.from(item),
  ];
}

void _overlayPlayer(
  Map<String, dynamic> host,
  Map<String, dynamic> base,
  Map<String, dynamic> mine,
) {
  for (final key in mine.keys) {
    final next = mine[key];
    final previous = base[key];
    final current = host[key];
    if (next is int && previous is int && current is int) {
      host[key] = current + (next - previous);
    } else if (next is Map && previous is Map && current is Map) {
      host[key] = _overlayMap(
        Map<String, dynamic>.from(current),
        Map<String, dynamic>.from(previous),
        Map<String, dynamic>.from(next),
      );
    } else if (jsonEncode(next) != jsonEncode(previous)) {
      host[key] = jsonDecode(jsonEncode(next));
    }
  }
}

Map<String, dynamic> _overlayMap(
  Map<String, dynamic> host,
  Map<String, dynamic> base,
  Map<String, dynamic> mine,
) {
  final keys = {...host.keys, ...base.keys, ...mine.keys};
  for (final key in keys) {
    final next = mine[key] ?? 0;
    final previous = base[key] ?? 0;
    final current = host[key] ?? 0;
    if (next is int && previous is int && current is int) {
      final value = current + (next - previous);
      if (value == 0) {
        host.remove(key);
      } else {
        host[key] = value;
      }
    } else if (jsonEncode(next) != jsonEncode(previous)) {
      host[key] = next;
    }
  }
  return host;
}

class _Peer {
  _Peer(this.socket);

  final Socket socket;
  final buffer = BytesBuilder();
  final lines = StreamController<Map<String, dynamic>>();
  Future<void> _writes = Future<void>.value();

  void listen(void Function() onDone) {
    onOverflow = onDone;
    socket.listen((data) {
      buffer.add(data);
      _pump();
    }, onDone: onDone, onError: (_) => onDone());
  }

  void _pump() {
    if (buffer.length > maxTableMessageBytes) {
      AppLog.warn('table: tampon trop gros, pair écarté');
      buffer.clear();
      onOverflow();
      return;
    }
    final text = utf8.decode(buffer.toBytes(), allowMalformed: true);
    final cut = text.lastIndexOf('\n');
    if (cut < 0) return;
    buffer.clear();
    final rest = text.substring(cut + 1);
    if (rest.isNotEmpty) buffer.add(utf8.encode(rest));
    for (final line in text.substring(0, cut).split('\n')) {
      if (line.trim().isEmpty) continue;
      if (line.length > maxTableMessageBytes) {
        AppLog.warn('table: ligne trop longue, ignorée');
        continue;
      }
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          lines.add(decoded);
        } else if (decoded is Map) {
          lines.add(Map<String, dynamic>.from(decoded));
        }
      } on Object catch (error) {
        AppLog.warn('table: ligne illisible · $error');
      }
    }
  }

  void Function() onOverflow = () {};

  void send(Map<String, dynamic> message) {
    final bytes = utf8.encode('${jsonEncode(message)}\n');
    if (bytes.length > maxTableMessageBytes) {
      AppLog.warn('table: message trop gros, non envoyé');
      return;
    }
    _writes = _writes.then((_) async {
      socket.add(bytes);
      await socket.flush();
    }).catchError((Object error) {
      AppLog.warn('table: envoi refusé · $error');
    });
  }

  Future<void> close() async {
    try {
      await _writes;
    } on Object {
      // Une écriture déjà en échec ne bloque pas la fermeture.
    }
    try {
      await lines.close();
    } on Object {
      // Déjà fermé.
    }
    try {
      await socket.close();
    } on Object {
      // Le flux d’envoi est encore occupé, ou le socket est déjà coupé.
    }
  }
}

/// Hôte : la partie vit sur ce téléphone, les autres s’y branchent.
class _TableHost {
  _TableHost({required this.deviceId, required this.onMessage});

  final String deviceId;
  final void Function(Map<String, dynamic> message, _Peer peer) onMessage;
  ServerSocket? _server;
  RawDatagramSocket? _beacon;
  Timer? _timer;
  final peers = <_Peer>[];
  final devices = <_Peer, String>{};
  final roster = <String>{};
  String code = '';
  int port = 0;
  int? maxPhones;
  int rev = 0;
  bool closed = false;
  Map<String, dynamic> session = {};
  Map<String, String> seats = {};

  Future<void> start(
    Map<String, dynamic> initial, {
    String? keepCode,
    int bindPort = 0,
    int? maxPhones,
  }) async {
    this.maxPhones = maxPhones;
    code = keepCode ?? _roomCode();
    session = initial;
    roster.add(deviceId);
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, bindPort);
    port = _server!.port;
    _server!.listen(_accept);
    try {
      _beacon = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _beacon!.broadcastEnabled = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _announce());
      _announce();
    } on Object {
      // Le code et l’adresse suffisent si le réseau bloque l’annonce.
    }
  }

  void publish(Map<String, dynamic> next) {
    rev += 1;
    session = next;
    _sendAll(_state());
  }

  void claim(String device, String? playerId) {
    if (playerId == null || playerId.isEmpty) {
      seats.remove(device);
    } else {
      seats.removeWhere((_, id) => id == playerId);
      seats[device] = playerId;
    }
    _sendAll(_state());
  }

  void rememberPeer(_Peer peer, String id) {
    if (id.isEmpty || closed) return;
    devices[peer] = id;
    final fresh = roster.add(id);
    if (fresh) _sendAll(_state());
  }

  Map<String, dynamic> _state() => {
    'op': 'state',
    'rev': rev,
    'host': deviceId,
    'code': code,
    'seats': seats,
    'roster': roster.toList()..sort(),
    'session': session,
  };

  void _accept(Socket socket) {
    final limit = maxPhones;
    if (limit != null && roster.length >= limit) {
      final peer = _Peer(socket);
      peer.send({'op': 'full', 'limit': limit});
      unawaited(peer.close());
      return;
    }
    final peer = _Peer(socket);
    peers.add(peer);
    peer.listen(() => _forget(peer));
    peer.lines.stream.listen((message) => onMessage(message, peer));
    peer.send(_state());
  }

  void _forget(_Peer peer) {
    peers.remove(peer);
    final id = devices.remove(peer);
    if (id != null) roster.remove(id);
    if (!closed && id != null) _sendAll(_state());
  }

  void _sendAll(Map<String, dynamic> message) {
    for (final peer in [...peers]) {
      try {
        peer.send(message);
      } on Object {
        peers.remove(peer);
      }
    }
  }

  void _announce() {
    final beacon = _beacon;
    if (beacon == null) return;
    final text = 'LS1 $code $port $deviceId';
    beacon.send(
      utf8.encode(text),
      InternetAddress('255.255.255.255'),
      tableDiscoveryPort,
    );
  }

  Future<void> close() async {
    closed = true;
    _timer?.cancel();
    _beacon?.close();
    for (final peer in [...peers]) {
      await peer.close();
    }
    peers.clear();
    await _server?.close();
    _server = null;
  }
}

class _TableGuest {
  _TableGuest({required this.onState, required this.onDropped});

  final void Function(Map<String, dynamic> message) onState;
  final void Function() onDropped;
  _Peer? _peer;

  Future<void> connect(String host, int port) async {
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 4),
    );
    final peer = _Peer(socket);
    _peer = peer;
    peer.listen(onDropped);
    peer.lines.stream.listen(onState);
  }

  void send(Map<String, dynamic> message) {
    _peer?.send(message);
  }

  Future<void> close() async {
    await _peer?.close();
    _peer = null;
  }
}

/// Cherche une table annoncée sur le Wi-Fi du lieu.
Future<({String host, int port})?> findRoom(
  String code, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final want = code.trim().toUpperCase();
  await _multicast(true);
  RawDatagramSocket socket;
  try {
    socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      tableDiscoveryPort,
    );
  } on Object {
    await _multicast(false);
    return null;
  }
  final found = Completer<({String host, int port})?>();
  final timer = Timer(timeout, () {
    if (!found.isCompleted) found.complete(null);
  });
  socket.listen((event) {
    if (event != RawSocketEvent.read) return;
    final datagram = socket.receive();
    if (datagram == null) return;
    final text = utf8.decode(datagram.data, allowMalformed: true).trim();
    final parts = text.split(' ');
    if (parts.length < 3 || parts[0] != 'LS1') return;
    if (parts[1].toUpperCase() != want) return;
    final port = int.tryParse(parts[2]);
    if (port == null) return;
    if (!found.isCompleted) {
      found.complete((host: datagram.address.address, port: port));
    }
  });
  final result = await found.future;
  timer.cancel();
  socket.close();
  await _multicast(false);
  return result;
}

Future<void> _multicast(bool on) async {
  try {
    await _netChannel.invokeMethod<void>('multicast', {'on': on});
  } on Object {
    // Windows, tests, ou un appareil sans ce canal.
  }
}

Future<String?> lanAddress({bool preferHotspot = false}) async {
  try {
    final found = <String>[];
    for (final interface in await NetworkInterface.list()) {
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
          found.add(address.address);
        }
      }
    }
    return pickLanAddress(found, preferHotspot: preferHotspot);
  } on Object {
    return null;
  }
}

/// Choisit l’adresse que les autres téléphones peuvent joindre.
/// Le réseau ouvert par l’application passe devant le Wi-Fi du lieu.
String? pickLanAddress(Iterable<String> addresses, {bool preferHotspot = false}) {
  final usable = [
    for (final address in addresses)
      if (!address.startsWith('169.254.')) address,
  ];
  if (usable.isEmpty) return null;
  usable.sort(
    (a, b) => _addressRank(a, preferHotspot: preferHotspot)
        .compareTo(_addressRank(b, preferHotspot: preferHotspot)),
  );
  return usable.first;
}

int _addressRank(String ip, {required bool preferHotspot}) {
  final hotspot = ip.startsWith('192.168.43.') ||
      ip.startsWith('192.168.49.') ||
      ip.startsWith('192.168.137.');
  if (preferHotspot && hotspot) return 0;
  if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
    return 1;
  }
  return 2;
}

/// QR lu par l’appareil photo : il connecte le téléphone au réseau de la table.
String wifiQrPayload(String ssid, String pass) {
  String esc(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll(':', r'\:');
  return 'WIFI:T:WPA;S:${esc(ssid)};P:${esc(pass)};;';
}

String _roomCode([int length = 4]) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random();
  return List.generate(
    length,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}

/// Lien entre les téléphones de la table. Un seul téléphone : rien n’est ouvert.
class TableLinkController extends ChangeNotifier {
  TableLinkController()
    : deviceId = 'd${DateTime.now().microsecondsSinceEpoch}-${_nextDevice++}';

  static int _nextDevice = 0;
  final String deviceId;
  _TableHost? _host;
  _TableGuest? _guest;
  int rev = 0;
  String? code;
  String? address;
  String hostDeviceId = '';
  Map<String, String> seats = {};
  String? status;
  bool searching = false;
  bool center = false;
  bool centerChosen = false;
  String? networkSsid;
  String? networkPass;
  TablePath path = TablePath.lan;
  List<DirectPeer> nearby = [];
  List<String> roster = [];
  RelayRoom? _relay;
  bool _relayHost = false;
  bool _rejected = false;
  int? _fullLimit;
  bool _closingRelay = false;
  int _relayStrikes = 0;
  int _epoch = 0;
  bool _reforming = false;
  Timer? _reformTimer;
  Completer<void>? _reformGate;
  Map<String, dynamic>? _base;
  Map<String, dynamic>? _pending;
  final _snapshots = <int, Map<String, dynamic>>{};
  Completer<void>? _hello;
  int _localGen = 0;
  int _sentGen = 0;
  bool _sending = false;

  void Function(Map<String, dynamic> session)? onSession;

  bool get linked => _host != null || _guest != null || _relay != null;
  bool get hosting => _host != null || _relayHost;

  String get pathLabel => switch (path) {
    TablePath.lan => 'Wi-Fi du lieu',
    TablePath.direct => 'Groupe isolé',
    TablePath.online => 'Salon en ligne',
  };
  String? get mySeat => seats[deviceId];
  int? get port => _host?.port;
  String? get joinAddress =>
      address != null && port != null ? '$address:$port' : null;
  int get phones {
    if (_host != null) return _host!.roster.length;
    if (roster.isNotEmpty) return roster.length;
    return linked ? 1 : 0;
  }

  /// Cet écran montre la table et ne prend pas de siège.
  void setCenter(bool value) {
    center = value;
    centerChosen = true;
    if (value) claim(null);
    notifyListeners();
  }

  /// Ouvre le partage de connexion Android quand le Wi-Fi du lieu isole les appareils.
  Future<bool> openHotspotSettings() async {
    try {
      await _netChannel.invokeMethod<void>('tether');
      return true;
    } on Object {
      return false;
    }
  }
  Map<String, dynamic>? latestSession;

  Future<void> hostTable(
    Map<String, dynamic> session, {
    String? keepCode,
    int? bindPort,
    String? announce,
    int? maxPhones,
  }) async {
    final keptSeats = keepCode == null
        ? <String, String>{}
        : Map<String, String>.from(seats);
    final epoch = _epoch;
    await _closeLink();
    if (epoch != _epoch) return;
    final host = _TableHost(deviceId: deviceId, onMessage: _onHostMessage);
    await host.start(
      session,
      keepCode: keepCode,
      bindPort: bindPort ?? 0,
      maxPhones: maxPhones ?? maxTablePlayers,
    );
    if (epoch != _epoch) {
      await host.close();
      return;
    }
    _host = host;
    for (final entry in keptSeats.entries) {
      host.claim(entry.key, entry.value);
    }
    code = host.code;
    rev = host.rev;
    seats = Map<String, String>.from(host.seats);
    roster = host.roster.toList()..sort();
    address = announce ?? await lanAddress(preferHotspot: networkSsid != null);
    if (announce == null) path = TablePath.lan;
    latestSession = jsonDecode(jsonEncode(session)) as Map<String, dynamic>;
    status = keepCode == null
        ? 'Table $code ouverte'
        : 'Table reprise sur cet appareil · $code';
    _base = jsonDecode(jsonEncode(session)) as Map<String, dynamic>;
    _remember(host.rev, session);
    notifyListeners();
  }

  void _remember(int revision, Map<String, dynamic> session) {
    _snapshots[revision] = jsonDecode(jsonEncode(session)) as Map<String, dynamic>;
    while (_snapshots.length > 40) {
      var oldest = revision;
      for (final key in _snapshots.keys) {
        if (key < oldest) oldest = key;
      }
      _snapshots.remove(oldest);
    }
  }

  Future<bool> joinTable(String input) async {
    final epoch = _epoch;
    await _closeLink();
    if (epoch != _epoch) return false;
    searching = true;
    status = 'Recherche…';
    notifyListeners();
    final parsed = _parseAddress(input);
    String? host;
    var port = 0;
    if (parsed != null) {
      host = parsed.$1;
      port = parsed.$2;
    } else {
      final found = await findRoom(input);
      host = found?.host;
      port = found?.port ?? 0;
    }
    if (host == null || port == 0) {
      searching = false;
      status = 'Table introuvable. Vérifiez le code ou l’adresse.';
      notifyListeners();
      return false;
    }
    final guest = _TableGuest(onState: _onGuestState, onDropped: _onDropped);
    _hello = Completer<void>();
    try {
      await guest.connect(host, port);
    } on Object {
      searching = false;
      status = 'Connexion impossible.';
      notifyListeners();
      return false;
    }
    _guest = guest;
    guest.send({'op': 'hello', 'device': deviceId});
    searching = false;
    status = 'Relié';
    notifyListeners();
    try {
      await _hello!.future.timeout(const Duration(seconds: 4));
    } on Object {
      await _closeLink();
      status = 'La table ne répond pas.';
      notifyListeners();
      return false;
    }
    if (_rejected || epoch != _epoch) {
      if (_rejected) {
        final text = _fullStatus(_fullLimit);
        await _closeLink();
        status = text;
        notifyListeners();
      }
      return false;
    }
    path = TablePath.lan;
    return true;
  }

  void publishLocal(Map<String, dynamic> session) {
    if (_relayHost) {
      _publishRelay(session);
      return;
    }
    if (_relay != null) {
      _localGen += 1;
      _pending = session;
      _pumpRelay();
      return;
    }
    final host = _host;
    if (host != null) {
      host.publish(session);
      rev = host.rev;
      _base = jsonDecode(jsonEncode(session)) as Map<String, dynamic>;
      _remember(rev, session);
      _pending = null;
      notifyListeners();
      return;
    }
    if (_guest == null) return;
    _localGen += 1;
    _pending = session;
    _pumpGuest();
  }

  void claim(String? playerId) {
    if (_relayHost) {
      _assignSeat(deviceId, playerId);
      final session = _base;
      if (session != null) _publishRelay(session);
      return;
    }
    if (_relay != null) {
      unawaited(
        _relay!.send({
          'op': 'claim',
          'device': deviceId,
          'player': playerId ?? '',
        }),
      );
      return;
    }
    final host = _host;
    if (host != null) {
      host.claim(deviceId, playerId);
      seats = Map<String, String>.from(host.seats);
      notifyListeners();
      return;
    }
    _guest?.send({'op': 'claim', 'device': deviceId, 'player': playerId ?? ''});
  }

  Future<void> stop() async {
    _epoch += 1;
    await _closeLink();
    await releaseTableNetwork();
    path = TablePath.lan;
    status = null;
    notifyListeners();
  }

  /// Ferme un réseau de table ouvert par cet appareil, s’il y en a un.
  Future<void> releaseTableNetwork() async {
    networkSsid = null;
    networkPass = null;
    try {
      await _netChannel
          .invokeMethod<void>('stopTableNet')
          .timeout(const Duration(milliseconds: 400));
    } on Object {
      // Windows, tests, ou un téléphone sans ce réseau.
    }
  }

  /// Quatre téléphones, en Wi-Fi Direct, sans le réseau du lieu.
  Future<bool> hostDirect(Map<String, dynamic> session) async {
    final opened = await _directStart();
    if (opened == null) {
      status =
          'Groupe isolé indisponible sur cet appareil. Il se crée sur Android, avec le Wi-Fi Direct.';
      notifyListeners();
      return false;
    }
    try {
      await hostTable(
        session,
        bindPort: directTablePort,
        announce: opened.address,
        maxPhones: directPhoneCap,
      );
    } on Object {
      await releaseTableNetwork();
      status = 'Le groupe s’est ouvert, mais la table n’a pas pu démarrer.';
      notifyListeners();
      return false;
    }
    path = TablePath.direct;
    address = opened.address;
    networkSsid = opened.ssid;
    networkPass = opened.pass;
    status = 'Groupe isolé · 4 téléphones au plus';
    notifyListeners();
    return true;
  }

  Future<void> seekDirect() async {
    searching = true;
    status = 'Recherche d’un groupe isolé…';
    notifyListeners();
    nearby = await _directDiscover();
    searching = false;
    status = nearby.isEmpty
        ? 'Aucun groupe vu. Restez près du téléphone qui l’a ouvert, puis réessayez.'
        : 'Touchez le téléphone qui a ouvert le groupe.';
    notifyListeners();
  }

  Future<bool> joinDirect(String peerAddress) async {
    status = 'Connexion au groupe…';
    notifyListeners();
    final owner = await _directConnect(peerAddress);
    if (owner == null) {
      status = 'Ce téléphone n’a pas rejoint le groupe.';
      notifyListeners();
      return false;
    }
    final ok = await joinTable('$owner:$directTablePort');
    if (!ok) {
      await releaseTableNetwork();
      return false;
    }
    path = TablePath.direct;
    notifyListeners();
    return true;
  }

  /// Salon chiffré, quand aucun réseau local ne tient. Jusqu’à 12 téléphones.
  Future<bool> hostOnline(Map<String, dynamic> session) async {
    final epoch = _epoch;
    await _closeLink();
    if (epoch != _epoch) return false;
    final room = _roomCode(8);
    final relay = RelayRoom(deviceId: deviceId, code: room);
    status = 'Ouverture du salon…';
    notifyListeners();
    try {
      await relay.open();
    } on Object {
      await relay.close();
      status =
          'Salon injoignable. Le Wi-Fi du lieu ou un groupe isolé reste possible.';
      notifyListeners();
      return false;
    }
    if (epoch != _epoch) {
      await relay.close();
      return false;
    }
    _attachRelay(relay, host: true, room: room, session: session);
    status = 'Salon ouvert';
    notifyListeners();
    return true;
  }

  Future<bool> joinOnline(String input) async {
    final room = normalizeRoomCode(input);
    if (room.length < 4) {
      status = 'Code incomplet.';
      notifyListeners();
      return false;
    }
    final epoch = _epoch;
    await _closeLink();
    if (epoch != _epoch) return false;
    final relay = RelayRoom(deviceId: deviceId, code: room);
    searching = true;
    status = 'Connexion au salon…';
    notifyListeners();
    try {
      await relay.open();
    } on Object {
      await relay.close();
      searching = false;
      status =
          'Salon injoignable. Le Wi-Fi du lieu ou un groupe isolé reste possible.';
      notifyListeners();
      return false;
    }
    if (epoch != _epoch) {
      await relay.close();
      return false;
    }
    _relay = relay;
    _relayHost = false;
    _relayStrikes = 0;
    path = TablePath.online;
    code = room;
    _hello = Completer<void>();
    relay.messages.listen(_onRelayMessage, onDone: _onRelayDone);
    _greet(relay);
    searching = false;
    notifyListeners();
    try {
      await _hello!.future.timeout(const Duration(seconds: 6));
    } on Object {
      await _closeLink();
      status = 'Ce salon ne répond pas. Vérifiez le code.';
      notifyListeners();
      return false;
    }
    if (_rejected || epoch != _epoch) {
      if (_rejected) {
        await _closeLink();
        status = 'Ce salon est plein.';
        notifyListeners();
      }
      return false;
    }
    return true;
  }

  void _attachRelay(
    RelayRoom relay, {
    required bool host,
    required String room,
    required Map<String, dynamic> session,
  }) {
    _relay = relay;
    _relayHost = host;
    _relayStrikes = 0;
    path = TablePath.online;
    code = room;
    hostDeviceId = deviceId;
    roster = [deviceId];
    seats = {};
    rev = 0;
    final copy = jsonDecode(jsonEncode(session)) as Map<String, dynamic>;
    latestSession = copy;
    _base = copy;
    relay.messages.listen(_onRelayMessage, onDone: _onRelayDone);
    if (host) _publishRelay(copy);
  }

  void _greet(RelayRoom relay) {
    unawaited(relay.send({'op': 'hello', 'device': deviceId}));
    unawaited(() async {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (_relay != relay || _relayHost) return;
      await relay.send({'op': 'hello', 'device': deviceId});
    }());
  }

  void _assignSeat(String device, String? playerId) {
    if (playerId == null || playerId.isEmpty) {
      seats.remove(device);
    } else {
      seats.removeWhere((_, id) => id == playerId);
      seats[device] = playerId;
    }
  }

  void _publishRelay(Map<String, dynamic> session) {
    final relay = _relay;
    if (relay == null) return;
    rev += 1;
    final copy = jsonDecode(jsonEncode(session)) as Map<String, dynamic>;
    _base = copy;
    latestSession = copy;
    _remember(rev, copy);
    _pending = null;
    _sentGen = _localGen;
    unawaited(
      relay.send({
        'op': 'state',
        'rev': rev,
        'host': deviceId,
        'code': code,
        'seats': seats,
        'roster': roster,
        'session': copy,
      }),
    );
    notifyListeners();
  }

  void _pumpRelay() {
    final relay = _relay;
    final pending = _pending;
    if (relay == null || pending == null || _sending || _relayHost) return;
    _sending = true;
    _sentGen = _localGen;
    final generation = _sentGen;
    unawaited(() async {
      try {
        await relay.send({'op': 'edit', 'base': rev, 'session': pending});
      } on Object {
        if (_sentGen == generation) _sending = false;
      }
    }());
  }

  void _onRelayDone() {
    if (_closingRelay || _relay == null) return;
    unawaited(_onRelayLost());
  }

  void _onRelayMessage(Map<String, dynamic> message) {
    if (message['from'] == deviceId) return;
    final op = message['op'];
    if (op == 'bye') {
      final from = message['from'];
      if (_relayHost && from is String) {
        roster = [
          for (final id in roster)
            if (id != from) id,
        ];
        seats.remove(from);
        final session = _base;
        if (session != null) _publishRelay(session);
      } else if (!_relayHost && from == hostDeviceId) {
        unawaited(_reformOnline());
      }
      return;
    }
    if (op == 'full') {
      final target = message['device'];
      if (target is String && target.isNotEmpty && target != deviceId) return;
      final hello = _hello;
      if (hello == null || hello.isCompleted) return;
      _rejected = true;
      status = 'Ce salon est plein.';
      hello.complete();
      notifyListeners();
      return;
    }
    if (_relayHost) {
      _onRelayHost(message);
      return;
    }
    if (op == 'state') _onGuestState(message);
  }

  void _onRelayHost(Map<String, dynamic> message) {
    final op = message['op'];
    final device = message['from'] ?? message['device'];
    if (device is! String || device.isEmpty) return;
    if (op == 'hello' || op == 'claim') {
      if (!roster.contains(device) && roster.length >= maxTablePlayers) {
        unawaited(_relay?.send({'op': 'full', 'device': device}));
        return;
      }
      if (!roster.contains(device)) {
        roster = [...roster, device]..sort();
      }
      if (op == 'claim') {
        final player = message['player'];
        _assignSeat(
          device,
          player is String && player.isNotEmpty ? player : null,
        );
      }
      final session = _base;
      if (session != null) _publishRelay(session);
      return;
    }
    if (op != 'edit') return;
    final session = message['session'];
    if (session is! Map) return;
    final incoming = Map<String, dynamic>.from(session);
    final baseRev = message['base'];
    final known = baseRev is int ? _snapshots[baseRev] : null;
    final Map<String, dynamic> next;
    if (baseRev == rev) {
      next = incoming;
    } else if (known != null && _base != null) {
      next = mergeSessions(base: known, mine: incoming, host: _base!);
    } else {
      final current = _base;
      if (current != null) _publishRelay(current);
      return;
    }
    _publishRelay(next);
    onSession?.call(next);
  }

  Future<void> _reformOnline() async {
    if (_reforming || _relay == null) return;
    final session = latestSession;
    final fallen = hostDeviceId;
    final names = List<String>.from(roster);
    if (session == null) {
      status = 'Le salon s’est coupé. La partie reste ici.';
      notifyListeners();
      return;
    }
    final next = tableSuccessor(names, fallen, deviceId);
    if (next != deviceId) {
      status = 'L’hôte a coupé. Un autre téléphone reprend le salon…';
      notifyListeners();
      _reformTimer?.cancel();
      _reformTimer = Timer(const Duration(seconds: 4), () {
        if (_relayHost || hostDeviceId != fallen) return;
        status = 'Le salon est interrompu. La partie reste ici.';
        notifyListeners();
      });
      return;
    }
    _relayHost = true;
    hostDeviceId = deviceId;
    status = 'Salon repris sur cet appareil';
    _publishRelay(session);
  }

  Future<void> _onRelayLost() async {
    if (_closingRelay || path != TablePath.online) return;
    _relayStrikes += 1;
    final epoch = _epoch;
    final session = latestSession;
    final room = code;
    final wasHost = _relayHost;
    _relay = null;
    _relayHost = false;
    if (_relayStrikes > 2 || session == null || room == null || room.isEmpty) {
      status = 'Le salon en ligne s’est coupé. La partie reste ici.';
      notifyListeners();
      return;
    }
    status = 'Salon interrompu. Reconnexion…';
    notifyListeners();
    final relay = RelayRoom(deviceId: deviceId, code: room);
    try {
      await relay.open();
    } on Object {
      if (epoch != _epoch) return;
      status = 'Le salon en ligne s’est coupé. La partie reste ici.';
      notifyListeners();
      return;
    }
    if (epoch != _epoch) {
      await relay.close();
      return;
    }
    _relay = relay;
    relay.messages.listen(_onRelayMessage, onDone: _onRelayDone);
    if (wasHost) {
      _relayHost = true;
      hostDeviceId = deviceId;
      roster = [deviceId];
      _publishRelay(session);
      status = 'Salon repris sur cet appareil';
    } else {
      _greet(relay);
      status = 'Salon retrouvé';
    }
    notifyListeners();
  }

  Future<void> _closeLink() async {
    _cancelReform();
    final host = _host;
    final guest = _guest;
    _host = null;
    _guest = null;
    code = null;
    address = null;
    seats = {};
    roster = [];
    rev = 0;
    searching = false;
    _pending = null;
    _base = null;
    _snapshots.clear();
    _rejected = false;
    _fullLimit = null;
    nearby = [];
    final relay = _relay;
    _relay = null;
    _relayHost = false;
    _closingRelay = true;
    await host?.close();
    await guest?.close();
    await relay?.close();
    _closingRelay = false;
  }

  void _cancelReform() {
    _reformTimer?.cancel();
    _reformTimer = null;
    final gate = _reformGate;
    if (gate != null && !gate.isCompleted) gate.complete();
    _reformGate = null;
  }

  void _onHostMessage(Map<String, dynamic> message, _Peer peer) {
    final host = _host;
    if (host == null) return;
    final op = message['op'];
    if (op == 'hello' || op == 'claim') {
      final device = message['device'];
      if (device is String &&
          path == TablePath.direct &&
          !host.roster.contains(device) &&
          host.roster.length >= directPhoneCap) {
        peer.send({'op': 'full', 'limit': directPhoneCap});
        return;
      }
      if (device is String) host.rememberPeer(peer, device);
      roster = host.roster.toList()..sort();
      if (op == 'hello' || device is! String) {
        notifyListeners();
        return;
      }
      final player = message['player'];
      host.claim(device, player is String ? player : null);
      seats = Map<String, String>.from(host.seats);
      notifyListeners();
      return;
    }
    if (op != 'edit') return;
    final baseRev = message['base'];
    final session = message['session'];
    if (session is! Map) return;
    final incoming = Map<String, dynamic>.from(session);
    final known = baseRev is int ? _snapshots[baseRev] : null;
    if (baseRev == host.rev) {
      host.publish(incoming);
    } else if (known != null) {
      final merged = mergeSessions(
        base: known,
        mine: incoming,
        host: host.session,
      );
      host.publish(merged);
    } else {
      peer.send(host._state());
      return;
    }
    rev = host.rev;
    _base = jsonDecode(jsonEncode(host.session)) as Map<String, dynamic>;
    _remember(rev, host.session);
    seats = Map<String, String>.from(host.seats);
    onSession?.call(host.session);
    notifyListeners();
  }

  void _onGuestState(Map<String, dynamic> message) {
    if (message['op'] == 'full') {
      _rejected = true;
      final limit = message['limit'];
      _fullLimit = limit is int ? limit : null;
      final hello = _hello;
      if (hello != null && !hello.isCompleted) hello.complete();
      return;
    }
    if (message['op'] != 'state') return;
    final nextRev = message['rev'];
    final session = message['session'];
    if (nextRev is! int || session is! Map) return;
    final seatsRaw = message['seats'];
    seats = {};
    if (seatsRaw is Map) {
      for (final entry in seatsRaw.entries) {
        if (entry.value is String && (entry.value as String).isNotEmpty) {
          seats['${entry.key}'] = entry.value as String;
        }
      }
    }
    code = message['code'] as String? ?? code;
    hostDeviceId = message['host'] as String? ?? hostDeviceId;
    final rosterRaw = message['roster'];
    if (rosterRaw is List) {
      roster = [
        for (final item in rosterRaw)
          if (item is String && item.isNotEmpty) item,
      ];
    }
    if (rosterRaw is List && !roster.contains(deviceId)) {
      notifyListeners();
      return;
    }
    final incoming = Map<String, dynamic>.from(session);
    final newerLocal = _pending != null && _localGen != _sentGen;
    rev = nextRev;
    _sending = false;
    if (newerLocal && _base != null && _pending != null) {
      _pending = mergeSessions(base: _base!, mine: _pending!, host: incoming);
      _base = incoming;
      latestSession = _pending;
      onSession?.call(_pending!);
      if (_relay != null) {
        _pumpRelay();
      } else {
        _pumpGuest();
      }
      notifyListeners();
      return;
    }
    _pending = null;
    _sentGen = _localGen;
    _base = incoming;
    status = code == null ? 'Relié' : 'Relié · $code';
    latestSession = incoming;
    if (_hello != null &&
        !_hello!.isCompleted &&
        roster.contains(deviceId)) {
      _hello!.complete();
    }
    onSession?.call(incoming);
    notifyListeners();
  }

  void _pumpGuest() {
    final guest = _guest;
    final pending = _pending;
    if (guest == null || pending == null || _sending) return;
    _sending = true;
    _sentGen = _localGen;
    guest.send({'op': 'edit', 'base': rev, 'session': pending});
  }

  void _onDropped() {
    if (_rejected) return;
    if (_guest == null || _reforming) return;
    final epoch = _epoch;
    final session = latestSession;
    final room = code;
    final fallen = hostDeviceId;
    final names = List<String>.from(roster);
    _guest = null;
    if (path == TablePath.direct) {
      status =
          'Le groupe isolé s’est fermé avec le téléphone qui l’a ouvert. La partie reste ici.';
      notifyListeners();
      unawaited(releaseTableNetwork());
      return;
    }
    if (session == null || room == null || room.isEmpty) {
      status = 'Téléphone hôte déconnecté. La partie reste sur cet appareil.';
      notifyListeners();
      return;
    }
    status = 'L’hôte a coupé. La table se reforme…';
    notifyListeners();
    _reforming = true;
    unawaited(() async {
      try {
        await _reform(epoch, session, room, names, fallen);
      } finally {
        _reforming = false;
      }
    }());
  }

  Future<void> _reform(
    int epoch,
    Map<String, dynamic> session,
    String room,
    List<String> names,
    String fallen,
  ) async {
    final next = tableSuccessor(names, fallen, deviceId);
    if (next != deviceId) {
      _reformGate = Completer<void>();
      _reformTimer = Timer(const Duration(milliseconds: 700), () {
        final gate = _reformGate;
        if (gate != null && !gate.isCompleted) gate.complete();
      });
      await _reformGate!.future;
      _reformTimer = null;
      _reformGate = null;
      if (epoch != _epoch || _host != null || _guest != null) return;
      final found = await findRoom(room, timeout: const Duration(seconds: 3));
      if (epoch != _epoch || _host != null || _guest != null) return;
      if (found != null) {
        final ok = await joinTable('${found.host}:${found.port}');
        if (ok || epoch != _epoch) return;
      }
      status =
          'Table interrompue. La partie reste ici. Le code $room est peut-être repris sur un autre téléphone.';
      notifyListeners();
      return;
    }
    if (epoch != _epoch) return;
    await hostTable(session, keepCode: room);
  }
}

Future<({String address, String? ssid, String? pass})?> _directStart() async {
  try {
    final raw = await _netChannel
        .invokeMethod<dynamic>('directStart')
        .timeout(const Duration(seconds: 25));
    if (raw is! Map) return null;
    final address = raw['address'];
    if (address is! String || address.isEmpty) return null;
    return (
      address: address,
      ssid: raw['ssid'] as String?,
      pass: raw['pass'] as String?,
    );
  } on Object {
    return null;
  }
}

Future<List<DirectPeer>> _directDiscover() async {
  try {
    final raw = await _netChannel
        .invokeMethod<dynamic>('directDiscover')
        .timeout(const Duration(seconds: 15));
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map && item['address'] is String)
          DirectPeer(
            name: item['name'] is String && (item['name'] as String).isNotEmpty
                ? item['name'] as String
                : 'Téléphone',
            address: item['address'] as String,
          ),
    ];
  } on Object {
    return const [];
  }
}

Future<String?> _directConnect(String address) async {
  try {
    final raw = await _netChannel
        .invokeMethod<dynamic>('directConnect', {'address': address})
        .timeout(const Duration(seconds: 25));
    if (raw is String && raw.isNotEmpty) return raw;
    return null;
  } on Object {
    return null;
  }
}

(String, int)? _parseAddress(String input) {
  final text = input.trim();
  final words = text.split(RegExp(r'\s+'));
  if (words.length >= 4 && words[0] == 'LS1') {
    final port = int.tryParse(words[3]);
    if (port != null && port > 0) return (words[2], port);
  }
  final parts = text.split(':');
  if (parts.length != 2) return null;
  final port = int.tryParse(parts[1]);
  if (port == null || port <= 0) return null;
  return (parts[0], port);
}
