import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mtg_table/domain/handicap.dart';
import 'package:mtg_table/domain/journal_event.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/planar_decks.dart';

class Trail {
  Trail(this.label, this.before);

  final String label;
  final Map<String, dynamic> before;

  Map<String, dynamic> toJson() => {'label': label, 'before': before};

  factory Trail.fromJson(Map<String, dynamic> json) {
    final raw = json['before'];
    return Trail(
      json['label'] as String? ?? '',
      raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }
}

class FoundCommander {
  const FoundCommander(this.owner, this.commander);

  final Player owner;
  final Commander commander;
}

class GameController extends ChangeNotifier {
  GameController({
    required this.game,
    List<Trail>? undo,
    List<Trail>? redo,
    List<JournalEvent>? journal,
    this.onChanged,
    DateTime? turnStarted,
    DateTime? matchStarted,
  }) : undoStack = undo ?? [],
       redoStack = redo ?? [],
       journal = journal ?? [],
       turnStarted = turnStarted ?? DateTime.now(),
       matchStarted = matchStarted ?? DateTime.now();

  Game game;
  final List<Trail> undoStack;
  final List<Trail> redoStack;
  final List<JournalEvent> journal;
  final VoidCallback? onChanged;
  DateTime turnStarted;
  DateTime matchStarted;
  String lastLabel = '';
  int flashId = 0;
  String flashText = '';
  /// Historique complet des PV depuis le début (plus récent en tête).
  final List<LifeChange> lifeLog = [];

  /// Historique des dégâts de commandant (plus récent en tête).
  final List<CmdDamageChange> cmdDamageLog = [];

  /// Lignes pour récap / bandeau (dérivées de [lifeLog]).
  List<String> get lifeFeed => [for (final e in lifeLog) e.line];

  Duration get turnElapsed => DateTime.now().difference(turnStarted);
  Duration get matchElapsed => DateTime.now().difference(matchStarted);

  void _pushLifeChange(LifeChange change) {
    lifeLog.insert(0, change);
    if (lifeLog.length > 400) lifeLog.removeLast();
  }

  void _pushCmdDamageChange(CmdDamageChange change) {
    cmdDamageLog.insert(0, change);
    if (cmdDamageLog.length > 400) cmdDamageLog.removeLast();
  }

  LifeChange? lastLifeChangeFor(String playerId) {
    for (final e in lifeLog) {
      if (e.playerId == playerId && e.delta != 0) return e;
    }
    return null;
  }

  /// Pile des derniers ±PV (après fusion des taps), du plus récent au plus ancien.
  List<LifeChange> recentLifeChangesFor(String playerId, {int limit = 5}) {
    final out = <LifeChange>[];
    for (final e in lifeLog) {
      if (e.playerId != playerId || e.delta == 0) continue;
      out.add(e);
      if (out.length >= limit) break;
    }
    return out;
  }

  CmdDamageChange? lastCmdDamageChangeFor({
    required String defenderId,
    required String commanderId,
  }) {
    for (final e in cmdDamageLog) {
      if (e.defenderId == defenderId &&
          e.commanderId == commanderId &&
          e.delta != 0) {
        return e;
      }
    }
    return null;
  }

  List<CmdDamageChange> recentCmdDamageChangesFor({
    required String defenderId,
    required String commanderId,
    int limit = 4,
  }) {
    final out = <CmdDamageChange>[];
    for (final e in cmdDamageLog) {
      if (e.defenderId != defenderId || e.commanderId != commanderId) {
        continue;
      }
      if (e.delta == 0) continue;
      out.add(e);
      if (out.length >= limit) break;
    }
    return out;
  }

