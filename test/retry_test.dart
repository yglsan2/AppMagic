import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/data/retry.dart';

void main() {
  test('withFourTries réussit au 3e essai', () async {
    var n = 0;
    final value = await withFourTries(() async {
      n++;
      if (n < 3) throw StateError('fail');
      return n;
    }, baseDelay: Duration.zero);
    expect(value, 3);
    expect(n, 3);
  });

  test('withFourTriesOrNull après 4 échecs', () async {
    var n = 0;
    final value = await withFourTriesOrNull(() async {
      n++;
      throw StateError('fail');
    }, baseDelay: Duration.zero);
    expect(value, isNull);
    expect(n, 4);
  });

  test('withFourTriesResult expose le message', () async {
    final result = await withFourTriesResult(
      () async {
        throw StateError('x');
      },
      baseDelay: Duration.zero,
      failMessage: 'Échec final',
    );
    expect(result.ok, isFalse);
    expect(result.errorMessage, 'Échec final');
  });

  test('le finally court une fois, succès ou abandon', () async {
    var done = 0;
    final value = await withFourTries(
      () async => 7,
      onFinally: () async => done++,
    );
    expect(value, 7);
    expect(done, 1);

    var fails = 0;
    final missed = await withFourTries<int>(
      () async => throw StateError('fail'),
      baseDelay: Duration.zero,
      onGiveUp: (_, _) async => 0,
      onFinally: () async => fails++,
    );
    expect(missed, 0);
    expect(fails, 1);
  });
}
