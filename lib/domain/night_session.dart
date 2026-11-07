import 'dart:math';

import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/stats.dart';

/// Statut d’une table (pod) dans la soirée.
enum PodStatus { idle, playing, paused }

/// Joueur inscrit à la soirée (roster global).
class NightPlayer {
  const NightPlayer({
    required this.id,
    required this.name,
    this.color = 0,
  });

  final String id;
  final String name;
  final int color;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
  };

  factory NightPlayer.fromJson(Map<String, dynamic> json) {
    return NightPlayer(
      id: json['id'] as String? ?? newId('np'),
      name: (json['name'] as String? ?? 'Joueur').trim().isEmpty
          ? 'Joueur'
          : (json['name'] as String).trim(),
      color: asInt(json['color']),
    );
  }
}

/// Une table physique / pod de la soirée.
class NightPod {
  NightPod({
    required this.id,
    required this.label,
    List<String>? playerNames,
    this.status = PodStatus.idle,
    this.session,
    this.gamesPlayed = 0,
  }) : playerNames = playerNames ?? [];

  final String id;
  String label;
  List<String> playerNames;
  PodStatus status;

  /// Snapshot de partie en pause (exportSession), si [status] == paused.
  Map<String, dynamic>? session;
  int gamesPlayed;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'playerNames': playerNames,
    'status': status.name,
    'session': session,
    'gamesPlayed': gamesPlayed,
  };

  factory NightPod.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? session;
    final raw = json['session'];
    if (raw is Map<String, dynamic>) {
      session = raw;
    } else if (raw is Map) {
      session = Map<String, dynamic>.from(raw);
    }
    return NightPod(
      id: json['id'] as String? ?? newId('pod'),
      label: json['label'] as String? ?? 'Table',
      playerNames: [
        for (final n in (json['playerNames'] as List? ?? [])) '$n',
      ],
      status: PodStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PodStatus.idle,
      ),
      session: session,
      gamesPlayed: asInt(json['gamesPlayed']),
    );
  }
}

/// Classement d’un joueur sur la soirée.
class NightStanding {
  const NightStanding({
    required this.name,
    required this.games,
    required this.wins,
    required this.soloWins,
    required this.teamWins,
    required this.points,
    required this.totalDurationSec,
  });

  final String name;
  final int games;
  final int wins;
  final int soloWins;
  final int teamWins;

  /// Points : 3 par victoire (solo), 2 par victoire d’équipe, 1 participation.
  final int points;
  final int totalDurationSec;

  double get winRate => games == 0 ? 0 : wins / games;

  int get avgDurationSec =>
      games == 0 ? 0 : (totalDurationSec / games).round();
}

/// Soirée Magic multi-tables (locale, partageable via MTGN1).
class NightSession {
  NightSession({
    required this.id,
    required this.code,
    required this.title,
    required this.startedAtMs,
    List<NightPlayer>? roster,
    List<NightPod>? pods,
    List<ArchivedGame>? games,
    this.activePodId,
    this.endedAtMs,
  }) : roster = roster ?? [],
       pods = pods ?? [],
       games = games ?? [];

  final String id;

  /// Code court affiché (ex. SOIR-K7M2), pas le payload complet.
  final String code;
  String title;
  final int startedAtMs;
  int? endedAtMs;
  final List<NightPlayer> roster;
  final List<NightPod> pods;
  final List<ArchivedGame> games;
  String? activePodId;

  bool get isOpen => endedAtMs == null;

  NightPod? get activePod {
    final id = activePodId;
    if (id == null) return null;
    for (final pod in pods) {
      if (pod.id == id) return pod;
    }
    return null;
  }

  Duration get elapsed {
    final end = endedAtMs ?? DateTime.now().millisecondsSinceEpoch;
    return Duration(milliseconds: (end - startedAtMs).clamp(0, 24 * 3600 * 1000));
  }