  void _recordLife({
    required Player player,
    required int from,
    required int to,
    String? reason,
  }) {
    if (from == to && reason == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final delta = to - from;
    // Fusion taps rapides : −1×5 → un seul −5 (comme Lifetap / Portal).
    if (delta != 0 && lifeLog.isNotEmpty) {
      final last = lifeLog.first;
      final samePlayer = last.playerId == player.id;
      final sameReason = last.reason == reason;
      final fresh =
          last.atMs != null && (now - last.atMs!) <= lifeDeltaMergeMs;
      final lastDelta = last.delta;
      final sameSign =
          lastDelta == 0 || delta == 0 || (lastDelta > 0) == (delta > 0);
      if (samePlayer && sameReason && fresh && sameSign && lastDelta != 0) {
        lifeLog[0] = LifeChange(
          playerId: last.playerId,
          playerName: last.playerName,
          from: last.from,
          to: to,
          delta: to - last.from,
          turnCount: game.turnCount,
          roundNumber: game.roundNumber,
          reason: reason,
          atMs: now,
        );
        return;
      }
    }
    _pushLifeChange(
      LifeChange(
        playerId: player.id,
        playerName: _groupLabel(player),
        from: from,
        to: to,
        delta: delta,
        turnCount: game.turnCount,
        roundNumber: game.roundNumber,
        reason: reason,
        atMs: now,
      ),
    );
  }

  void _recordCmdDamage({
    required Player defender,
    required String commanderId,
    required String commanderLabel,
    required int fromTaken,
    required int toTaken,
    int? lifeFrom,
    int? lifeTo,
  }) {
    if (fromTaken == toTaken) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final delta = toTaken - fromTaken;
    if (cmdDamageLog.isNotEmpty) {
      final last = cmdDamageLog.first;
      final same = last.defenderId == defender.id &&
          last.commanderId == commanderId;
      final fresh =
          last.atMs != null && (now - last.atMs!) <= lifeDeltaMergeMs;
      final sameSign =
          last.delta == 0 || delta == 0 || (last.delta > 0) == (delta > 0);
      if (same && fresh && sameSign && last.delta != 0) {
        cmdDamageLog[0] = CmdDamageChange(
          defenderId: last.defenderId,
          defenderName: last.defenderName,
          commanderId: last.commanderId,
          commanderLabel: last.commanderLabel,
          fromTaken: last.fromTaken,
          toTaken: toTaken,
          delta: toTaken - last.fromTaken,
          turnCount: game.turnCount,
          roundNumber: game.roundNumber,
          lifeFrom: last.lifeFrom ?? lifeFrom,
          lifeTo: lifeTo,
          atMs: now,
        );
        return;
      }
    }
    _pushCmdDamageChange(
      CmdDamageChange(
        defenderId: defender.id,
        defenderName: defender.name,
        commanderId: commanderId,
        commanderLabel: commanderLabel,
        fromTaken: fromTaken,
        toTaken: toTaken,
        delta: delta,
        turnCount: game.turnCount,
        roundNumber: game.roundNumber,
        lifeFrom: lifeFrom,
        lifeTo: lifeTo,
        atMs: now,
      ),
    );
  }

  /// Banque restante du joueur actif (chess), en tenant compte du tour en cours.
  Duration get activeBankRemaining {
    if (game.timerMode != TimerMode.chess || game.players.isEmpty) {
      return Duration.zero;
    }
    final active = game.players[game.activeIndex];
    final left = active.clockBankMs - turnElapsed.inMilliseconds;
    return Duration(milliseconds: left.clamp(0, 6 * 3600 * 1000));
  }

  bool get turnOverAlert {
    if (game.timerMode == TimerMode.chess) {
      return game.players.isNotEmpty &&
          activeBankRemaining <= Duration.zero &&
          turnElapsed.inMilliseconds > 0;
    }
    final limit = game.turnAlertSeconds;
    return limit > 0 && turnElapsed.inSeconds >= limit;
  }

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  int get historyLength => undoStack.length;

  String historyLabel(int index) => undoStack[index].label;

  Player playerById(String id) => game.playerById(id);

  FoundCommander? findCommander(String id) {
    for (final player in game.players) {
      for (final commander in player.commanders) {
        if (commander.id == id) return FoundCommander(player, commander);
      }
    }
    return null;
  }

  void flash(String text) {
    flashText = text;
    flashId++;
    lastLabel = text;
    notifyListeners();
  }

  void _commit(String label, void Function() change) {
    final before = game.toJson();
    change();
    undoStack.add(Trail(label, before));
    if (undoStack.length > 80) undoStack.removeAt(0);
    redoStack.clear();
    lastLabel = label;
    notifyListeners();
    onChanged?.call();
  }

  void undo() => undoSteps(1);

  void undoSteps(int steps) {
    if (steps <= 0 || undoStack.isEmpty) return;
    for (var i = 0; i < steps; i++) {
      if (undoStack.isEmpty) break;
      final trail = undoStack.removeLast();
      redoStack.add(Trail(trail.label, game.toJson()));
      game = Game.fromJson(trail.before);
      if (journal.isNotEmpty && journal.first.label == trail.label) {
        journal.removeAt(0);
      }
      lastLabel = 'Annulé · ${trail.label}';
    }
    turnStarted = DateTime.now();
    notifyListeners();
    onChanged?.call();
  }

  void redo() {
    if (redoStack.isEmpty) return;
    final trail = redoStack.removeLast();
    undoStack.add(Trail(trail.label, game.toJson()));
    game = Game.fromJson(trail.before);
    lastLabel = trail.label;
    turnStarted = DateTime.now();
    notifyListeners();
    onChanged?.call();
  }

  List<int> lifeSeries(String playerId) {
    final series = <int>[];
    for (final trail in undoStack) {
      series.add(Game.fromJson(trail.before).playerById(playerId).life);
    }
    series.add(game.playerById(playerId).life);
    return series;
  }

  void _setLife(Player player, int value) {
    final next = value.clamp(-99, 999);
    if (!game.sharedLife) {
      player.life = next;
      return;
    }
    final index = game.indexOf(player.id);
    final team = index ~/ 2;
    for (var i = 0; i < game.players.length; i++) {
      if (i ~/ 2 == team) game.players[i].life = next;
    }
  }

  String _groupLabel(Player player) {
    if (!game.sharedLife) return player.name;
    final team = game.indexOf(player.id) ~/ 2;
    final names = [
      for (var i = 0; i < game.players.length; i++)
        if (i ~/ 2 == team) game.players[i].name,
    ];
    return names.join(' & ');
  }

  void addLife(String playerId, int delta) {
    if (delta == 0) return;
    final player = playerById(playerId);
    final before = player.life;
    final next = (before + delta).clamp(-99, 999);
    if (next == before) return;
    final wasAlive = !game.lifeLethal(player);
    final label =
        '${_groupLabel(player)} $before → $next (${next > before ? '+' : ''}${next - before})';
    _commit(label, () {
      _setLife(player, next);
    });
    _recordLife(player: player, from: before, to: next);
    if (wasAlive && next <= 0) {
      flash('${player.name} est à terre');
    }
  }

  /// Enregistre un événement de journal et applique les deltas confirmés.
  /// L’annulation (undo) recalcule l’état via le snapshot — journal corrigible.
  void commitJournalEvent(JournalEvent event) {
    final label = event.label;
    final lifeBefore = <String, int>{
      for (final d in event.deltas)
        if (game.indexOf(d.playerId) >= 0)
          d.playerId: playerById(d.playerId).life,
    };
    _commit(label, () {
      for (final delta in event.deltas) {
        try {
          _applyDeltaSilent(delta);
        } on Object {
          // Delta invalide (joueur disparu) : on ignore ce seul delta.
        }
      }
    });
    journal.insert(0, event);
    if (journal.length > 120) journal.removeLast();
    for (final entry in lifeBefore.entries) {
      final player = playerById(entry.key);
      if (player.life != entry.value) {
        _recordLife(
          player: player,
          from: entry.value,
          to: player.life,
          reason: label,
        );
      }
    }
    flash(label);
  }

  /// Journal seul (terrain, note, sort sans PV) — toujours annulable via undo
  /// si des deltas existent ; sinon entrée purement narrative.
  void logJournalNote(JournalEvent event) {
    if (event.deltas.isNotEmpty) {
      commitJournalEvent(event);
      return;
    }
    journal.insert(0, event);
    if (journal.length > 120) journal.removeLast();
    lastLabel = event.label;
    notifyListeners();
    onChanged?.call();
  }

  void _applyDeltaSilent(AppliedDelta delta) {
    if (game.indexOf(delta.playerId) < 0) return;
    final player = playerById(delta.playerId);
    if (delta.commanderId != null && delta.commanderDamageDelta != 0) {
      final commanderId = delta.commanderId!;
      final found = findCommander(commanderId);
      if (found != null) {
        final current = player.damageTaken[commanderId] ?? 0;
        final next = (current + delta.commanderDamageDelta).clamp(
          0,
          game.commanderThreshold,
        );
        final applied = next - current;
        final drained = player.lifeDrainedByCommander[commanderId] ?? 0;
        final int lifeDelta;
        if (applied > 0) {
          lifeDelta = -applied;
        } else {
          final undo = -applied;
          final restore = undo > drained ? drained : undo;
          lifeDelta = restore;
        }
        player.damageTaken[commanderId] = next;
        if (lifeDelta != 0) {
          _setLife(player, (player.life + lifeDelta).clamp(-99, 999));
        }
        if (applied > 0) {
          player.lifeDrainedByCommander[commanderId] = drained + applied;
        } else {
          player.lifeDrainedByCommander[commanderId] =
              (drained - lifeDelta).clamp(0, 99);
        }
      }
    } else if (delta.lifeDelta != 0) {
      _setLife(player, (player.life + delta.lifeDelta).clamp(-99, 999));
    }
    if (delta.poisonDelta != 0) {
      player.poison = (player.poison + delta.poisonDelta).clamp(0, 30);
    }
  }

  void setLife(String playerId, int value) {
    final player = playerById(playerId);
    addLife(playerId, value.clamp(-99, 999) - player.life);
  }

  void addCommanderDamage({
    required String defenderId,
    required String commanderId,
    required int delta,
  }) {
    if (!game.trackCommanderDamage || delta == 0) return;
    final defender = playerById(defenderId);
    final found = findCommander(commanderId);
    if (found == null) return;
    final current = defender.damageTaken[commanderId] ?? 0;
    final next = (current + delta).clamp(0, game.commanderThreshold);
    final applied = next - current;
    if (applied == 0) return;
    final source = commanderChipLabel(found.owner, found.commander);
    final remaining = game.commanderThreshold - next;
    // Règle : dégâts de combat du commandant = aussi perte de PV (CR 120.3a).
    // En corrigeant, on ne rend que les PV réellement retirés par ce suivi.
    final drained = defender.lifeDrainedByCommander[commanderId] ?? 0;
    final int lifeDelta;
    if (applied > 0) {
      lifeDelta = -applied;
    } else {
      final undo = -applied;
      final restore = undo > drained ? drained : undo;
      lifeDelta = restore;
    }
    final lifeBefore = defender.life;
    final lifeAfter = (lifeBefore + lifeDelta).clamp(-99, 999);
    final takenBefore = current;
    _commit(
      '${defender.name} : $remaining / ${game.commanderThreshold} face à $source'
      ' · vie $lifeBefore → $lifeAfter',
      () {
        defender.damageTaken[commanderId] = next;
        if (lifeDelta != 0) {
          _setLife(defender, lifeAfter);
        }
        if (applied > 0) {
          defender.lifeDrainedByCommander[commanderId] = drained + applied;
        } else {
          defender.lifeDrainedByCommander[commanderId] =
              (drained - lifeDelta).clamp(0, 99);
        }
      },
    );
    _recordCmdDamage(
      defender: defender,
      commanderId: commanderId,
      commanderLabel: source,
      fromTaken: takenBefore,
      toTaken: next,
      lifeFrom: lifeDelta != 0 ? lifeBefore : null,
      lifeTo: lifeDelta != 0 ? lifeAfter : null,
    );
    if (lifeDelta != 0) {
      _recordLife(
        player: defender,
        from: lifeBefore,
        to: lifeAfter,
        reason: source,
      );
    }
    if (remaining == 0) {
      flash('${defender.name} hors jeu · $source');
    } else if (game.lifeLethal(defender)) {
      flash('${defender.name} est à terre');
    }
    final win = game.victoryBanner();
    if (win != null) flash(win);
  }

  void addPlayer({String? name}) {
    if (game.players.length >= 8) return;
    if (game.sharedLife && game.players.length.isOdd) return;
    final index = game.players.length;
    final label = (name ?? '').trim().isEmpty
        ? 'Joueur ${index + 1}'
        : name!.trim();
    _commit('Ajout de $label', () {
      final commanders = <Commander>[];
      if (game.tracksCommanders) {
        commanders.add(Commander(id: newId('cmd'), name: 'Commandant'));
      }
      final newbie = Player(
        id: newId('p'),
        name: label,
        color: index % 8,
        life: game.startingLife,
        commanders: commanders,
        mana: {for (final key in manaKeys) key: 0},
      );
      newbie.life = newbie.startingLifeFor(game);
      game.players.add(newbie);
    });
  }

  void setDeckHandicap(
    String playerId, {
    DeckBracket? bracket,
    int? lifeDelta,
    bool adjustCurrentLife = true,
  }) {
    final player = playerById(playerId);
    final int nextDelta;
    if (lifeDelta != null) {
      nextDelta = clampHandicapLife(lifeDelta);
    } else if (bracket != null && bracket != DeckBracket.custom) {
      nextDelta = bracket.suggestedLifeDelta;
    } else {
      nextDelta = player.handicapLifeDelta;
    }
    final nextBracket = bracket ?? bracketMatchingLifeDelta(nextDelta);
    if (nextBracket == player.deckBracket &&
        nextDelta == player.handicapLifeDelta) {
      return;
    }
    final beforeStart = player.startingLifeFor(game);
    _commit(
      '${player.name} · handicap ${nextBracket.label} '
      '(${formatLifeDelta(nextDelta)} PV)',
      () {
        player.deckBracket = nextBracket;
        player.handicapLifeDelta = nextDelta;
        if (adjustCurrentLife && game.handicapsEnabled) {
          final afterStart = player.startingLifeFor(game);
          final delta = afterStart - beforeStart;
          if (delta != 0) {
            _setLife(player, (player.life + delta).clamp(-99, 999));
          }
        }
      },
    );
  }

  void setHandicapsEnabled(bool enabled) {
    if (game.handicapsEnabled == enabled) return;
    if (game.sharedLife && enabled) return;
    _commit(enabled ? 'Handicaps activés' : 'Handicaps désactivés', () {
      // Recalcule les PV relatifs au nouvel état.
      final befores = [
        for (final player in game.players) player.startingLifeFor(game),
      ];
      game.handicapsEnabled = enabled;
      for (var i = 0; i < game.players.length; i++) {
        final player = game.players[i];
        final after = player.startingLifeFor(game);
        final delta = after - befores[i];
        if (delta != 0) {
          _setLife(player, (player.life + delta).clamp(-99, 999));
        }
      }
    });
  }

  void removePlayer(String playerId) {
    if (game.players.length <= 1) return;
    if (game.sharedLife && game.players.length <= 2) return;
    final player = playerById(playerId);
    final index = game.indexOf(playerId);
    _commit('${player.name} quitte la table', () {
      final commanderIds = [for (final c in player.commanders) c.id];
      game.players.removeAt(index);
      for (final other in game.players) {
        for (final id in commanderIds) {
          other.damageTaken.remove(id);
        }
      }
      if (game.monarchId == playerId) game.monarchId = null;
      if (game.initiativeId == playerId) game.initiativeId = null;
      if (game.archenemyId == playerId) {
        game.archenemyId = game.players.isEmpty ? null : game.players.first.id;
      }
      if (game.activeIndex >= game.players.length) {
        game.activeIndex = 0;
      } else if (index < game.activeIndex) {
        game.activeIndex -= 1;
      }
      if (game.players.isNotEmpty) {
        game.seatShift %= game.players.length;
      }
    });
  }

  void setPlayerCount(int count) {
    final minPlayers = game.sharedLife ? 2 : 1;
    var target = count.clamp(minPlayers, 8);
    if (game.sharedLife && target.isOdd) target += 1;
    target = target.clamp(minPlayers, 8);
    if (target == game.players.length) return;
    _commit('$target joueurs à table', () {
      while (game.players.length < target) {
        final index = game.players.length;
        final commanders = <Commander>[];
        if (game.tracksCommanders) {
          commanders.add(Commander(id: newId('cmd'), name: 'Commandant'));
        }
        final newbie = Player(
          id: newId('p'),
          name: 'Joueur ${index + 1}',
          color: index % 8,
          life: game.startingLife,
          commanders: commanders,
          mana: {for (final key in manaKeys) key: 0},
        );
        newbie.life = newbie.startingLifeFor(game);
        game.players.add(newbie);
      }
      while (game.players.length > target) {
        final player = game.players.removeLast();
        final commanderIds = [for (final c in player.commanders) c.id];
        for (final other in game.players) {
          for (final id in commanderIds) {
            other.damageTaken.remove(id);
          }
        }
        if (game.monarchId == player.id) game.monarchId = null;
        if (game.initiativeId == player.id) game.initiativeId = null;
        if (game.archenemyId == player.id) {
          game.archenemyId = game.players.isEmpty
              ? null
              : game.players.first.id;
        }
      }
      if (game.activeIndex >= game.players.length) game.activeIndex = 0;
      if (game.players.isNotEmpty) {
        game.seatShift %= game.players.length;
      }
    });
  }

  void setCommanderDamage({
    required String defenderId,
    required String commanderId,
    required int value,
  }) {
    final current = playerById(defenderId).damageTaken[commanderId] ?? 0;
    addCommanderDamage(
      defenderId: defenderId,
      commanderId: commanderId,
      delta: value.clamp(0, game.commanderThreshold) - current,
    );
  }

  void addCommander(String playerId, String name) {
    final player = playerById(playerId);
    if (player.commanders.length >= 4) return;
    final label = name.trim().isEmpty
        ? 'Commandant ${player.commanders.length + 1}'
        : name.trim();
    final commander = Commander(id: newId('cmd'), name: label);
    _commit('${player.name} : commandant $label', () {
      player.commanders.add(commander);
    });
  }

  void renameCommander(String commanderId, String name, {String? artUrl}) {
    final found = findCommander(commanderId);
    if (found == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (trimmed == found.commander.name && artUrl == found.commander.artUrl) {
      return;
    }
    _commit('${found.owner.name} renomme ${found.commander.name}', () {
      found.commander.name = trimmed;
      if (artUrl != null) found.commander.artUrl = artUrl;
    });
  }

  void setCommanderArt(String commanderId, String? artUrl) {
    final found = findCommander(commanderId);
    if (found == null || found.commander.artUrl == artUrl) return;
    found.commander.artUrl = artUrl;
    notifyListeners();
    onChanged?.call();
  }

  void dealTreacheryRoles() {
    if (game.format != MatchFormat.treachery) return;
    final alive = [for (final player in game.players) if (!player.conceded) player];
    if (alive.length < 3) return;
    final roles = <TreacheryRole>[TreacheryRole.leader];
    final remaining = alive.length - 1;
    final traitors = (remaining / 3).floor().clamp(1, remaining);
    final assassins = (remaining - traitors) >= 2
        ? ((remaining - traitors) / 2).ceil()
        : 0;
    final guardians = remaining - traitors - assassins;
    roles.addAll(List.filled(traitors, TreacheryRole.traitor));
    roles.addAll(List.filled(assassins, TreacheryRole.assassin));
    roles.addAll(List.filled(guardians, TreacheryRole.guardian));
    while (roles.length < alive.length) {
      roles.add(TreacheryRole.guardian);
    }
    roles.shuffle(Random());
    _commit('Rôles Traîtrise distribués', () {
      for (var i = 0; i < alive.length; i++) {
        alive[i].treacheryRole = roles[i];
        alive[i].treacheryRevealed = false;
      }
    });
    flash('Rôles Traîtrise distribués (secrets)');
  }

  void revealTreachery(String playerId) {
    final player = playerById(playerId);
    if (player.treacheryRole == TreacheryRole.none || player.treacheryRevealed) {
      return;
    }
    _commit(
      '${player.name} révèle ${treacheryRoleLabel(player.treacheryRole)}',
      () => player.treacheryRevealed = true,
    );
    flash('${player.name} · ${treacheryRoleLabel(player.treacheryRole)}');
  }

  void removeCommander(String commanderId) {
    final found = findCommander(commanderId);
    if (found == null) return;
    _commit('${found.owner.name} retire ${found.commander.name}', () {
      found.owner.commanders.removeWhere(
        (commander) => commander.id == commanderId,
      );
      for (final player in game.players) {
        player.damageTaken.remove(commanderId);
      }
    });
  }

  void castCommander(String commanderId, int delta) {
    final found = findCommander(commanderId);
    if (found == null || delta == 0) return;
    final next = (found.commander.casts + delta).clamp(0, 30);
    final applied = next - found.commander.casts;
    if (applied == 0) return;
    _commit(
      '${found.owner.name} · taxe ${found.commander.name} ${found.commander.tax} → ${next * 2}',
      () => found.commander.casts = next,
    );
  }

  void renamePlayer(String playerId, String name) {
    final player = playerById(playerId);
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == player.name) return;
    _commit('${player.name} devient $trimmed', () => player.name = trimmed);
  }

  void setColor(String playerId, int color) {
    final player = playerById(playerId);
    if (player.color == color) return;
    _commit('Couleur de ${player.name}', () => player.color = color);
  }

  void bumpStat(String playerId, Stat stat, int delta) {
    if (delta == 0) return;
    final player = playerById(playerId);
    final current = player.readStat(stat);
    final max = stat == Stat.poison || stat == Stat.signature ? 30 : 99;
    final next = (current + delta).clamp(0, max);
    if (next == current) return;
    _commit('${player.name} · ${statLabel(stat)} $current → $next', () {
      player.writeStat(stat, next);
    });
  }

  void bumpMana(String playerId, String color, int delta) {
    if (!manaKeys.contains(color) || delta == 0) return;
    final player = playerById(playerId);
    final current = player.mana[color] ?? 0;
    final next = (current + delta).clamp(0, 99);
    if (next == current) return;
    _commit('${player.name} · mana $color $current → $next', () {
      player.mana[color] = next;
    });
  }

  void addCustom(String playerId, String name) {
    final player = playerById(playerId);
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final counter = NamedCounter(id: newId('cnt'), name: trimmed);
    _commit(
      '${player.name} · suivi $trimmed',
      () => player.custom.add(counter),
    );
  }

  void bumpCustom(String playerId, String counterId, int delta) {
    if (delta == 0) return;
    final player = playerById(playerId);
    final index = player.custom.indexWhere(
      (counter) => counter.id == counterId,
    );
    if (index < 0) return;
    final counter = player.custom[index];
    final next = (counter.value + delta).clamp(0, 99);
    if (next == counter.value) return;
    _commit('${player.name} · ${counter.name} ${counter.value} → $next', () {
      counter.value = next;
    });
  }

  void removeCustom(String playerId, String counterId) {
    final player = playerById(playerId);
    final index = player.custom.indexWhere(
      (counter) => counter.id == counterId,
    );
    if (index < 0) return;
    final name = player.custom[index].name;
    _commit('${player.name} retire $name', () {
      player.custom.removeAt(index);
    });
  }

  void setRing(String playerId, int value) {
    final player = playerById(playerId);
    final next = value.clamp(0, 4);
    if (next == player.ring) return;
    _commit('${player.name} · anneau $next', () => player.ring = next);
  }

  void toggleBlessing(String playerId) {
    final player = playerById(playerId);
    _commit(
      player.blessing
          ? '${player.name} perd la bénédiction'
          : '${player.name} a la bénédiction',
      () => player.blessing = !player.blessing,
    );
  }

  void toggleMonarch(String playerId) {
    final player = playerById(playerId);
    if (game.monarchId == playerId) {
      _commit('Plus de monarque', () => game.monarchId = null);
    } else {
      _commit('Monarque : ${player.name}', () => game.monarchId = playerId);
    }
  }

  void toggleInitiative(String playerId) {
    final player = playerById(playerId);
    if (game.initiativeId == playerId) {
      _commit("Plus d'initiative", () => game.initiativeId = null);
    } else {
      _commit(
        'Initiative : ${player.name}',
        () => game.initiativeId = playerId,
      );
    }
  }

  void setDay(DayState state) {
    if (game.dayState == state) return;
    final label = switch (state) {
      DayState.day => 'Jour',
      DayState.night => 'Nuit',
      DayState.unset => 'Jour / nuit effacé',
    };
    _commit(label, () => game.dayState = state);
  }

  void setConceded(String playerId, bool value) {
    final player = playerById(playerId);
    if (player.conceded == value) return;
    _commit(
      value ? '${player.name} quitte la partie' : '${player.name} revient',
      () => player.conceded = value,
    );
  }

  void revivePlayer(String playerId) {
    final player = playerById(playerId);
    if (!game.isDefeated(player)) return;

    // Remise minimale : juste sous le seuil létal, sans inventer de PV.
    // Les corrections de commandant passent par addCommanderDamage (PV cohérents).
    final lethalCommanders = <String>[
      for (final entry in player.damageTaken.entries)
        if (entry.value >= game.commanderThreshold) entry.key,
    ];
    final needLife = game.lifeLethal(player);
    final needPoison = game.poisonLethal(player);
    final wasConceded = player.conceded;

    if (wasConceded) {
      setConceded(playerId, false);
    }
    for (final commanderId in lethalCommanders) {
      final taken = playerById(playerId).damageTaken[commanderId] ?? 0;
      final target = game.commanderThreshold - 1;
      if (taken > target) {
        addCommanderDamage(
          defenderId: playerId,
          commanderId: commanderId,
          delta: target - taken,
        );
      }
    }
    if (needLife && playerById(playerId).life <= 0) {
      setLife(playerId, 1);
    }
    if (needPoison) {
      final poison = playerById(playerId).poison;
      final target = game.poisonThreshold - 1;
      if (poison > target) {
        bumpStat(playerId, Stat.poison, target - poison);
      }
    }
    if (!game.isDefeated(playerById(playerId))) {
      flash('${playerById(playerId).name} revient à la table');
    }
  }

  void nextTurn() {
    final leaving = game.players[game.activeIndex];
    final spentMs = turnElapsed.inMilliseconds;
    var next = game.activeIndex;
    var guard = 0;
    do {
      next = (next + 1) % game.players.length;
      guard++;
    } while (game.players[next].conceded && guard < game.players.length);
    final wrapped = next <= game.activeIndex;
    final incoming = game.players[next];
    _commit(
      wrapped
          ? 'Manche ${game.roundNumber + 1} · ${incoming.name}'
          : 'Tour de ${incoming.name}',
      () {
        if (game.timerMode == TimerMode.chess) {
          leaving.clockBankMs = (leaving.clockBankMs - spentMs).clamp(
            0,
            game.chessBankSeconds * 1000,
          );
        }
        if (game.resetManaOnTurn) {
          for (final key in manaKeys) {
            leaving.mana[key] = 0;
          }
        }
        if (game.resetStormOnTurn) leaving.storm = 0;
        game.activeIndex = next;
        game.turnCount += 1;
        if (wrapped) game.roundNumber += 1;
      },
    );
    turnStarted = DateTime.now();
    if (game.timerMode == TimerMode.chess && leaving.clockBankMs <= 0) {
      flash('${leaving.name} · banque de temps épuisée');
    }
  }

  void addClockBank(String playerId, Duration delta) {
    final player = playerById(playerId);
    final next = (player.clockBankMs + delta.inMilliseconds).clamp(
      0,
      6 * 3600 * 1000,
    );
    if (next == player.clockBankMs) return;
    _commit('${player.name} · chronomètre', () => player.clockBankMs = next);
  }

  void setActive(int index) {
    if (index < 0 || index >= game.players.length) return;
    if (index == game.activeIndex) return;
    final player = game.players[index];
    _commit('Joueur actif : ${player.name}', () => game.activeIndex = index);
    turnStarted = DateTime.now();
  }

  void rotateSeats() {
    if (game.players.isEmpty) return;
    _commit('Places tournées', () {
      game.seatShift = (game.seatShift + 1) % game.players.length;
    });
  }

  void shuffleSeats() {
    if (game.players.length < 2) return;
    final activeId = game.players[game.activeIndex].id;
    _commit('Places mélangées', () {
      game.players.shuffle(Random());
      game.seatShift = 0;
      final next = game.players.indexWhere((player) => player.id == activeId);
      if (next >= 0) game.activeIndex = next;
    });
  }

  void planeswalk() {
    if (game.planechase && game.planes.isNotEmpty) {
      _commit('Planeswalk', () {
        game.planeIndex = (game.planeIndex + 1) % game.planes.length;
      });
      flash('Planeswalk · ${game.currentPlane}');
      return;
    }
    flash('Planeswalk');
  }

  void renamePlane(String name) {
    if (!game.planechase || game.planes.isEmpty) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final index = game.planeIndex.clamp(0, game.planes.length - 1);
    _commit('Plan : $trimmed', () => game.planes[index] = trimmed);
  }

  void nextScheme() {
    if (game.schemes.isNotEmpty) {
      _commit('Schéma suivant', () {
        game.schemeIndex = (game.schemeIndex + 1) % game.schemes.length;
        game.schemeNumber += 1;
      });
      flash(game.currentScheme);
      return;
    }
    _commit('Schéma ${game.schemeNumber + 1}', () => game.schemeNumber += 1);
    flash('Schéma ${game.schemeNumber}');
  }

  void raiseBounty() {
    if (!game.bounty) return;
    if (game.bountyLevel >= officialBounties.length - 1) {
      flash('Prime au maximum');
      return;
    }
    _commit('Prime ↑', () => game.bountyLevel += 1);
    flash(game.currentBounty.name);
  }

  void claimBounty(String playerId) {
    if (!game.bounty) return;
    final player = playerById(playerId);
    final card = game.currentBounty;
    _commit('${player.name} réclame ${card.name}', () {
      game.bountyLevel = 0;
    });
    _pushLifeChange(
      LifeChange(
        playerId: player.id,
        playerName: player.name,
        from: player.life,
        to: player.life,
        delta: 0,
        turnCount: game.turnCount,
        roundNumber: game.roundNumber,
        reason: 'prime ${card.name}',
        atMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    flash('${player.name} · ${card.reward}');
  }

  void setPanelArt(String playerId, String? artUrl) {
    final player = playerById(playerId);
    if (player.panelArtUrl == artUrl) return;
    _commit('${player.name} · fond', () => player.panelArtUrl = artUrl);
  }

  void setSignatureName(String playerId, String name) {
    final player = playerById(playerId);
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == player.signatureName) return;
    _commit('${player.name} · sort $trimmed', () {
      player.signatureName = trimmed;
    });
  }

  void setArchenemy(String playerId) {
    final player = playerById(playerId);
    _commit('Archenemy : ${player.name}', () => game.archenemyId = playerId);
  }

  void _wipeBoard({
    required bool resetRoundNumber,
    required bool resetActiveSeat,
  }) {
    for (final player in game.players) {
      player.life = player.startingLifeFor(game);
      player.damageTaken.clear();
      player.lifeDrainedByCommander.clear();
      player.poison = 0;
      player.energy = 0;
      player.experience = 0;
      player.rad = 0;
      player.speed = 0;
      player.treasure = 0;
      player.storm = 0;
      player.signatureCasts = 0;
      player.blessing = false;
      player.ring = 0;
      player.conceded = false;
      for (final key in manaKeys) {
        player.mana[key] = 0;
      }
      for (final commander in player.commanders) {
        commander.casts = 0;
      }
      for (final counter in player.custom) {
        counter.value = 0;
      }
      player.clockBankMs = game.chessBankSeconds * 1000;
    }
    if (resetActiveSeat) game.activeIndex = 0;
    if (resetRoundNumber) {
      game.roundNumber = 1;
    } else {
      game.roundNumber += 1;
    }
    game.turnCount = 1;
    game.monarchId = null;
    game.initiativeId = null;
    game.dayState = DayState.unset;
    game.planeIndex = 0;
    game.schemeIndex = 0;
    game.schemeNumber = 0;
    game.bountyLevel = 0;
    for (final player in game.players) {
      player.treacheryRole = TreacheryRole.none;
      player.treacheryRevealed = false;
    }
    journal.clear();
    lifeLog.clear();
    cmdDamageLog.clear();
  }

  /// Remet vies et compteurs à zéro, manche 1, premier siège actif.
  void resetRound() {
    _commit('Remise à zéro', () {
      _wipeBoard(resetRoundNumber: true, resetActiveSeat: true);
    });
    final now = DateTime.now();
    turnStarted = now;
    matchStarted = now;
  }

  /// Nouvelle manche : scores à zéro, numéro de manche +1, siège actif inchangé.
  void rematch() {
    _commit('Revanche', () {
      _wipeBoard(resetRoundNumber: false, resetActiveSeat: false);
    });
    final now = DateTime.now();
    turnStarted = now;
    matchStarted = now;
  }

  void removeLastCommander(String playerId) {
    final player = playerById(playerId);
    if (player.commanders.length <= 1) return;
    removeCommander(player.commanders.last.id);
  }

  void applyRules(AppSettings settings) {
    final same =
        game.resetManaOnTurn == settings.resetManaOnTurn &&
        game.resetStormOnTurn == settings.resetStormOnTurn &&
        game.commanderThreshold == settings.commanderThreshold &&
        game.poisonThreshold == settings.poisonThreshold &&
        game.turnAlertSeconds == settings.turnAlertSeconds &&
        game.timerMode == settings.timerMode &&
        game.chessBankSeconds == settings.chessBankSeconds;
    if (same) return;
    final bankChanged = game.chessBankSeconds != settings.chessBankSeconds;
    _commit('Réglages de partie', () {
      game.linkDamageToLife = true;
      game.resetManaOnTurn = settings.resetManaOnTurn;
      game.resetStormOnTurn = settings.resetStormOnTurn;
      game.commanderThreshold = settings.commanderThreshold.clamp(1, 99);
      game.poisonThreshold = settings.poisonThreshold.clamp(1, 30);
      game.turnAlertSeconds = settings.turnAlertSeconds.clamp(0, 3600);
      game.timerMode = settings.timerMode;
      game.chessBankSeconds = settings.chessBankSeconds.clamp(60, 6 * 3600);
      if (bankChanged || settings.timerMode == TimerMode.chess) {
        for (final player in game.players) {
          if (player.clockBankMs <= 0 || bankChanged) {
            player.clockBankMs = game.chessBankSeconds * 1000;
          }
        }
      }
    });
  }

  Map<String, dynamic> exportSession() => {
    'game': game.toJson(),
    'undo': undoStack.map((trail) => trail.toJson()).toList(),
    'redo': redoStack.map((trail) => trail.toJson()).toList(),
    'journal': [for (final event in journal) event.toJson()],
    'lifeFeed': lifeFeed,
    'lifeLog': [for (final e in lifeLog) e.toJson()],
    'cmdDamageLog': [for (final e in cmdDamageLog) e.toJson()],
    'turnStartedMs': turnStarted.millisecondsSinceEpoch,
    'matchStartedMs': matchStarted.millisecondsSinceEpoch,
  };

  static GameController restore(
    Map<String, dynamic> json, {
    VoidCallback? onChanged,
  }) {
    List<Trail> readTrails(Object? raw) {
      if (raw is! List) return [];
      return [
        for (final item in raw)
          if (item is Map<String, dynamic>)
            Trail.fromJson(item)
          else if (item is Map)
            Trail.fromJson(Map<String, dynamic>.from(item)),
      ];
    }

    List<JournalEvent> readJournal(Object? raw) {
      if (raw is! List) return [];
      return [
        for (final item in raw)
          if (item is Map<String, dynamic>)
            JournalEvent.fromJson(item)
          else if (item is Map)
            JournalEvent.fromJson(Map<String, dynamic>.from(item)),
      ];
    }

    final started = asInt(json['turnStartedMs']);
    final matchMs = asInt(json['matchStartedMs']);
    final controller = GameController(
      game: Game.fromJson(
        json['game'] is Map<String, dynamic>
            ? json['game'] as Map<String, dynamic>
            : Map<String, dynamic>.from(json['game'] as Map),
      ),
      undo: readTrails(json['undo']),
      redo: readTrails(json['redo']),
      journal: readJournal(json['journal']),
      onChanged: onChanged,
      turnStarted: started == 0
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(started),
      matchStarted: matchMs == 0
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(matchMs),
    );
    final log = json['lifeLog'];
    if (log is List) {
      for (final item in log) {
        if (item is Map<String, dynamic>) {
          controller.lifeLog.add(LifeChange.fromJson(item));
        } else if (item is Map) {
          controller.lifeLog.add(
            LifeChange.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    } else {
      final feed = json['lifeFeed'];
      if (feed is List) {
        for (final line in feed) {
          final text = '$line';
          controller.lifeLog.add(
            LifeChange(
              playerId: '',
              playerName: text,
              from: 0,
              to: 0,
              delta: 0,
              turnCount: 1,
              roundNumber: 1,
              reason: text,
            ),
          );
        }
      }
    }
    final cmdLog = json['cmdDamageLog'];
    if (cmdLog is List) {
      for (final item in cmdLog) {
        if (item is Map<String, dynamic>) {
          controller.cmdDamageLog.add(CmdDamageChange.fromJson(item));
        } else if (item is Map) {
          controller.cmdDamageLog.add(
            CmdDamageChange.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return controller;
  }
}
