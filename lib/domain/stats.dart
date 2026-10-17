import 'dart:convert';
import 'dart:math';

import 'package:mtg_table/domain/models.dart';

class ArchivedGame {
  const ArchivedGame({
    required this.id,
    required this.endedAtMs,
    required this.format,
    required this.players,
    required this.winner,
    required this.durationSec,
    required this.planechase,
    required this.commanders,
    this.nightId,
    this.podId,
  });

  final String id;
  final int endedAtMs;
  final String format;
  final List<String> players;
  final String? winner;
  final int durationSec;
  final bool planechase;
  final List<String> commanders;
  final String? nightId;
  final String? podId;

  DateTime get endedAt => DateTime.fromMillisecondsSinceEpoch(endedAtMs);

  Map<String, dynamic> toJson() => {
    'id': id,
    'endedAtMs': endedAtMs,
    'format': format,
    'players': players,
    'winner': winner,
    'durationSec': durationSec,
    'planechase': planechase,
    'commanders': commanders,
    if (nightId != null) 'nightId': nightId,
    if (podId != null) 'podId': podId,
  };

  factory ArchivedGame.fromJson(Map<String, dynamic> json) {
    return ArchivedGame(
      id: json['id'] as String? ?? newId('game'),
      endedAtMs: asInt(json['endedAtMs']),
      format: json['format'] as String? ?? MatchFormat.commander.name,
      players: [for (final name in (json['players'] as List? ?? [])) '$name'],
      winner: json['winner'] as String?,
      durationSec: asInt(json['durationSec']),
      planechase: json['planechase'] as bool? ?? false,
      commanders: [
        for (final name in (json['commanders'] as List? ?? [])) '$name',
      ],
      nightId: json['nightId'] as String?,
      podId: json['podId'] as String?,
    );
  }

  factory ArchivedGame.fromMatch({
    required Game game,
    required Duration duration,
    String? nightId,
    String? podId,
  }) {
    final winner = game.winnerLabel();
    return ArchivedGame(
      id: newId('game'),
      endedAtMs: DateTime.now().millisecondsSinceEpoch,
      format: game.format.name,
      players: [for (final player in game.players) player.name],
      winner: winner,
      durationSec: duration.inSeconds.clamp(0, 24 * 3600),
      planechase: game.planechase,
      commanders: [
        for (final player in game.players)
          for (final commander in player.commanders)
            '${player.name} · ${commander.name}',
      ],
      nightId: nightId,
      podId: podId,
    );
  }
}

class PlayerRecord {
  const PlayerRecord({
    required this.name,
    required this.games,
    required this.wins,
  });

  final String name;
  final int games;
  final int wins;

  double get winRate => games == 0 ? 0 : wins / games;
}

class HeadToHead {
  const HeadToHead({
    required this.a,
    required this.b,
    required this.aWins,
    required this.bWins,
  });

  final String a;
  final String b;
  final int aWins;
  final int bWins;
}

class LocalLedger {
  LocalLedger({List<ArchivedGame>? games}) : games = games ?? [];

  final List<ArchivedGame> games;

  static const maxGames = 80;

  void add(ArchivedGame game) {
    games.insert(0, game);
    while (games.length > maxGames) {
      games.removeLast();
    }
  }

