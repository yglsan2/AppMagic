import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/data/safe_image.dart';
import 'package:mtg_table/domain/session_transfer.dart';

void main() {
  group('isTrustedImageUrl', () {
    test('accepte Scryfall HTTPS', () {
      expect(
        isTrustedImageUrl('https://cards.scryfall.io/art_crop/front/a/b/x.jpg'),
        isTrue,
      );
      expect(
        isTrustedImageUrl(
          'https://c1.scryfall.com/file/scryfall-cards/normal/x.jpg',
        ),
        isTrue,
      );
    });

    test('refuse HTTP, hosts étrangers, javascript', () {
      expect(isTrustedImageUrl('http://cards.scryfall.io/x.jpg'), isFalse);
      expect(isTrustedImageUrl('https://evil.example/x.jpg'), isFalse);
      expect(isTrustedImageUrl('javascript:alert(1)'), isFalse);
      expect(isTrustedImageUrl(null), isFalse);
      expect(isTrustedImageUrl(''), isFalse);
    });
  });

  group('session transfer limits', () {
    test('refuse entrée trop longue', () {
      final huge = 'MTGS1.${'A' * (maxTransferInputChars + 10)}';
      expect(decodeSessionTransfer(huge), isNull);
    });

    test('round-trip session minimale', () {
      final session = {
        'game': {
          'format': 'commander',
          'players': [
            {
              'id': 'p1',
              'name': 'A',
              'life': 40,
              'startingLife': 40,
              'color': 0xFF000000,
            },
          ],
        },
      };
      final code = encodeSessionTransfer(session);
      expect(code, isNotNull);
      expect(code!.startsWith('MTGS1.'), isTrue);
      final decoded = decodeSessionTransfer(code);
      expect(decoded, isNotNull);
      expect(decoded!['game'], isA<Map>());
    });

    test('refuse codes invalides ou sans game', () {
      expect(decodeSessionTransfer('MTGS1.not-valid-base64!!!'), isNull);
      expect(decodeSessionTransfer('PASUNCODE'), isNull);
      final noGame = encodeSessionTransfer({'oops': true});
      // Encode réussit, decode exige map['game'] is Map → null.
      expect(noGame, isNotNull);
      expect(decodeSessionTransfer(noGame!), isNull);
    });
  });
}
