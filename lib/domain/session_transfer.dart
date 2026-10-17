import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:mtg_table/data/app_log.dart';

const sessionTransferPrefix = 'MTGS1.';

/// Limites anti-abus (gzip bomb / payload trop gros).
const maxTransferInputChars = 180000;
const maxTransferCompressedBytes = 120000;
const maxTransferRawBytes = 1500000;

/// Encode une session complète pour QR / presse-papiers (gzip + base64).
String? encodeSessionTransfer(Map<String, dynamic> session) {
  try {
    final raw = utf8.encode(jsonEncode(session));
    if (raw.length > maxTransferRawBytes) {
      AppLog.warn('encodeSessionTransfer: session trop volumineuse (${raw.length})');
      return null;
    }
    final compressed = GZipEncoder().encode(raw);
    final code = '$sessionTransferPrefix${base64Url.encode(compressed)}';
    if (code.length > maxTransferInputChars) {
      AppLog.warn('encodeSessionTransfer: code trop long (${code.length})');
      return null;
    }
    return code;
  } on Object catch (error, stack) {
    AppLog.error('encodeSessionTransfer', error, stack);
    return null;
  }
}

Map<String, dynamic>? decodeSessionTransfer(String input) {
  final trimmed = input.trim();
  if (!trimmed.startsWith(sessionTransferPrefix)) return null;
  if (trimmed.length > maxTransferInputChars) {
    AppLog.warn('decodeSessionTransfer: entrée trop longue (${trimmed.length})');
    return null;
  }
  try {
    final payload = trimmed.substring(sessionTransferPrefix.length);
    final bytes = base64Url.decode(payload);
    if (bytes.length > maxTransferCompressedBytes) {
      AppLog.warn(
        'decodeSessionTransfer: payload compressé trop gros (${bytes.length})',
      );
      return null;
    }
    List<int> raw;
    try {
      raw = GZipDecoder().decodeBytes(bytes);
    } on Object {
      raw = bytes;
    }
    if (raw.length > maxTransferRawBytes) {
      AppLog.warn(
        'decodeSessionTransfer: JSON décompressé trop gros (${raw.length})',
      );
      return null;
    }
    final decoded = jsonDecode(utf8.decode(raw));
    Map<String, dynamic>? map;
    if (decoded is Map<String, dynamic>) {
      map = decoded;
    } else if (decoded is Map) {
      map = Map<String, dynamic>.from(decoded);
    }
    if (map == null || map['game'] is! Map) return null;
    return map;
  } on Object catch (error) {
    AppLog.warn('decodeSessionTransfer: $error');
    return null;
  }
}

/// QR version 40 ~ 2,9 Ko de données binaires ; au-delà, préférer le collage.
bool sessionTransferFitsQr(String code) => code.length <= 2200;
