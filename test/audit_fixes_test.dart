import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/planar_decks.dart';
import 'package:mtg_table/domain/recap.dart';
import 'package:mtg_table/domain/stats.dart';

void main() {
  test('2HG : équipe gagnante (2 vivants) → bannière et archive', () {
    final game = Game.start(
      format: MatchFormat.twoHeaded,
      playerCount: 4,
      names: const ['A1', 'A2', 'B1', 'B2'],
      sharedLife: true,
    );
    expect(game.sharedLife, isTrue);
    // Équipe B éliminée
    game.players[2].life = 0;
    game.players[3].life = 0;
    expect(game.victoryBanner(), contains('A1'));
    expect(game.victoryBanner(), contains('A2'));
    expect(game.winnerLabel(), 'A1 & A2');
    final archived = ArchivedGame.fromMatch(
      game: game,
      duration: const Duration(minutes: 10),
    );
    expect(archived.winner, 'A1 & A2');
    final recap = buildGameRecap(game: game, duration: Duration.zero);
    expect(recap, contains('A1 & A2'));
  });

  test('Traîtrise : révélation publique', () {
    final game = Game.start(
      format: MatchFormat.treachery,
      playerCount: 4,
      names: const ['A', 'B', 'C', 'D'],
    );
    final controller = GameController(game: game);
    addTearDown(controller.dispose);
    controller.dealTreacheryRoles();
    final player = game.players.first;
    expect(player.treacheryRole, isNot(TreacheryRole.none));
    expect(player.treacheryRevealed, isFalse);
    controller.revealTreachery(player.id);
    expect(player.treacheryRevealed, isTrue);
  });

  test('claim bounty passe au contrat du joueur', () {
    final game = Game.start(playerCount: 2, bounty: true);
    final controller = GameController(game: game);
    addTearDown(controller.dispose);
    final player = game.players.first;
    final before = player.bountyIndex;
    controller.claimBounty(player.id);
    expect(player.bountyIndex, (before + 1) % officialBounties.length);
    expect(game.players[1].bountyIndex, 1);
    expect(controller.lifeFeed.first, contains('prime'));
    expect(controller.canUndo, isTrue);
  });

  test('chess : banque restante baisse pendant le tour', () {
    final game = Game.start(
      playerCount: 2,
      timerMode: TimerMode.chess,
      timersEnabled: true,
      chessBankSeconds: 120,
    );
    final controller = GameController(game: game);
    addTearDown(controller.dispose);
    controller.turnStarted = DateTime.now().subtract(
      const Duration(seconds: 10),
    );
    expect(controller.activeBankRemaining.inSeconds, lessThan(120));
    expect(controller.activeBankRemaining.inSeconds, greaterThan(100));
  });
}
