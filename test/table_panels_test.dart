import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/table_panels.dart';

void main() {
  test('besoin téléphone selon l’effectif', () {
    expect(phoneNeedFor(4), TablePhoneNeed.one);
    expect(phoneNeedFor(6), TablePhoneNeed.oneOrTwo);
    expect(phoneNeedFor(8), TablePhoneNeed.oneOrTwo);
    expect(phoneNeedFor(9), TablePhoneNeed.three);
    expect(phoneNeedFor(10), TablePhoneNeed.three);
  });

  test('suggestion 6–8 et contrainte 9–10', () {
    expect(suggestedPhoneCount(7, preferMulti: false), 1);
    expect(suggestedPhoneCount(7, preferMulti: true), 2);
    expect(suggestedPhoneCount(10, preferMulti: false), 3);
    expect(minPhonesFor(10), 3);
    expect(maxPhonesFor(7), 2);
  });

  test('mode minimal uniquement 6–8 sur un écran', () {
    expect(useMinimalBand(6, phoneCount: 1), isTrue);
    expect(useMinimalBand(8, phoneCount: 1), isTrue);
    expect(useMinimalBand(6, phoneCount: 2), isFalse);
    expect(useMinimalBand(4, phoneCount: 1), isFalse);
    expect(useMinimalBand(10, phoneCount: 3), isFalse);
  });

  test('deux panneaux découpent toute la table', () {
    const players = 8;
    final a = panelSeatIndexes(players: players, panelIndex: 0, panelCount: 2);
    final b = panelSeatIndexes(players: players, panelIndex: 1, panelCount: 2);
    expect(a.intersection(b), isEmpty);
    expect(a.union(b).length, players);
    expect(a.length + b.length, players);
  });

  test('trois panneaux pour 9–10', () {
    for (final players in [9, 10]) {
      final parts = [
        for (var i = 0; i < 3; i++)
          panelSeatIndexes(players: players, panelIndex: i, panelCount: 3),
      ];
      final all = parts.expand((s) => s).toSet();
      expect(all.length, players);
      for (var i = 0; i < 3; i++) {
        for (var j = i + 1; j < 3; j++) {
          expect(parts[i].intersection(parts[j]), isEmpty);
        }
      }
      final plan = panelPlan(players: players, panelIndex: 1, panelCount: 3);
      final shown = [
        ...plan.south,
        ...plan.north,
        ...plan.westTopToBottom,
        ...plan.eastTopToBottom,
      ];
      expect(shown.toSet(), parts[1]);
    }
  });

  test('libellés et ids de panneau', () {
    expect(panelLabel(0), 'A');
    expect(panelLabel(2), 'C');
    expect(isPanelSeat(panelSeatId(1)), isTrue);
    expect(panelIndexFromSeat(panelSeatId(1)), 1);
    expect(isPanelSeat('p1'), isFalse);
  });
}