  static String generateCode([Random? random]) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = random ?? Random();
    final buf = StringBuffer('SOIR-');
    for (var i = 0; i < 4; i++) {
      buf.write(alphabet[rng.nextInt(alphabet.length)]);
    }
    return buf.toString();
  }

  factory NightSession.create({
    String? title,
    List<NightPlayer>? roster,
    int podCount = 2,
  }) {
    final now = DateTime.now();
    final night = NightSession(
      id: newId('night'),
      code: generateCode(),
      title: (title == null || title.trim().isEmpty)
          ? 'Soirée ${now.day.toString().padLeft(2, '0')}/'
                '${now.month.toString().padLeft(2, '0')}'
          : title.trim(),
      startedAtMs: now.millisecondsSinceEpoch,
      roster: roster ?? [],
    );
    final count = podCount.clamp(1, 6);
    for (var i = 0; i < count; i++) {
      night.pods.add(
        NightPod(id: newId('pod'), label: 'Table ${i + 1}'),
      );
    }
    if (night.pods.isNotEmpty) {
      night.activePodId = night.pods.first.id;
    }
    return night;
  }

  void addPlayer(String name, {int color = 0}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (roster.any((p) => p.name.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }
    roster.add(NightPlayer(id: newId('np'), name: trimmed, color: color));
  }

  void removePlayer(String playerId) {
    roster.removeWhere((p) => p.id == playerId);
    final names = {for (final p in roster) p.name};
    for (final pod in pods) {
      pod.playerNames = [
        for (final n in pod.playerNames)
          if (names.contains(n)) n,
      ];
    }
  }

  void addPod([String? label]) {
    if (pods.length >= 6) return;
    pods.add(
      NightPod(
        id: newId('pod'),
        label: label?.trim().isNotEmpty == true
            ? label!.trim()
            : 'Table ${pods.length + 1}',
      ),
    );
  }

  void removePod(String podId) {
    pods.removeWhere((p) => p.id == podId);
    if (activePodId == podId) {
      activePodId = pods.isEmpty ? null : pods.first.id;
    }
  }

  NightPod? podById(String podId) {
    for (final pod in pods) {
      if (pod.id == podId) return pod;
    }
    return null;
  }

  void setPodPlayers(String podId, List<String> names) {
    final pod = podById(podId);
    if (pod == null) return;
    final allowed = {for (final p in roster) p.name.toLowerCase()};
    pod.playerNames = [
      for (final n in names)
        if (allowed.contains(n.trim().toLowerCase())) n.trim(),
    ].take(8).toList();
  }

  /// Enregistre une partie terminée (idempotent sur l’id).
  void recordGame(ArchivedGame game, {String? podId}) {
    if (games.any((g) => g.id == game.id)) return;
    final tagged = ArchivedGame(
      id: game.id,
      endedAtMs: game.endedAtMs,
      format: game.format,
      players: game.players,
      winner: game.winner,
      durationSec: game.durationSec,
      planechase: game.planechase,
      commanders: game.commanders,
      nightId: id,
      podId: podId ?? activePodId,
    );
    games.insert(0, tagged);
    final pid = tagged.podId;
    if (pid != null) {
      for (final pod in pods) {
        if (pod.id == pid) {
          pod.gamesPlayed += 1;
          pod.status = PodStatus.idle;
          pod.session = null;
          break;
        }
      }
    }
  }

  /// Fusionne une autre soirée (même code ou import) : ajoute les parties manquantes.
  void mergeFrom(NightSession other) {
    for (final player in other.roster) {
      addPlayer(player.name, color: player.color);
    }
    for (final game in other.games) {
      recordGame(game, podId: game.podId);
    }
    if (title.trim().isEmpty && other.title.trim().isNotEmpty) {
      title = other.title;
    }
  }

  void endNight() {
    endedAtMs ??= DateTime.now().millisecondsSinceEpoch;
    for (final pod in pods) {
      if (pod.status == PodStatus.playing) {
        pod.status = PodStatus.paused;
      }
    }
  }

  List<NightStanding> standings() {
    final gamesBy = <String, int>{};
    final winsBy = <String, int>{};
    final soloBy = <String, int>{};
    final teamBy = <String, int>{};
    final pointsBy = <String, int>{};
    final durationBy = <String, int>{};

    void touch(String name) {
      gamesBy[name] = gamesBy[name] ?? 0;
      winsBy[name] = winsBy[name] ?? 0;
      soloBy[name] = soloBy[name] ?? 0;
      teamBy[name] = teamBy[name] ?? 0;
      pointsBy[name] = pointsBy[name] ?? 0;
      durationBy[name] = durationBy[name] ?? 0;
    }

    for (final player in roster) {
      touch(player.name);
    }

    for (final game in games) {
      final winners = _splitWinners(game.winner);
      final isTeam = winners.length > 1;
      for (final name in game.players) {
        touch(name);
        gamesBy[name] = gamesBy[name]! + 1;
        pointsBy[name] = pointsBy[name]! + 1; // présence
        durationBy[name] = durationBy[name]! + game.durationSec;
      }
      for (final name in winners) {
        touch(name);
        winsBy[name] = winsBy[name]! + 1;
        if (isTeam) {
          teamBy[name] = teamBy[name]! + 1;
        } else {
          soloBy[name] = soloBy[name]! + 1;
        }
        pointsBy[name] = pointsBy[name]! + (isTeam ? 2 : 3);
      }
    }

    final names = gamesBy.keys.toList()
      ..sort((a, b) {
        final pc = pointsBy[b]!.compareTo(pointsBy[a]!);
        if (pc != 0) return pc;
        final wc = winsBy[b]!.compareTo(winsBy[a]!);
        if (wc != 0) return wc;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    return [
      for (final name in names)
        NightStanding(
          name: name,
          games: gamesBy[name]!,
          wins: winsBy[name]!,
          soloWins: soloBy[name]!,
          teamWins: teamBy[name]!,
          points: pointsBy[name]!,
          totalDurationSec: durationBy[name]!,
        ),
    ];
  }

  /// Face-à-face sur la soirée (victoires solo ou d’équipe comptées).
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

  static List<String> _splitWinners(String? winner) {
    if (winner == null || winner.trim().isEmpty) return const [];
    return [
      for (final part in winner.split('&'))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  String buildRecap() {
    final buf = StringBuffer();
    buf.writeln('Soirée LifeStack · $title');
    buf.writeln('Code · $code');
    buf.writeln(
      'Durée · ${_fmt(elapsed)} · ${games.length} partie'
      '${games.length > 1 ? 's' : ''} · ${pods.length} table'
      '${pods.length > 1 ? 's' : ''}',
    );
    if (!isOpen) buf.writeln('Soirée close');
    buf.writeln('');
    buf.writeln('Classement :');
    final board = standings();
    if (board.isEmpty) {
      buf.writeln('· (personne encore)');
    } else {
      for (var i = 0; i < board.length; i++) {
        final s = board[i];
        final rate = (s.winRate * 100).round();
        buf.writeln(
          '${i + 1}. ${s.name} · ${s.points} pts · '
          '${s.wins}V / ${s.games}P · $rate %'
          '${s.teamWins > 0 ? ' · ${s.teamWins} équipe' : ''}',
        );
      }
    }
    final duels = headToHeads(limit: 8);
    if (duels.isNotEmpty) {
      buf.writeln('');
      buf.writeln('Face à face :');
      for (final d in duels) {
        buf.writeln('· ${d.a} ${d.aWins} – ${d.bWins} ${d.b}');
      }
    }
    if (games.isNotEmpty) {
      buf.writeln('');
      buf.writeln('Parties :');
      for (final game in games.take(20)) {
        final pod = game.podId == null ? null : podById(game.podId!);
        final table = pod?.label ?? 'Table';
        final win = game.winner ?? '—';
        final dur = _fmt(Duration(seconds: game.durationSec));
        buf.writeln('· $table · ${game.format} · $win · $dur');
        if (game.commanders.isNotEmpty) {
          buf.writeln('  ${game.commanders.take(4).join(' · ')}');
        }
      }
    }
    buf.writeln('');
    buf.writeln('— LifeStack · soirée locale');
    return buf.toString();
  }

  /// Export CSV (séparateur `;`, Excel FR) : classement + parties.
  String buildCsv() {
    final buf = StringBuffer();
    buf.writeln('Soirée;$title');
    buf.writeln('Code;$code');
    buf.writeln('Parties;${games.length}');
    buf.writeln('');
    buf.writeln('Rang;Joueur;Points;Victoires;Solo;Equipe;Parties;Winrate%;Duree_moy_s');
    final board = standings();
    for (var i = 0; i < board.length; i++) {
      final s = board[i];
      buf.writeln(
        '${i + 1};${_csv(s.name)};${s.points};${s.wins};${s.soloWins};'
        '${s.teamWins};${s.games};${(s.winRate * 100).round()};'
        '${s.avgDurationSec}',
      );
    }
    buf.writeln('');
    buf.writeln('Date;Format;Table;Joueurs;Vainqueur;Duree_s;Commandants');
    for (final game in games) {
      final pod = game.podId == null ? null : podById(game.podId!);
      final table = pod?.label ?? '';
      final at = game.endedAt;
      final date =
          '${at.year}-${at.month.toString().padLeft(2, '0')}-'
          '${at.day.toString().padLeft(2, '0')} '
          '${at.hour.toString().padLeft(2, '0')}:'
          '${at.minute.toString().padLeft(2, '0')}';
      buf.writeln(
        '$date;${_csv(game.format)};${_csv(table)};'
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

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}';
    return '${m}m';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'title': title,
    'startedAtMs': startedAtMs,
    'endedAtMs': endedAtMs,
    'roster': [for (final p in roster) p.toJson()],
    'pods': [for (final p in pods) p.toJson()],
    'games': [for (final g in games) g.toJson()],
    'activePodId': activePodId,
  };

  factory NightSession.fromJson(Map<String, dynamic> json) {
    return NightSession(
      id: json['id'] as String? ?? newId('night'),
      code: json['code'] as String? ?? generateCode(),
      title: json['title'] as String? ?? 'Soirée',
      startedAtMs: asInt(json['startedAtMs'], DateTime.now().millisecondsSinceEpoch),
      endedAtMs: json['endedAtMs'] == null ? null : asInt(json['endedAtMs']),
      roster: [
        for (final item in (json['roster'] as List? ?? []))
          if (item is Map<String, dynamic>)
            NightPlayer.fromJson(item)
          else if (item is Map)
            NightPlayer.fromJson(Map<String, dynamic>.from(item)),
      ],
      pods: [
        for (final item in (json['pods'] as List? ?? []))
          if (item is Map<String, dynamic>)
            NightPod.fromJson(item)
          else if (item is Map)
            NightPod.fromJson(Map<String, dynamic>.from(item)),
      ],
      games: [
        for (final item in (json['games'] as List? ?? []))
          if (item is Map<String, dynamic>)
            ArchivedGame.fromJson(item)
          else if (item is Map)
            ArchivedGame.fromJson(Map<String, dynamic>.from(item)),
      ],
      activePodId: json['activePodId'] as String?,
    );
  }
}