  static List<String> _splitWinners(String? winner) {
    if (winner == null || winner.trim().isEmpty) return const [];
    return [
      for (final part in winner.split('&'))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  List<PlayerRecord> playerRecords() {
    final gamesBy = <String, int>{};
    final winsBy = <String, int>{};
    for (final game in games) {
      for (final name in game.players) {
        gamesBy[name] = (gamesBy[name] ?? 0) + 1;
      }
      for (final name in _splitWinners(game.winner)) {
        winsBy[name] = (winsBy[name] ?? 0) + 1;
      }
    }
    final names = {...gamesBy.keys, ...winsBy.keys}.toList()
      ..sort((a, b) {
        final wa = winsBy[a] ?? 0;
        final wb = winsBy[b] ?? 0;
        if (wa != wb) return wb.compareTo(wa);
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return [
      for (final name in names)
        PlayerRecord(
          name: name,
          games: gamesBy[name] ?? 0,
          wins: winsBy[name] ?? 0,
        ),
    ];
  }

  List<HeadToHead> headToHeads({int limit = 12}) {
    final pairs = <String, HeadToHead>{};
    for (final game in games) {
      final winners = _splitWinners(game.winner);
      if (winners.isEmpty || game.players.length < 2) continue;
      final winnerSet = {for (final w in winners) w};
      for (final winner in winners) {
        for (final name in game.players) {
          if (winnerSet.contains(name)) continue;
          final key = [winner, name]..sort();
          final id = '${key[0]}|${key[1]}';
          final prev =
              pairs[id] ??
              HeadToHead(a: key[0], b: key[1], aWins: 0, bWins: 0);
          if (winner == prev.a) {
            pairs[id] = HeadToHead(
              a: prev.a,
              b: prev.b,
              aWins: prev.aWins + 1,
              bWins: prev.bWins,
            );
          } else {
            pairs[id] = HeadToHead(
              a: prev.a,
              b: prev.b,
              aWins: prev.aWins,
              bWins: prev.bWins + 1,
            );
          }
        }
      }
    }
    final list = pairs.values.toList()
      ..sort((a, b) => (b.aWins + b.bWins).compareTo(a.aWins + a.bWins));
    return list.take(limit).toList();
  }

  /// Export CSV (`;`) des stats locales + parties.
  String buildCsv() {
    final buf = StringBuffer();
    buf.writeln('Joueur;Victoires;Parties;Winrate%');
    for (final r in playerRecords()) {
      buf.writeln(
        '${_csv(r.name)};${r.wins};${r.games};${(r.winRate * 100).round()}',
      );
    }
    buf.writeln('');
    buf.writeln('Date;Format;Joueurs;Vainqueur;Duree_s;Commandants');
    for (final game in games) {
      final at = game.endedAt;
      final date =
          '${at.year}-${at.month.toString().padLeft(2, '0')}-'
          '${at.day.toString().padLeft(2, '0')} '
          '${at.hour.toString().padLeft(2, '0')}:'
          '${at.minute.toString().padLeft(2, '0')}';
      buf.writeln(
        '$date;${_csv(game.format)};'
        '${_csv(game.players.join(' | '))};'
        '${_csv(game.winner ?? '')};${game.durationSec};'
        '${_csv(game.commanders.join(' | '))}',
      );
    }
    return buf.toString();
  }

  static String _csv(String value) {
    final needsQuotes =
        value.contains(';') || value.contains('"') || value.contains('\n');
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  Map<String, dynamic> toJson() => {
    'games': games.map((game) => game.toJson()).toList(),
  };

  factory LocalLedger.fromJson(Map<String, dynamic> json) {
    return LocalLedger(
      games: [
        for (final raw in (json['games'] as List? ?? []))
          if (raw is Map<String, dynamic>)
            ArchivedGame.fromJson(raw)
          else if (raw is Map)
            ArchivedGame.fromJson(Map<String, dynamic>.from(raw)),
      ],
    );
  }
}

/// Code compact pour QR / collage (pas de serveur).
String encodePlaygroupInvite(Playgroup group) {
  final raw = jsonEncode(group.toJson());
  final bytes = utf8.encode(raw);
  return 'TABLEMTG1.${base64Url.encode(bytes)}';
}

Playgroup? decodePlaygroupInvite(String input) {
  final trimmed = input.trim();
  if (!trimmed.startsWith('TABLEMTG1.')) return null;
  try {
    final payload = trimmed.substring('TABLEMTG1.'.length);
    final json = jsonDecode(utf8.decode(base64Url.decode(payload)));
    if (json is Map<String, dynamic>) return Playgroup.fromJson(json);
    if (json is Map) {
      return Playgroup.fromJson(Map<String, dynamic>.from(json));
    }
  } on Object {
    return null;
  }
  return null;
}

String randomCommanderHint() {
  const pool = [
    'Atraxa, Praetors\' Voice',
    'Kraum, Ludevic\'s Opus',
    'Tymna the Weaver',
    'Meren of Clan Nel Toth',
    'The Ur-Dragon',
    'Korvold, Fae-Cursed King',
    'Wilhelt, the Rotcleaver',
    'Giada, Font of Hope',
  ];
  return pool[Random().nextInt(pool.length)];
}
