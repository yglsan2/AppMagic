import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/net/table_link.dart';

void main() {
  test('deux téléphones gardent chacun leur changement', () async {
    final hostGame = GameController(
      game: Game.start(
        playerCount: 2,
        names: const ['A', 'B'],
      ),
    );
    final host = TableLinkController();
    final guestA = TableLinkController();
    final guestB = TableLinkController();
    host.onSession = hostGame.adoptSession;
    hostGame.addListener(() {
      if (!hostGame.applyingRemote && host.linked) {
        host.publishLocal(hostGame.exportSession());
      }
    });

    await host.hostTable(hostGame.exportSession());
    final port = host.port!;

    Future<GameController> join(TableLinkController link) async {
      final ok = await link.joinTable('127.0.0.1:$port');
      expect(ok, isTrue);
      final game = GameController.restore(link.latestSession!);
      link.onSession = game.adoptSession;
      game.addListener(() {
        if (!game.applyingRemote && link.linked) {
          link.publishLocal(game.exportSession());
        }
      });
      return game;
    }

    final gameA = await join(guestA);
    final gameB = await join(guestB);
    final first = hostGame.game.players[0].id;
    final second = hostGame.game.players[1].id;
    guestA.claim(first);
    guestB.claim(second);

    gameA.addLife(first, -1);
    gameB.addLife(second, -1);

    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(hostGame.playerById(first).life, 39);
    expect(hostGame.playerById(second).life, 39);
    expect(gameA.playerById(first).life, 39);
    expect(gameA.playerById(second).life, 39);
    expect(gameB.playerById(first).life, 39);
    expect(gameB.playerById(second).life, 39);
    expect(guestA.mySeat, first);
    expect(guestB.mySeat, second);

    await guestA.stop();
    await guestB.stop();
    await host.stop();
  });

  test('la bande garde les deux pertes', () {
    final host = GameController(
      game: Game.start(playerCount: 2, names: const ['A', 'B']),
    );
    final base = host.exportSession();
    final left = GameController.restore(base);
    final right = GameController.restore(base);
    final first = left.game.players[0].id;
    final second = left.game.players[1].id;
    left.addLife(first, -1);
    right.addLife(second, -2);
    final merged = mergeSessions(
      base: base,
      mine: left.exportSession(),
      host: right.exportSession(),
    );
    final game = GameController.restore(merged);
    expect(game.playerById(first).life, 39);
    expect(game.playerById(second).life, 38);
    expect(game.lifeLog.map((event) => event.id).toSet(), hasLength(2));
    expect(game.lifeLog.map((event) => event.story).join(' '), contains('-1'));
    expect(game.lifeLog.map((event) => event.story).join(' '), contains('-2'));
  });

  test('un seul téléphone reprend la table', () {
    expect(tableSuccessor(const ['hôte', 'b', 'a'], 'hôte', 'b'), 'a');
    expect(tableSuccessor(const ['hôte'], 'hôte', 'moi'), 'moi');
  });

  test('la table continue quand le téléphone qui l’a ouverte s’éteint', () async {
    final hostGame = GameController(
      game: Game.start(playerCount: 2, names: const ['A', 'B']),
    );
    final host = TableLinkController();
    final guest = TableLinkController();
    addTearDown(() async {
      await guest.stop();
      await host.stop();
    });
    await host.hostTable(hostGame.exportSession());
    final room = host.code!;
    final ok = await guest.joinTable('127.0.0.1:${host.port}');
    expect(ok, isTrue);
    final game = GameController.restore(guest.latestSession!);
    guest.onSession = game.adoptSession;
    game.addListener(() {
      if (!game.applyingRemote && guest.linked) {
        guest.publishLocal(game.exportSession());
      }
    });
    final lifeId = game.game.players.first.id;
    await host.stop();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(guest.hosting, isTrue);
    expect(guest.code, room);
    game.addLife(lifeId, -1);
    expect(game.playerById(lifeId).life, 39);
  });

  test('une table pleine refuse le téléphone en trop', () async {
    final host = TableLinkController();
    final guest = TableLinkController();
    addTearDown(() async {
      await guest.stop();
      await host.stop();
    });
    await host.hostTable(
      GameController(
        game: Game.start(playerCount: 1, names: const ['A']),
      ).exportSession(),
      maxPhones: 1,
    );
    final ok = await guest.joinTable('127.0.0.1:${host.port}');
    expect(ok, isFalse);
    expect(guest.linked, isFalse);
    expect(guest.status, 'Cette table est pleine (1 téléphone).');
  });

  test('sans Wi-Fi Direct, le groupe isolé le dit', () async {
    final link = TableLinkController();
    addTearDown(link.stop);
    final ok = await link.hostDirect(<String, dynamic>{});
    expect(ok, isFalse);
    expect(link.linked, isFalse);
    expect(link.status, contains('Android'));
  });
}
