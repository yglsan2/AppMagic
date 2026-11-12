import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:mtg_table/data/app_log.dart';

/// Au-delà, la trame est refusée : un relais public ne doit pas remplir la mémoire.
const maxMqttFrameBytes = 2 * 1024 * 1024;

/// Relais du salon en ligne. Le code est la clé : le sujet et le contenu
/// n’en montrent pas le texte.
const relaySockets = <String>[
  'wss://broker.hivemq.com:8884/mqtt',
  'wss://broker.emqx.io:8084/mqtt',
];

Future<String> topicForCode(String code) async {
  final digest = await Sha256().hash(
    utf8.encode('lifestack-topic-v1:$code'),
  );
  return 'ls/${_hex(digest.bytes.sublist(0, 16))}';
}

Future<List<int>> sealForCode(String code, List<int> plain) async {
  final algorithm = AesGcm.with256bits();
  final box = await algorithm.encrypt(
    plain,
    secretKey: await _key(code),
  );
  return <int>[...box.nonce, ...box.cipherText, ...box.mac.bytes];
}

Future<List<int>?> openForCode(String code, List<int> sealed) async {
  if (sealed.length < 12 + 16) return null;
  final algorithm = AesGcm.with256bits();
  final nonce = sealed.sublist(0, 12);
  final mac = sealed.sublist(sealed.length - 16);
  final cipher = sealed.sublist(12, sealed.length - 16);
  try {
    return await algorithm.decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
      secretKey: await _key(code),
    );
  } on Object {
    return null;
  }
}

Future<SecretKey> _key(String code) async {
  final digest = await Sha256().hash(
    utf8.encode('lifestack-key-v1:$code'),
  );
  return SecretKey(digest.bytes);
}

String _hex(List<int> bytes) {
  const alphabet = '0123456789abcdef';
  final out = StringBuffer();
  for (final byte in bytes) {
    out.write(alphabet[byte >> 4]);
    out.write(alphabet[byte & 0x0f]);
  }
  return out.toString();
}

