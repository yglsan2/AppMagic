import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/deck_audit.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/journal_event.dart';
import 'package:mtg_table/domain/life_series.dart';
import 'package:mtg_table/domain/mana_curve.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/play_structure.dart';
import 'package:mtg_table/domain/stats.dart';

void main() {
  test('la banque dépasse en négatif et rend le bonus', () {
    final game = Game.start(
      playerCount: 2,
      names: const ['Ana', 'Bo'],
      timerMode: TimerMode.chess,
      timersEnabled: true,
      chessBankSeconds: 120,
      chessBonusSeconds: 10,
    );
    final controller = GameController(game: game);
    addTearDown(controller.dispose);
    controller.turnStarted = DateTime.now().subtract(const Duration(seconds: 30));
    controller.nextTurn();
    final ana = game.players.first.clockBankMs;
    expect(ana, lessThan(110000));
    expect(ana, greaterThan(90000));
    expect(game.players.first.timeSpentMs, greaterThan(25000));

    game.players[game.activeIndex].clockBankMs = 4000;
    controller.turnStarted = DateTime.now().subtract(const Duration(seconds: 20));
    final before = game.players[game.activeIndex].id;
    controller.nextTurn();
    final left = game.players.firstWhere((player) => player.id == before);
    expect(left.clockBankMs, lessThan(0));
  });

  test('le graphe suit les points de vie', () {
    final controller = GameController(
      game: Game.start(playerCount: 2, names: const ['Ana', 'Bo'], startingLife: 40),
    );
    addTearDown(controller.dispose);
    controller.addLife(controller.game.players.first.id, -5);
    final series = lifeSeries(controller.game, controller.lifeLog);
    final points = series[controller.game.players.first.id]!;
    expect(points.first.life, 40);
    expect(points.last.life, 35);
  });

  test('une courbe lourde demande des terrains', () {
    final lines = parseDeckList('Commander\n20 Forest\n60 Big Spell');
    expect(lines, hasLength(2));
    final cards = [
      basicCurveCard('Forest', 20)!,
      for (var i = 0; i < 60; i++)
        const CurveCard(name: 'Big Spell', count: 1, mv: 6, manaCost: '{6}'),
    ];
    final report = buildCurve(cards);
    expect(report.lands, 20);
    expect(report.advice.join(' '), contains('manque'));
    expect(report.advice.join(' '), contains('lourde'));
  });

  test('les stats relient un commandant à ses victoires', () {
    final ledger = LocalLedger(
      games: [
        ArchivedGame(
          id: 'a',
          endedAtMs: 1,
          format: 'commander',
          players: const ['Ana', 'Bo'],
          winner: 'Ana',
          durationSec: 3600,
          planechase: false,
          commanders: const ['Ana · Atraxa'],
        ),
        ArchivedGame(
          id: 'b',
          endedAtMs: 2,
          format: 'commander',
          players: const ['Ana', 'Bo'],
          winner: 'Bo',
          durationSec: 1800,
          planechase: false,
          commanders: const ['Ana · Atraxa'],
        ),
        ArchivedGame(
          id: 'c',
          endedAtMs: 3,
          format: 'commander',
          players: const ['Ana', 'Bo'],
          winner: 'Ana',
          durationSec: 1800,
          planechase: false,
          commanders: const ['Ana · Atraxa'],
        ),
      ],
    );
    final record = ledger.commanderNamed('Atraxa');
    expect(record?.games, 3);
    expect(record?.wins, 2);
    expect(ledger.averageDurationSec(), 2400);
    final advice = buildCurve(
      const [
        CurveCard(name: 'Spell', count: 20, mv: 4, manaCost: '{2}{G}{G}'),
        CurveCard(name: 'Forest', count: 36, mv: 0, land: true, produces: ['G']),
      ],
      context: CurveContext(
        averageGameSec: ledger.averageDurationSec(),
        commanderName: record?.commander,
        commanderWins: record?.wins,
        commanderGames: record?.games,
      ),
    );
    expect(advice.advice.join(' '), contains('Atraxa'));
  });

  test('quarante terrains plus la préparation étouffent les créatures', () {
    final notes = deckStructureNotes(
      lands: 40,
      ramp: 12,
      draw: 10,
      creatures: 14,
      threats: 3,
      spells: 59,
    );
    expect(notes.join(' '), contains('40 terrains'));
    expect(notes.join(' '), contains('créatures'));
    expect(notes.join(' '), contains('menaces'));
  });

  test('le journal de soirée voit la préparation sans les menaces', () {
    final game = Game.start(playerCount: 2, names: const ['Bo', 'Ana']);
    final id = game.players.first.id;
    JournalEvent play(String name, String type, {String oracle = '', int? mv}) {
      return JournalEvent(
        id: name,
        kind: JournalKind.cardPlayed,
        label: 'Bo · $name',
        createdAtMs: 1,
        roundNumber: 1,
        turnCount: 1,
        sourcePlayerId: id,
        cardName: name,
        cardTypeLine: type,
        oracleText: oracle,
        manaValue: mv,
      );
    }

    final events = [
      for (var i = 0; i < 8; i++) play('Forêt $i', 'Basic Land — Forest'),
      for (var i = 0; i < 4; i++)
        play('Rampe $i', 'Sorcery', oracle: 'Search your library for a land card.'),
      play('Pioche', 'Sorcery', oracle: 'Draw three cards.'),
      play('Petite', 'Creature — Elf', mv: 2),
    ];
    final seats = journalStructure(game, events);
    expect(seats.single.lands, 8);
    expect(seats.single.ramp, 4);
    expect(seats.single.notes.join(' '), contains('préparation'));
  });

  test('la pause fige le chrono', () {
    final controller = GameController(
      game: Game.start(playerCount: 2, timersEnabled: true),
    );
    addTearDown(controller.dispose);
    controller.turnStarted = DateTime.now().subtract(const Duration(seconds: 5));
    final frozen = controller.turnElapsed;
    controller.pauseClock();
    expect(controller.clockPaused, isTrue);
    expect(controller.turnElapsed.inSeconds, frozen.inSeconds);
  });

  test('l’analyse sépare commandant, deck et réserve', () {
    final zoned = parseZonedDeck('''
Commandant
1 Atraxa, Praetors' Voice
Deck
36 Forest
63 Sol Ring
Réserve
10 Swords to Plowshares
1 Forest
''');
    expect(zoned.commander.single.name, 'Atraxa, Praetors\' Voice');
    expect(zoned.total, 110);
    expect(zoned.dropped, 1);
    expect(zoned.sideboard.fold(0, (sum, line) => sum + line.count), 10);
    final audit = auditDeck(
      commander: const [
        CurveCard(name: 'Atraxa', count: 1, mv: 4, creature: true),
      ],
      main: [
        basicCurveCard('Forest', 40)!,
        for (var i = 0; i < 12; i++)
          const CurveCard(name: 'Rampe', count: 1, mv: 2, ramp: true, sorcery: true),
        for (var i = 0; i < 10; i++)
          const CurveCard(name: 'Pioche', count: 1, mv: 3, draw: true, instant: true),
        for (var i = 0; i < 14; i++)
          const CurveCard(name: 'Elfe', count: 1, mv: 2, creature: true),
        for (var i = 0; i < 23; i++)
          const CurveCard(name: 'Sort', count: 1, mv: 4),
      ],
      side: const [],
      dropped: 0,
    );
    expect(audit.mainCards, 99);
    expect(audit.commanderCards, 1);
    expect(audit.strengths.join(' '), contains('1 + 99'));
    expect(audit.weaknesses.join(' '), contains('créatures'));
    expect(audit.portrait, contains('préparation'));
    expect(audit.advice.join(' '), contains('créatures'));
    expect(audit.advice.join(' '), contains('réponses'));
  });

  test('une liste réelle sépare le code d’édition et la réserve', () {
    final zoned = parseZonedDeck('''
Deck
1 Sol Ring (C21) 263
SB: 2 Path to Exile (A25) 27
''');
    expect(zoned.main.single.name, 'Sol Ring');
    expect(zoned.sideboard.single.name, 'Path to Exile');
    expect(zoned.sideboard.single.count, 2);
  });

  test('un deck bancal montre l’identité, les doublons et les cartes peu jouées', () {
    final audit = auditDeck(
      commander: const [
        CurveCard(
          name: 'Heliod',
          count: 1,
          mv: 3,
          creature: true,
          colorIdentity: ['W'],
        ),
      ],
      main: [
        basicCurveCard('Plains', 10)!,
        const CurveCard(
          name: 'Lightning Bolt',
          count: 4,
          mv: 1,
          instant: true,
          colorIdentity: ['R'],
          manaCost: '{R}',
          edhrecRank: 20000,
          rarity: 'common',
        ),
        const CurveCard(
          name: 'Griselbrand',
          count: 1,
          mv: 8,
          creature: true,
          colorIdentity: ['B'],
          legalCommander: false,
          rarity: 'mythic',
          edhrecRank: 4000,
        ),
        for (var i = 0; i < 20; i++)
          CurveCard(
            name: 'Obscure $i',
            count: 1,
            mv: 7,
            creature: true,
            colorIdentity: ['W'],
            rarity: 'rare',
            edhrecRank: 18000,
          ),
        const CurveCard(name: 'Carte inconnue', count: 8, mv: 0, unknown: true),
        const CurveCard(
          name: 'Rats',
          count: 20,
          mv: 2,
          creature: true,
          anyNumber: true,
          colorIdentity: ['B'],
          edhrecRank: 100,
        ),
      ],
      dropped: 0,
    );
    final weak = audit.weaknesses.join(' ');
    expect(audit.unknown, 8);
    expect(audit.mainCards, 63);
    expect(audit.offIdentity, contains('Lightning Bolt'));
    expect(audit.duplicates, contains('Lightning Bolt'));
    expect(audit.duplicates, isNot(contains('Rats')));
    expect(audit.illegal, contains('Griselbrand'));
    expect(audit.rarelyPlayed, contains('Lightning Bolt'));
    expect(weak, contains('identité'));
    expect(weak, contains('peu vus'));
    expect(weak, contains('inconnues'));
    expect(audit.rarityLine, contains('rares'));
    expect(audit.advice.first, contains('jouable'));
    expect(audit.advice.join(' '), contains('terrains'));
    expect(audit.advice.join(' '), isNot(contains('réponses')));
    expect(audit.portrait, contains('pas jouable'));
  });
}
