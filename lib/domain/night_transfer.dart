import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:mtg_table/data/app_log.dart';
import 'package:mtg_table/domain/night_session.dart';
import 'package:mtg_table/domain/session_transfer.dart';

const nightTransferPrefix = 'MTGN1.';

/// Encode une soirée (roster + parties + pods sans snapshots géants).
String? encodeNightTransfer(NightSession night) {
  try {
    final slim = NightSession.fromJson(night.toJson());
    for (final pod in slim.pods) {
      // Les boards complets restent sur l’appareil hôte ; le partage
      // transporte le classement et l’historique.
      pod.session = null;
      if (pod.status == PodStatus.playing) {
        pod.status = PodStatus.paused;
      }
    }
    final raw = utf8.encode(jsonEncode(slim.toJson()));
    if (raw.length > maxTransferRawBytes) {
      AppLog.warn('encodeNightTransfer: trop volumineux (${raw.length})');
      return null;
    }
    final compressed = GZipEncoder().encode(raw);
    final code = '$nightTransferPrefix${base64Url.encode(compressed)}';
    if (code.length > maxTransferInputChars) {
      AppLog.warn('encodeNightTransfer: code trop long (${code.length})');
      return null;
    }
    return code;
  } on Object catch (error, stack) {
    AppLog.error('encodeNightTransfer', error, stack);
    return null;
  }
}

NightSession? decodeNightTransfer(String input) {
  final trimmed = input.trim();
  if (!trimmed.startsWith(nightTransferPrefix)) return null;
  if (trimmed.length > maxTransferInputChars) {
    AppLog.warn('decodeNightTransfer: entrée trop longue');
    return null;
  }
  try {
    final payload = trimmed.substring(nightTransferPrefix.length);
    final bytes = base64Url.decode(payload);
    if (bytes.length > maxTransferCompressedBytes) return null;
    List<int> raw;
    try {
      raw = GZipDecoder().decodeBytes(bytes);
    } on Object {
      raw = bytes;
    }
    if (raw.length > maxTransferRawBytes) return null;
    final decoded = jsonDecode(utf8.decode(raw));
    Map<String, dynamic>? map;
    if (decoded is Map<String, dynamic>) {
      map = decoded;
    } else if (decoded is Map) {
      map = Map<String, dynamic>.from(decoded);
    }
    if (map == null || map['id'] is! String) return null;
    return NightSession.fromJson(map);
  } on Object catch (error) {
    AppLog.warn('decodeNightTransfer: $error');
    return null;
  }
}

bool nightTransferFitsQr(String code) => code.length <= 2200;
