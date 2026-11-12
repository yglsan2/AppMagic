import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/vfx_cast.dart';
import 'package:mtg_table/theme/app_theme.dart';

void main() {
  test('les paliers suivent les points perdus', () {
    expect(woundTier(0), 0);
    expect(woundTier(1), 1);
    expect(woundTier(5), 1);
    expect(woundTier(6), 2);
    expect(woundTier(10), 2);
    expect(woundTier(11), 3);
    expect(woundTier(20), 3);
    expect(woundTier(21), 4);
    expect(woundTier(80), 4);
    expect(shownWoundTier(1, LifeBand.safe), 1);
    expect(shownWoundTier(1, LifeBand.warning), 2);
    expect(shownWoundTier(1, LifeBand.critical), 3);
    expect(shownWoundTier(21, LifeBand.safe), 4);
  });

  test('le rouge seul ne prend pas le givre', () {
    final pool = castPool(
      style: FinaleStyle.rouge,
      role: VfxRole.aura,
      inks: const ['U', 'G'],
      seatColor: 1,
    );
    expect(pool, contains('aura-fire'));
    expect(pool, isNot(contains('aura-frost')));
    expect(pool, isNot(contains('aura-nature')));
  });

  test('deux couleurs mélangent sans répéter le même effet', () {
    final pool = castPool(
      style: FinaleStyle.teinte,
      role: VfxRole.hit,
      inks: const ['W', 'R'],
      seatColor: 0,
    );
    expect(pool, contains('hi-fire-burst'));
    expect(pool, contains('spell-light-impact'));
    String? previous;
    final seen = <String>{};
    for (var i = 0; i < 12; i++) {
      final next = pickClip(pool, previous, i * 5 + 2);
      expect(next, isNotNull);
      if (previous != null) expect(next, isNot(previous));
      previous = next;
      seen.add(next!);
    }
    expect(seen.length, greaterThan(1));
  });

  test('les soins n’effacent pas les blessures, l’annulation oui', () {
    const loss = LifeChange(
      playerId: 'a',
      playerName: 'Ana',
      from: 40,
      to: 30,
      delta: -10,
      turnCount: 1,
      roundNumber: 1,
    );
    const heal = LifeChange(
      playerId: 'a',
      playerName: 'Ana',
      from: 30,
      to: 34,
      delta: 4,
      turnCount: 2,
      roundNumber: 1,
    );
    const undone = LifeChange(
      playerId: 'a',
      playerName: 'Ana',
      from: 34,
      to: 30,
      delta: -4,
      turnCount: 3,
      roundNumber: 1,
      retracted: true,
    );
    expect(woundTally(const [loss, heal, undone], 'a'), 10);
  });

  test('l’épée suit une seule couleur, sinon une lame neutre', () {
    final red = swordPool(const ['R'], 1);
    expect(red, contains('blade-r-1'));
    expect(red, contains('slash-fire-up'));
    expect(red, isNot(contains('blade-w-1')));
    final white = swordPool(const ['W', 'B'], 0);
    expect(white, contains('blade-w-1'));
    expect(white, isNot(contains('blade-b-1')));
    final black = swordPool(const ['W', 'B'], 1);
    expect(black, contains('blade-b-1'));
    expect(black, isNot(contains('blade-w-1')));
    expect(swordPool(const [], 4), ['slash-neutral']);
    String? previous;
    for (var i = 0; i < 8; i++) {
      final next = pickClip(red, previous, i + 1);
      if (previous != null) expect(next, isNot(previous));
      previous = next;
    }
  });

  test('plusieurs teintes en tirent une, l’inconnue reste neutre', () {
    final white = castPool(
      style: FinaleStyle.teinte,
      role: VfxRole.hit,
      inks: const ['W', 'R'],
      seatColor: 2,
      salt: 0,
    );
    expect(white, contains('spell-light-impact'));
    expect(white, isNot(contains('hi-fire-burst')));
    final fire = castPool(
      style: FinaleStyle.teinte,
      role: VfxRole.hit,
      inks: const ['W', 'R'],
      seatColor: 2,
      salt: 1,
    );
    expect(fire, contains('chain-infernal'));
    expect(fire, isNot(contains('spell-light-impact')));
    final unknown = castPool(
      style: FinaleStyle.teinte,
      role: VfxRole.hit,
      inks: const [],
      seatColor: 2,
    );
    expect(unknown, contains('slash-neutral'));
    expect(unknown, isNot(contains('ember-fireball')));
  });

  test('une perte sans attaquant ne sort pas d’épée', () {
    const self = LifeChange(
      playerId: 'a',
      playerName: 'Ana',
      from: 40,
      to: 39,
      delta: -1,
      turnCount: 2,
      roundNumber: 1,
    );
    const struck = LifeChange(
      playerId: 'a',
      playerName: 'Ana',
      from: 39,
      to: 36,
      delta: -3,
      turnCount: 1,
      roundNumber: 1,
      sourceId: 'b',
    );
    expect(latestStrike(const [self, struck], 'a'), isNull);
    expect(latestStrike(const [struck], 'a'), 'b');
  });

  test('la blessure suit le choix du joueur', () {
    expect(woundFamily(CastTone.aucune, const ['R']).aura, isEmpty);
    expect(woundHits(CastTone.aucune, const ['R'], 1), isEmpty);
    expect(woundFamily(CastTone.rouge, const []).aura, 'aura-fire');
    expect(woundFamily(CastTone.bleu, const []).aura, 'bleu-runes');
    expect(woundFamily(CastTone.blanc, const []).aura, 'aura-radiant');
    expect(woundFamily(CastTone.standard, const ['R']).aura, 'veil-smoke');
    expect(woundFamily(CastTone.teinte, const []).aura, 'veil-smoke');
    expect(woundFamily(CastTone.faille, const []).aura, 'faille-rift');
    expect(woundHits(CastTone.faille, const [], 0), contains('chain-void'));
    expect(woundFamily(CastTone.sceau, const []).aura, 'ash-sigil');
    expect(woundFamily(CastTone.pilier, const []).aura, 'ash-pillar');
    expect(woundFamily(CastTone.nova, const []).aura, 'nova-ring');
    expect(woundHits(CastTone.standard, const [], 0), contains('ash-shatter'));
    expect(woundFamily(CastTone.teinte, const ['U']).aura, 'bleu-runes');
    final blue = woundHits(CastTone.teinte, const ['U', 'R'], 0);
    final red = woundHits(CastTone.teinte, const ['U', 'R'], 1);
    expect(blue, contains('bleu-bruine'));
    expect(red, contains('chain-infernal'));
    expect(blue, isNot(contains('chain-infernal')));
    expect(woundHits(CastTone.blanc, const [], 0), contains('slash-holy-up'));
    expect(woundHits(CastTone.blanc, const [], 0), isNot(contains('chain-infernal')));
  });

  test('une seule couleur disponible peut se répéter', () {
    expect(pickClip(const ['aura-fire'], 'aura-fire', 3), 'aura-fire');
  });
}
