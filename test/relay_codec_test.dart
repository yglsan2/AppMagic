import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/net/table_link.dart';
import 'package:mtg_table/net/table_relay.dart';

void main() {
  test('le groupe isolé s’arrête à quatre téléphones', () {
    expect(directPhoneCap, 4);
  });

  test('le salon chiffre et ne se lit qu’avec le code', () async {
    const code = 'LUNE7K2Q';
    final sealed = await sealForCode(code, utf8.encode('{"op":"state"}'));
    final opened = await openForCode(code, sealed);
    expect(utf8.decode(opened!), '{"op":"state"}');
    expect(await openForCode('AUTRECODE', sealed), isNull);
    final topic = await topicForCode(code);
    expect(topic.startsWith('ls/'), isTrue);
    expect(topic.contains(code), isFalse);
  });

  test('un code collé depuis le QR redevient le code', () {
    expect(normalizeRoomCode('lsnet:ab cd-12'), 'ABCD12');
  });

  test('une trame annoncée trop grosse est refusée', () {
    final header = BytesBuilder()..addByte(0x30);
    var length = maxMqttFrameBytes + 1;
    do {
      var encoded = length % 128;
      length ~/= 128;
      if (length > 0) encoded |= 0x80;
      header.addByte(encoded);
    } while (length > 0);
    final parsed = mqttFrames(header.toBytes());
    expect(parsed.overflow, isTrue);
    expect(parsed.rest, isEmpty);
    expect(parsed.frames, isEmpty);
  });

  test('un publish MQTT se relit', () {
    final packet = mqttPublishPacket('ls/demo', utf8.encode('bonjour'));
    final parsed = mqttFrames(packet);
    expect(parsed.rest, isEmpty);
    expect(parsed.frames, hasLength(1));
    expect(parsed.frames.single.type >> 4, 3);
    expect(
      utf8.decode(mqttPublishBody(parsed.frames.single.body)!),
      'bonjour',
    );
  });

  test('un flux coupé en deux finit par donner le paquet', () {
    final packet = mqttPublishPacket('ls/demo', [1, 2, 3, 4]);
    final cut = packet.length ~/ 2;
    final first = mqttFrames(packet.sublist(0, cut));
    expect(first.frames, isEmpty);
    final second = mqttFrames([...first.rest, ...packet.sublist(cut)]);
    expect(second.frames, hasLength(1));
    expect(mqttPublishBody(second.frames.single.body), Uint8List.fromList([1, 2, 3, 4]));
  });
}
