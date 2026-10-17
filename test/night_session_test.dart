import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/night_session.dart';
import 'package:mtg_table/domain/night_transfer.dart';
import 'package:mtg_table/domain/stats.dart';

void main() {
  test('classement : points win solo / équipe / présence', () {
    final night = NightSession.create(title: 'Test', podCount: 2);
    night.addPlayer('Ana');
    night.addPlayer('Bo');
    night.addPlayer('Céline');
    night.addPlayer('Dan');
    night.recordGame(
      ArchivedGame(
        id: 'g1',
        endedAtMs: 1,
        format: 'commander',
        players: const ['Ana', 'Bo', 'Céline', 'Dan'],
        winner: 'Ana',
        durationSec: 60,
        planechase: false,
        commanders: const [],
      ),
    );
    night.recordGame(
      ArchivedGame(
        id: 'g2',
        endedAtMs: 2,
        format: 'twoHeaded',
        players: const ['Ana', 'Bo', 'Céline', 'Dan'],
        winner: 'Ana & Bo',
        durationSec: 60,
        planechase: false,
        commanders: const [],
      ),
    );
    final board = night.standings();
    expect(board.first.name, 'Ana');
    // Ana : 1+3 (présence+win) + 1+2 (présence+équipe) = 7
    expect(board.first.points, 7);
    expect(board.first.wins, 2);
    final bo = board.firstWhere((s) => s.name == 'Bo');
    expect(bo.wins, 1);
    expect(bo.points, 4); // 1+0 + 1+2
  });

  test('merge MTGN1 cumule les parties sans doublon', () {
    final a = NightSession.create(title: 'A', podCount: 1);
    a.addPlayer('Ana');
    a.recordGame(
      ArchivedGame(
        id: 'same',
        endedAtMs: 1,
        format: 'commander',
        players: const ['Ana'],
        winner: 'Ana',
        durationSec: 10,
        planechase: false,
        commanders: const [],
      ),
    );
    final b = NightSession(
      id: a.id,
      code: a.code,
      title: 'B',
      startedAtMs: a.startedAtMs,
      roster: [const NightPlayer(id: 'x', name: 'Bo')],
      pods: [],
      games: [
        ArchivedGame(
          id: 'same',
          endedAtMs: 1,
          format: 'commander',
          players: const ['Ana'],
          winner: 'Ana',
          durationSec: 10,
          planechase: false,
          commanders: const [],
        ),
        ArchivedGame(
          id: 'other',
          endedAtMs: 2,
          format: 'commander',
          players: const ['Bo'],
          winner: 'Bo',
          durationSec: 10,
          planechase: false,
          commanders: const [],
        ),
      ],
    );
    a.mergeFrom(b);
    expect(a.games, hasLength(2));
    expect(a.roster.any((p) => p.name == 'Bo'), isTrue);
  });

  test('encode / decode night transfer', () {
    final night = NightSession.create(title: 'Salon', podCount: 2);
    night.addPlayer('Léa');
    night.recordGame(
      ArchivedGame(
        id: 'g',
        endedAtMs: 1,
        format: 'commander',
        players: const ['Léa'],
        winner: 'Léa',
        durationSec: 5,
        planechase: false,
        commanders: const [],
      ),
    );
    final code = encodeNightTransfer(night);
    expect(code, isNotNull);
    expect(code!.startsWith('MTGN1.'), isTrue);
    final decoded = decodeNightTransfer(code);
    expect(decoded, isNotNull);
    expect(decoded!.title, 'Salon');
    expect(decoded.games, hasLength(1));
    expect(decoded.buildRecap(), contains('Léa'));
  });

  test('CSV et face-à-face soirée', () {
    final night = NightSession.create(title: 'CSV', podCount: 1);
    night.addPlayer('Ana');
    night.addPlayer('Bo');
    night.addPlayer('Céline');
    night.recordGame(
      ArchivedGame(
        id: 'g1',
        endedAtMs: DateTime(2026, 10, 17, 20, 30).millisecondsSinceEpoch,
        format: 'commander',
        players: const ['Ana', 'Bo', 'Céline'],
        winner: 'Ana',
        durationSec: 1800,
        planechase: false,
        commanders: const ['Ana · Atraxa'],
      ),
    );
    night.recordGame(
      ArchivedGame(
        id: 'g2',
        endedAtMs: DateTime(2026, 10, 17, 21, 0).millisecondsSinceEpoch,
        format: 'commander',
        players: const ['Ana', 'Bo', 'Céline'],
        winner: 'Bo',
        durationSec: 900,
        planechase: false,
        commanders: const [],
      ),
    );
    final ana = night.standings().firstWhere((s) => s.name == 'Ana');
    expect(ana.soloWins, 1);
    expect(ana.wins, 1);
    expect(ana.avgDurationSec, greaterThan(0));

    final csv = night.buildCsv();
    expect(csv, contains('Rang;Joueur;Points'));
    expect(csv, contains('Ana'));
    expect(csv, contains('Date;Format;Table'));
    expect(csv, contains('Atraxa'));

    final duels = night.headToHeads();
    expect(duels, isNotEmpty);
    final anaVsBo = duels.firstWhere(
      (d) => (d.a == 'Ana' && d.b == 'Bo') || (d.a == 'Bo' && d.b == 'Ana'),
    );
    expect(anaVsBo.aWins + anaVsBo.bWins, 2);

    final recap = night.buildRecap();
    expect(recap, contains('Face à face'));
    expect(recap, contains('%'));
  });
}
