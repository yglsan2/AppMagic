import 'package:mtg_table/data/app_log.dart';

/// Méthode « 4 essais, 1 catch » : jusqu’à 4 tentatives, puis gestion finale.
///
/// Les 3 premiers échecs se retenten (backoff). Au 4ᵉ échec, [onGiveUp] reçoit
/// l’erreur (ou l’exception est relancée si [onGiveUp] est null).
Future<T> withFourTries<T>(
  Future<T> Function() action, {
  Duration baseDelay = const Duration(milliseconds: 200),
  bool Function(Object error, int attempt)? shouldRetry,
  Future<T> Function(Object error, StackTrace stack)? onGiveUp,
}) async {
  Object? lastError;
  StackTrace? lastStack;

  for (var attempt = 1; attempt <= 4; attempt++) {
    try {
      return await action();
    } on Object catch (error, stack) {
      lastError = error;
      lastStack = stack;
      final retry =
          attempt < 4 && (shouldRetry == null || shouldRetry(error, attempt));
      if (!retry) break;
      await Future<void>.delayed(baseDelay * attempt);
    }
  }

  final error = lastError!;
  final stack = lastStack!;
  AppLog.warn('abandon après 4 essais · $error');
  if (onGiveUp != null) return onGiveUp(error, stack);
  Error.throwWithStackTrace(error, stack);
}

/// Variante silencieuse : null après 4 échecs (réseau / parse).
Future<T?> withFourTriesOrNull<T>(
  Future<T?> Function() action, {
  Duration baseDelay = const Duration(milliseconds: 200),
  bool Function(Object error, int attempt)? shouldRetry,
}) {
  return withFourTries<T?>(
    action,
    baseDelay: baseDelay,
    shouldRetry: shouldRetry,
    onGiveUp: (_, _) async => null,
  );
}

/// Résultat typé pour l’UI (message FR utilisable).
class TryResult<T> {
  const TryResult.ok(T this.value) : errorMessage = null;

  const TryResult.fail(String this.errorMessage) : value = null;

  final T? value;
  final String? errorMessage;

  bool get ok => errorMessage == null;
}

Future<TryResult<T>> withFourTriesResult<T>(
  Future<T> Function() action, {
  Duration baseDelay = const Duration(milliseconds: 200),
  String failMessage = 'Échec après plusieurs tentatives.',
  bool Function(Object error, int attempt)? shouldRetry,
}) async {
  try {
    final value = await withFourTries(
      action,
      baseDelay: baseDelay,
      shouldRetry: shouldRetry,
    );
    return TryResult.ok(value);
  } on Object {
    return TryResult.fail(failMessage);
  }
}
