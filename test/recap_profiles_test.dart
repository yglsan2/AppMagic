import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/player_profile.dart';
import 'package:mtg_table/domain/recap.dart';

void main() {
  test('récap contient vainqueur et noms', () {
    final game = Game.start(
      playerCount: 2,
      names: const ['Ana', 'Bo'],
      commanderNames: const [
        ['Atraxa'],
        ['Kraum'],
      ],
    );
    game.players[1].life = 0;
    final text = buildGameRecap(
      game: game,
      duration: const Duration(minutes: 42, seconds: 7),
    );
    expect(text, contains('Ana'));
    expect(text, contains('Vainqueur'));
    expect(text, contains('42m'));
  });

  test('chess clock débite la banque au passage de tour', () {
    final game = Game.start(
      playerCount: 2,
      timerMode: TimerMode.chess,
      chessBankSeconds: 120,
    );
    final controller = GameController(game: game);
    addTearDown(controller.dispose);
    expect(controller.game.players.first.clockBankMs, 120000);
    // Simule un tour de 5s déjà écoulé
    controller.turnStarted = DateTime.now().subtract(
      const Duration(seconds: 5),
    );
    controller.nextTurn();
    expect(controller.game.players.first.clockBankMs, lessThan(120000));
    expect(controller.game.players.first.clockBankMs, greaterThan(100000));
  });

  test('profil sérialise correctement', () {
    final profile = PlayerProfile.fromDraft(
      name: 'Léa',
      color: 2,
      commanders: const ['Meren'],
      arts: const ['https://example.com/a.jpg'],
    );
    final round = PlayerProfile.fromJson(profile.toJson());
    expect(round.name, 'Léa');
    expect(round.commanders, ['Meren']);
    expect(round.commanderArts.first, contains('example.com'));
  });

  test('export journal inclut fil PV et actions', () {
    final controller = GameController(
      game: Game.start(
        playerCount: 2,
        names: const ['Ana', 'Bo'],
      ),
    );
    addTearDown(controller.dispose);
    controller.addLife(controller.game.players.first.id, -3);
    final text = buildJournalExport(controller);
    expect(text, contains('Journal Table MTG'));
    expect(text, contains('Fil PV'));
    expect(text, contains('Actions'));
    expect(text, contains('Ana'));
  });

  test('construit et limité ont des libellés distincts', () {
    expect(
      formatInfo(MatchFormat.constructed).label,
      contains('60 cartes'),
    );
    expect(formatInfo(MatchFormat.limited).label, contains('draft'));
    expect(formatInfo(MatchFormat.constructed).startingLife, 20);
    expect(formatInfo(MatchFormat.limited).startingLife, 20);
  });
}
