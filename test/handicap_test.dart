import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/handicap.dart';
import 'package:mtg_table/domain/models.dart';

void main() {
  test('échelle : 1 point = 5 PV sur les raccourcis', () {
    expect(DeckBracket.precon.suggestedLifeDelta, 10);
    expect(DeckBracket.budget.suggestedLifeDelta, 5);
    expect(DeckBracket.fair.suggestedLifeDelta, 0);
    expect(DeckBracket.strong.suggestedLifeDelta, -5);
    expect(DeckBracket.cedh.suggestedLifeDelta, -10);
  });

  test('précon vs cEDH et valeur perso', () {
    expect(
      effectiveStartingLife(
        baseLife: 40,
        handicapsEnabled: true,
        lifeDelta: 10,
      ),
      50,
    );
    expect(
      effectiveStartingLife(
        baseLife: 40,
        handicapsEnabled: true,
        lifeDelta: -10,
      ),
      30,
    );
    expect(
      effectiveStartingLife(
        baseLife: 40,
        handicapsEnabled: true,
        lifeDelta: 7,
      ),
      47,
    );
    expect(
      effectiveStartingLife(
        baseLife: 40,
        handicapsEnabled: false,
        lifeDelta: -10,
      ),
      40,
    );
  });

  test('bracketMatchingLifeDelta détecte perso', () {
    expect(bracketMatchingLifeDelta(10), DeckBracket.precon);
    expect(bracketMatchingLifeDelta(7), DeckBracket.custom);
    expect(bracketMatchingLifeDelta(0), DeckBracket.fair);
  });

  test('Game.start applique delta personnalisé', () {
    final game = Game.start(
      playerCount: 2,
      handicapsEnabled: true,
      names: const ['A', 'B'],
      handicapLifeDeltas: const [12, -8],
      commanderNames: const [
        ['A'],
        ['B'],
      ],
    );
    expect(game.players[0].life, 52);
    expect(game.players[1].life, 32);
    expect(game.players[0].deckBracket, DeckBracket.custom);
    expect(game.players[1].deckBracket, DeckBracket.custom);
  });

  test('revanche conserve les vies handicapées', () {
    final controller = GameController(
      game: Game.start(
        playerCount: 2,
        handicapsEnabled: true,
        deckBrackets: const [DeckBracket.budget, DeckBracket.strong],
        names: const ['A', 'B'],
      ),
    );
    addTearDown(controller.dispose);
    controller.addLife(controller.game.players[0].id, -10);
    controller.rematch();
    expect(controller.game.players[0].life, 45);
    expect(controller.game.players[1].life, 35);
  });

  test('setDeckHandicap perso ajuste la vie courante', () {
    final controller = GameController(
      game: Game.start(
        playerCount: 2,
        handicapsEnabled: true,
        names: const ['A', 'B'],
      ),
    );
    addTearDown(controller.dispose);
    final a = controller.game.players[0];
    expect(a.life, 40);
    controller.setDeckHandicap(a.id, lifeDelta: 15);
    expect(a.handicapLifeDelta, 15);
    expect(a.deckBracket, DeckBracket.custom);
    expect(a.life, 55);
  });

  test('migration JSON fineTune + bracket', () {
    final player = Player.fromJson({
      'id': 'p1',
      'name': 'Test',
      'color': 0,
      'life': 45,
      'deckBracket': 'budget',
      'handicapFineTune': 3,
      'mana': <String, int>{},
      'commanders': <Object>[],
    });
    expect(player.handicapLifeDelta, 8);
    expect(player.deckBracket, DeckBracket.custom);
  });

  test('vie partagée ignore les handicaps', () {
    final game = Game.start(
      format: MatchFormat.twoHeaded,
      playerCount: 4,
      handicapsEnabled: true,
      handicapLifeDeltas: const [10, -10, 10, -10],
    );
    expect(game.handicapsEnabled, isFalse);
    expect(game.players.every((p) => p.life == game.startingLife), isTrue);
  });
}
