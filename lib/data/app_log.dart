import 'package:flutter/foundation.dart';

/// Journal applicatif (debug / diagnostics). Pas d’envoi réseau.
class AppLog {
  AppLog._();

  static const int maxEntries = 80;
  static final List<String> recent = <String>[];

  static void info(String message) => _write('I', message);

  static void warn(String message) => _write('W', message);

  static void error(
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    final detail = error == null ? message : '$message · $error';
    _write('E', detail);
    if (kDebugMode && stack != null) {
      debugPrint(stack.toString());
    }
  }

  static void _write(String level, String message) {
    final line =
        '${DateTime.now().toIso8601String()} [$level] $message';
    recent.add(line);
    if (recent.length > maxEntries) {
      recent.removeRange(0, recent.length - maxEntries);
    }
    if (kDebugMode) {
      debugPrint(line);
    }
  }
}
