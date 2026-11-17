import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/l10n/app_lang.dart';
import 'package:mtg_table/l10n/catalog_en.dart';
import 'package:mtg_table/l10n/catalog_fr.dart';
import 'package:mtg_table/l10n/catalog_lv.dart';
import 'package:mtg_table/l10n/l10n.dart';

void main() {
  test('les trois catalogues ont les mêmes clés', () {
    expect(catalogEn.keys.toSet(), catalogFr.keys.toSet());
    expect(catalogLv.keys.toSet(), catalogFr.keys.toSet());
    expect(catalogFr.length, greaterThan(200));
  });

  test('les traductions ne sont pas vides', () {
    for (final entry in catalogEn.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: 'en ${entry.key}');
    }
    for (final entry in catalogLv.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: 'lv ${entry.key}');
    }
  });

  test('L10n remplace les variables', () {
    final en = const L10n(AppLang.en);
    expect(
      en.t('victory_solo', {'name': 'Ana'}),
      'Ana wins the game',
    );
    final lv = const L10n(AppLang.lv);
    expect(
      lv.t('victory_solo', {'name': 'Ana'}),
      'Ana uzvar spēli',
    );
  });

  test('drapeaux et noms natifs', () {
    expect(AppLang.fr.flag, '🇫🇷');
    expect(AppLang.en.flag, '🇬🇧');
    expect(AppLang.lv.flag, '🇱🇻');
    expect(AppLang.lv.nativeName, 'Latviešu');
  });
}
