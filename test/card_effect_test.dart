import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/data/scryfall_card.dart';
import 'package:mtg_table/domain/card_effect_engine.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/journal_event.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/session_transfer.dart';

void main() {
  group('CardEffectEngine', () {
    test('template Lightning Bolt', () {
      const card = ScryfallCard(
        name: 'Lightning Bolt',
        typeLine: 'Instant',
        oracleText: 'Lightning Bolt deals 3 damage to any target.',
        isLand: false,
        isCreature: false,
      );
      final suggestions = cardEffectEngine.suggest(card);
      expect(suggestions, isNotEmpty);
      expect(suggestions.first.amount, -3);
      expect(suggestions.first.scope, EffectScope.target);
    });

    test('parse each opponent loses life (EN)', () {
      final suggestions = cardEffectEngine.parseOracleEffects(
        'Each opponent loses 2 life. You gain life equal to the life lost this way.',
      );
      expect(
        suggestions.any((s) => s.scope == EffectScope.opponents && s.amount == -2),
        isTrue,
      );
    });

    test('parse FR adversaire perd', () {
      final suggestions = cardEffectEngine.parseOracleEffects(
        'Chaque adversaire perd 3 points de vie.',
      );
      expect(suggestions, isNotEmpty);
      expect(suggestions.first.amount, -3);
      expect(suggestions.first.scope, EffectScope.opponents);
    });

    test('resolve targets apply signed life', () {
      final suggestion = const EffectSuggestion(
        kind: EffectKind.life,
        amount: -3,
        scope: EffectScope.target,
        label: 'Inflige 3 blessures',
      );
      final deltas = cardEffectEngine.resolveDeltas(
        suggestion: suggestion,
        controllerId: 'a',
        allPlayerIds: const ['a', 'b', 'c'],
        targetIds: const ['b'],
        resolvedAmount: 3,
      );
      expect(deltas, hasLength(1));
      expect(deltas.first.playerId, 'b');
      expect(deltas.first.lifeDelta, -3);
    });
  });

  group('Journal + session', () {
    test('commit journal event change life and undo restores', () {
      final controller = GameController(
        game: Game.start(
          playerCount: 3,
          names: const ['A', 'B', 'C'],
        ),
      );
      addTearDown(controller.dispose);
      final b = controller.game.players[1];
      controller.commitJournalEvent(
        JournalEvent(
          id: 'e1',
          kind: JournalKind.assistedEffect,
          label: 'A · Lightning Bolt · Inflige 3',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          roundNumber: 1,
          turnCount: 1,
          sourcePlayerId: controller.game.players[0].id,
          cardName: 'Lightning Bolt',
          deltas: [AppliedDelta(playerId: b.id, lifeDelta: -3)],
          assisted: true,
        ),
      );
      expect(controller.playerById(b.id).life, 37);
      expect(controller.journal, hasLength(1));
      controller.undo();
      expect(controller.playerById(b.id).life, 40);
      expect(controller.journal, isEmpty);
    });

    test('session transfer round-trip keeps journal', () {
      final controller = GameController(
        game: Game.start(playerCount: 2, names: const ['A', 'B']),
      );
      addTearDown(controller.dispose);
      controller.logJournalNote(
        JournalEvent(
          id: 'n1',
          kind: JournalKind.landPlayed,
          label: 'A · Forest',
          createdAtMs: 1,
          roundNumber: 1,
          turnCount: 1,
          cardName: 'Forest',
        ),
      );
      final code = encodeSessionTransfer(controller.exportSession());
      expect(code, isNotNull);
      expect(sessionTransferFitsQr(code!) || code.startsWith('MTGS1.'), isTrue);
      final decoded = decodeSessionTransfer(code);
      expect(decoded, isNotNull);
      final restored = GameController.restore(decoded!);
      addTearDown(restored.dispose);
      expect(restored.journal, hasLength(1));
      expect(restored.journal.first.cardName, 'Forest');
    });
  });
}