/// Normalise un code tapé ou copié depuis le QR du salon.
String normalizeRoomCode(String input) {
  var text = input.trim().toUpperCase();
  if (text.startsWith('LSNET:')) text = text.substring(6);
  return text.replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

Uint8List mqttConnectPacket({
  required String clientId,
  required String willTopic,
  required List<int> willMessage,
}) {
  final id = utf8.encode(clientId);
  final topic = utf8.encode(willTopic);
  final payload = BytesBuilder();
  _mqttStr(payload, id);
  _mqttStr(payload, topic);
  _mqttStr(payload, willMessage);
  final body = BytesBuilder()
    ..addByte(0)
    ..addByte(4)
    ..add(utf8.encode('MQTT'))
    ..addByte(4)
    ..addByte(0x06)
    ..addByte(0)
    ..addByte(30)
    ..add(payload.toBytes());
  return _packet(0x10, body.toBytes());
}

Uint8List mqttSubscribePacket(String topic, int packetId) {
  final body = BytesBuilder()
    ..addByte(packetId >> 8)
    ..addByte(packetId & 0xff);
  _mqttStr(body, utf8.encode(topic));
  body.addByte(0);
  return _packet(0x82, body.toBytes());
}

Uint8List mqttPublishPacket(String topic, List<int> message) {
  final body = BytesBuilder();
  _mqttStr(body, utf8.encode(topic));
  body.add(message);
  return _packet(0x30, body.toBytes());
}

Uint8List mqttDisconnectPacket() => Uint8List.fromList(const [0xE0, 0x00]);

Uint8List mqttPingPacket() => Uint8List.fromList(const [0xC0, 0x00]);

void _mqttStr(BytesBuilder out, List<int> bytes) {
  out
    ..addByte(bytes.length >> 8)
    ..addByte(bytes.length & 0xff)
    ..add(bytes);
}

Uint8List _packet(int type, List<int> body) {
  final out = BytesBuilder()..addByte(type);
  var length = body.length;
  do {
    var encoded = length % 128;
    length ~/= 128;
    if (length > 0) encoded |= 0x80;
    out.addByte(encoded);
  } while (length > 0);
  out.add(body);
  return out.toBytes();
}

/// Paquets MQTT complets extraits d’un flux. Le reste incomplet est rendu.
///
/// [overflow] est vrai si une longueur annoncée dépasse [maxMqttFrameBytes] :
/// le reste du tampon est alors jeté.
({List<({int type, Uint8List body})> frames, Uint8List rest, bool overflow})
mqttFrames(List<int> buffer) {
  final frames = <({int type, Uint8List body})>[];
  var offset = 0;
  while (offset < buffer.length) {
    if (offset + 2 > buffer.length) break;
    final type = buffer[offset];
    var multiplier = 1;
    var length = 0;
    var used = 0;
    var complete = false;
    for (var i = offset + 1; i < buffer.length && i < offset + 5; i++) {
      used += 1;
      final byte = buffer[i];
      length += (byte & 0x7f) * multiplier;
      multiplier *= 128;
      if ((byte & 0x80) == 0) {
        complete = true;
        break;
      }
    }
    if (!complete) break;
    if (length < 0 || length > maxMqttFrameBytes) {
      AppLog.warn('mqtt: trame annoncée trop grosse ($length)');
      return (frames: frames, rest: Uint8List(0), overflow: true);
    }
    final start = offset + 1 + used;
    if (start + length > buffer.length) break;
    frames.add((
      type: type,
      body: Uint8List.fromList(buffer.sublist(start, start + length)),
    ));
    offset = start + length;
  }
  return (
    frames: frames,
    rest: Uint8List.fromList(buffer.sublist(offset)),
    overflow: false,
  );
}

/// Charge utile d’un PUBLISH QoS 0, ou null si le paquet n’en est pas un.
Uint8List? mqttPublishBody(Uint8List body) {
  if (body.length < 2) return null;
  final topicLength = (body[0] << 8) | body[1];
  final start = 2 + topicLength;
  if (topicLength < 0 || start > body.length) return null;
  return Uint8List.fromList(body.sublist(start));
}

/// Salon chiffré, branché sur un relais public. Un seul abonnement par table.
class RelayRoom {
  RelayRoom({required this.deviceId, required this.code});

  final String deviceId;
  final String code;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  WebSocket? _socket;
  Timer? _ping;
  final _buffer = BytesBuilder();
  var _open = false;
  var _closed = false;
  var _established = false;
  var _attempt = 0;
  String _topic = '';

  Stream<Map<String, dynamic>> get messages => _messages.stream;
  bool get isOpen => _open;

  Future<void> open() async {
    final topic = await topicForCode(code);
    Object? lastError;
    for (final url in relaySockets) {
      try {
        final generation = ++_attempt;
        _buffer.clear();
        final socket = await WebSocket.connect(
          url,
          protocols: const ['mqtt'],
        ).timeout(const Duration(seconds: 6));
        if (generation != _attempt || _closed) {
          await socket.close();
          continue;
        }
        _socket = socket;
        _topic = topic;
        final ready = Completer<void>();
        socket.listen(
          (event) {
            if (generation != _attempt) return;
            unawaited(_onFrame(event, ready));
          },
          onDone: () {
            if (generation != _attempt) return;
            _onDone();
          },
          onError: (_) {
            if (generation != _attempt) return;
            _onDone();
          },
        );
        final bye = utf8.encode(jsonEncode({'op': 'bye', 'from': deviceId}));
        final sealedBye = await sealForCode(code, bye);
        final rawId = 'ls${deviceId.hashCode & 0x7fffffff}';
        final client = rawId.length > 22 ? rawId.substring(0, 22) : rawId;
        socket.add(mqttConnectPacket(
          clientId: client,
          willTopic: topic,
          willMessage: sealedBye,
        ));
        await ready.future.timeout(const Duration(seconds: 6));
        _established = true;
        _open = true;
        _ping = Timer.periodic(const Duration(seconds: 20), (_) {
          _socket?.add(mqttPingPacket());
        });
        return;
      } on Object catch (error) {
        lastError = error;
        AppLog.warn('salon: relais $url · $error');
        final socket = _socket;
        _socket = null;
        if (socket != null) {
          try {
            await socket.close().timeout(const Duration(milliseconds: 300));
          } on Object {
            // On passe au relais suivant.
          }
        }
      }
    }
    final error = lastError ?? StateError('salon');
    AppLog.error('salon: aucun relais', error);
    throw error;
  }

  Future<void> _onFrame(Object event, Completer<void> ready) async {
    final bytes = switch (event) {
      final String text => utf8.encode(text),
      final List<int> data => data,
      _ => const <int>[],
    };
    if (bytes.isEmpty) return;
    _buffer.add(bytes);
    final parsed = mqttFrames(_buffer.toBytes());
    if (parsed.overflow) {
      _buffer.clear();
      AppLog.warn('salon: flux coupé, trame refusée');
      _onDone();
      final socket = _socket;
      _socket = null;
      _closed = true;
      if (socket != null) {
        unawaited(socket.close().catchError((Object error) {
          AppLog.warn('salon: fermeture · $error');
        }));
      }
      return;
    }
    _buffer
      ..clear()
      ..add(parsed.rest);
    for (final frame in parsed.frames) {
      final kind = frame.type >> 4;
      if (kind == 2) {
        final ok = frame.body.length >= 2 && frame.body[1] == 0;
        if (!ok) {
          if (!ready.isCompleted) {
            ready.completeError(StateError('refus'));
          }
          return;
        }
        _socket?.add(mqttSubscribePacket(_topic, 1));
      } else if (kind == 9 && !ready.isCompleted) {
        ready.complete();
      } else if (kind == 3) {
        final body = mqttPublishBody(frame.body);
        if (body == null) continue;
        final plain = await openForCode(code, body);
        if (plain == null) continue;
        try {
          final decoded = jsonDecode(utf8.decode(plain));
          if (decoded is Map<String, dynamic>) {
            _messages.add(decoded);
          } else if (decoded is Map) {
            _messages.add(Map<String, dynamic>.from(decoded));
          }
        } on Object {
          // Message illisible : on l’ignore.
        }
      }
    }
  }

  Future<void> send(Map<String, dynamic> message) async {
    final socket = _socket;
    if (socket == null || _closed) return;
    final payload = <String, dynamic>{...message, 'from': deviceId};
    final sealed = await sealForCode(code, utf8.encode(jsonEncode(payload)));
    socket.add(mqttPublishPacket(_topic, sealed));
  }

  void _onDone() {
    _open = false;
    _ping?.cancel();
    if (_established && !_messages.isClosed) _messages.close();
  }

  Future<void> close() async {
    _ping?.cancel();
    final socket = _socket;
    if (_established && socket != null && !_closed) {
      try {
        await send({'op': 'bye'});
        socket.add(mqttDisconnectPacket());
      } on Object {
        // Déjà coupé.
      }
    }
    _closed = true;
    _socket = null;
    if (socket != null) {
      unawaited(socket.close().catchError((_) {}));
    }
    if (!_messages.isClosed) await _messages.close();
  }
}
