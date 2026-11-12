import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mtg_table/domain/dungeons.dart';
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

/// Couronne qui vient de changer. L’affichage débutant s’en sert un court instant.
class CrownChange {
  const CrownChange({
    required this.id,
    required this.lostId,
    required this.gainedId,
  });

  final int id;
  final String? lostId;
  final String gainedId;
}

/// Le monarque a perdu des points : était-ce une blessure de combat ?
class CombatAsk {
  const CombatAsk({
    required this.id,
    required this.monarchId,
    required this.attackerId,
  });

  final int id;
  final String monarchId;

  /// Null : on ne sait pas qui a frappé (le joueur retire ses propres points).
  final String? attackerId;
}

class GameController extends ChangeNotifier {
  /// Son d’effet quand la vie change. Branché par l’écran de table.
  static void Function(CastTone cast, int delta)? lifeSound;

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
       journal = journal ?? [] {
    this.turnStarted = turnStarted ?? DateTime.now();
    this.matchStarted = matchStarted ?? DateTime.now();
  }

  Game game;
  /// Dernier joueur passé à terre. La revanche lui rend la main.
  String? lastFallenId;
  Set<String> _downIds = {};
  final List<Trail> undoStack;
  final List<Trail> redoStack;
  final List<JournalEvent> journal;
  final VoidCallback? onChanged;
  DateTime _turnAnchor = DateTime.now();
  DateTime _matchAnchor = DateTime.now();
  final Stopwatch _turnWatch = Stopwatch();
  final Stopwatch _matchWatch = Stopwatch();
  Duration _turnBase = Duration.zero;
  Duration _matchBase = Duration.zero;
  bool clockPaused = false;

  DateTime get turnStarted => _turnAnchor;
  set turnStarted(DateTime value) {
    _turnAnchor = value;
    _turnWatch
      ..stop()
      ..reset();
    final behind = DateTime.now().difference(value);
    _turnBase = behind.isNegative ? Duration.zero : behind;
    if (!clockPaused) _turnWatch.start();
  }

  DateTime get matchStarted => _matchAnchor;
  set matchStarted(DateTime value) {
    _matchAnchor = value;
    _matchWatch
      ..stop()
      ..reset();
    final behind = DateTime.now().difference(value);
    _matchBase = behind.isNegative ? Duration.zero : behind;
    if (!clockPaused) _matchWatch.start();
  }
  String lastLabel = '';
  int flashId = 0;
  String flashText = '';
  CrownChange? crownChange;
  DateTime? crownAt;
  CombatAsk? combatAsk;
  int _crownSeq = 0;
  int _askSeq = 0;
  int? _combatDeclinedTurn;
  /// Historique complet des PV depuis le début (plus récent en tête).
  final List<LifeChange> lifeLog = [];

  /// Historique des dégâts de commandant (plus récent en tête).
  final List<CmdDamageChange> cmdDamageLog = [];

  /// Mémoire locale des coups de commandant. Les totaux du plateau restent suivis.
  bool rememberCommanderLog = true;

  /// Pas de fin de tour : une perte de points éclaire le compte touché.
  bool noEndTurn = false;

  /// Vrai pendant qu’un téléphone voisin remplace la partie : on n’écho pas le lien.
  bool applyingRemote = false;
  static int _eventSeq = 0;

  String _eventId() =>
      'e${DateTime.now().microsecondsSinceEpoch}-${_eventSeq++}';

  /// Lignes pour récap / bandeau (dérivées de [lifeLog]).
  List<String> get lifeFeed => [for (final e in lifeLog) e.line];

  Duration get turnElapsed => _turnBase + _turnWatch.elapsed;
  Duration get matchElapsed => _matchBase + _matchWatch.elapsed;

  void pauseClock() {
    if (clockPaused) return;
    _turnBase += _turnWatch.elapsed;
    _matchBase += _matchWatch.elapsed;
    _turnWatch
      ..stop()
      ..reset();
    _matchWatch
      ..stop()
      ..reset();
    clockPaused = true;
    notifyListeners();
  }

  void resumeClock() {
    if (!clockPaused) return;
    clockPaused = false;
    _turnWatch.start();
    _matchWatch.start();
    notifyListeners();
  }

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
    String? sourceId,
  }) {
    if (from == to && reason == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final delta = to - from;
    // Fusion taps rapides : −1×5 → un seul −5 (comme Lifetap / Portal).
    if (delta != 0 && lifeLog.isNotEmpty) {
      final last = lifeLog.first;
      final samePlayer = last.playerId == player.id;
      final sameReason = last.reason == reason;
      final sameSource = last.sourceId == sourceId;
      final fresh =
          last.atMs != null && (now - last.atMs!) <= lifeDeltaMergeMs;
      final lastDelta = last.delta;
      final sameSign =
          lastDelta == 0 || delta == 0 || (lastDelta > 0) == (delta > 0);
      if (samePlayer &&
          sameReason &&
          sameSource &&
          fresh &&
          sameSign &&
          lastDelta != 0) {
        lifeLog[0] = last.copy(to: to, delta: to - last.from, atMs: now);
        return;
      }
    }
    _pushLifeChange(
      LifeChange(
        id: _eventId(),
        playerId: player.id,
        playerName: _groupLabel(player),
        from: from,
        to: to,
        delta: delta,
        turnCount: game.turnCount,
        roundNumber: game.roundNumber,
        reason: reason,
        atMs: now,
        sourceId: sourceId,
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
    if (!rememberCommanderLog || fromTaken == toTaken) return;
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
        cmdDamageLog[0] = last.copy(
          toTaken: toTaken,
          delta: toTaken - last.fromTaken,
          lifeTo: lifeTo,
          atMs: now,
        );
        return;
      }
    }
    _pushCmdDamageChange(
      CmdDamageChange(
        id: _eventId(),
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
    if (!game.timersEnabled ||
        game.timerMode != TimerMode.chess ||
        game.players.isEmpty) {
      return Duration.zero;
    }
    final active = game.players[game.activeIndex];
    final left = active.clockBankMs - turnElapsed.inMilliseconds;
    return Duration(milliseconds: left.clamp(-3600 * 1000, 6 * 3600 * 1000));
  }

  bool get turnOverAlert {
    if (!game.timersEnabled) return false;
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
    _rememberFallen();
    notifyListeners();
    onChanged?.call();
  }

  void _rememberFallen() {
    final now = <String>{
      for (final player in game.players)
        if (game.isDefeated(player)) player.id,
    };
    for (final id in now) {
      if (!_downIds.contains(id)) lastFallenId = id;
    }
    _downIds = now;
  }

  void undo() => undoSteps(1);

  void undoSteps(int steps) {
    if (steps <= 0 || undoStack.isEmpty) return;
    for (var i = 0; i < steps; i++) {
      if (undoStack.isEmpty) break;
      final trail = undoStack.removeLast();
      final lives = {for (final player in game.players) player.id: player.life};
      redoStack.add(Trail(trail.label, game.toJson()));
      game = Game.fromJson(trail.before);
      for (final player in game.players) {
        if (lives[player.id] != player.life) {
          _markLife(player.id, retracted: true);
          _markCmd(player.id, retracted: true);
        }
      }
      if (journal.isNotEmpty && journal.first.label == trail.label) {
        journal.removeAt(0);
      }
      lastLabel = 'Annulé · ${trail.label}';
    }
    _rememberFallen();
    crownChange = null;
    combatAsk = null;
    turnStarted = DateTime.now();
    notifyListeners();
    onChanged?.call();
  }

  void redo() {
    if (redoStack.isEmpty) return;
    final trail = redoStack.removeLast();
    final lives = {for (final player in game.players) player.id: player.life};
    undoStack.add(Trail(trail.label, game.toJson()));
    game = Game.fromJson(trail.before);
    for (final player in game.players) {
      if (lives[player.id] != player.life) {
        _markLife(player.id, retracted: false);
        _markCmd(player.id, retracted: false);
      }
    }
    lastLabel = trail.label;
    _rememberFallen();
    crownChange = null;
    combatAsk = null;
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

  void _markLife(String playerId, {required bool retracted}) {
    for (var i = 0; i < lifeLog.length; i++) {
      final event = lifeLog[i];
      if (event.playerId != playerId || event.retracted == retracted) continue;
      lifeLog[i] = event.copy(retracted: retracted);
      return;
    }
  }

  void _markCmd(String playerId, {required bool retracted}) {
    for (var i = 0; i < cmdDamageLog.length; i++) {
      final event = cmdDamageLog[i];
      if (event.defenderId != playerId || event.retracted == retracted) {
        continue;
      }
      cmdDamageLog[i] = event.copy(retracted: retracted);
      return;
    }
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

  /// Joueur encore en jeu, autre que [leavingId].
  bool _canWearCrown(Player player, String leavingId) {
    return player.id != leavingId && !game.isDefeated(player);
  }

  /// Le monarque quitte : le joueur actif, sinon le suivant dans l’ordre du tour.
  String? _crownHeir(String leavingId) {
    if (game.players.isEmpty) return null;
    final active = game.players[game.activeIndex];
    if (_canWearCrown(active, leavingId)) return active.id;
    var index = game.activeIndex;
    for (var n = 0; n < game.players.length; n++) {
      index = (index + 1) % game.players.length;
      if (_canWearCrown(game.players[index], leavingId)) {
        return game.players[index].id;
      }
    }
    return null;
  }

  /// Si le monarque n’est plus à la table, la couronne passe. Renvoie l’ancien.
  String? _rehomeCrown() {
    final id = game.monarchId;
    if (id == null) return null;
    final index = game.players.indexWhere((player) => player.id == id);
    final gone = index < 0 || game.isDefeated(game.players[index]);
    if (!gone) return null;
    game.monarchId = _crownHeir(id);
    return id;
  }

  /// Même passage que la couronne : le joueur actif, sinon le suivant.
  String? _rehomeInitiative() {
    final id = game.initiativeId;
    if (id == null) return null;
    final index = game.players.indexWhere((player) => player.id == id);
    final gone = index < 0 || game.isDefeated(game.players[index]);
    if (!gone) return null;
    game.initiativeId = _crownHeir(id);
    return id;
  }

  void _giveInitiative(String fromId, String toId) {
    if (game.initiativeId != fromId || toId == fromId) return;
    final index = game.players.indexWhere((player) => player.id == toId);
    if (index < 0 || game.isDefeated(game.players[index])) return;
    game.initiativeId = toId;
  }

  void _noteInitiative(String? before, {required String? monarchBefore}) {
    final now = game.initiativeId;
    if (now == before || game.monarchId != monarchBefore) return;
    if (now == null) {
      flash("Plus d'initiative");
      return;
    }
    flash('${playerById(now).name} prend l’initiative');
  }

  void _noteCrown(String? before, {String? lostName}) {
    final now = game.monarchId;
    if (now == before) return;
    combatAsk = null;
    if (now == null) {
      flash('Plus de monarque');
      crownChange = null;
      return;
    }
    final gained = playerById(now).name;
    String? lost = lostName;
    if (lost == null && before != null) {
      final index = game.players.indexWhere((player) => player.id == before);
      if (index >= 0) lost = game.players[index].name;
    }
    crownAt = DateTime.now();
    crownChange = CrownChange(
      id: ++_crownSeq,
      lostId: before,
      gainedId: now,
    );
    flash(
      lost == null
          ? '$gained est monarque'
          : '$lost perd la couronne. $gained est monarque.',
    );
  }

  void _offerCombat({required String defenderId, String? dealtBy}) {
    final crown = game.monarchId == defenderId;
    final initiative = game.initiativeId == defenderId;
    if (!crown && !initiative) return;
    if (_combatDeclinedTurn == game.turnCount) return;
    if (combatAsk != null) return;
    final attacker = dealtBy != null && dealtBy != defenderId ? dealtBy : null;
    combatAsk = CombatAsk(
      id: ++_askSeq,
      monarchId: defenderId,
      attackerId: attacker,
    );
    notifyListeners();
  }

  /// [attackerId] null : ce n’était pas une blessure de combat.
  void answerCombat(String? attackerId) {
    final ask = combatAsk;
    combatAsk = null;
    if (ask == null) {
      notifyListeners();
      return;
    }
    final defender = ask.monarchId;
    if (game.indexOf(defender) < 0) {
      notifyListeners();
      return;
    }
    if (attackerId == null || attackerId == defender) {
      _combatDeclinedTurn = game.turnCount;
      notifyListeners();
      return;
    }
    final before = game.monarchId;
    final initiativeBefore = game.initiativeId;
    final wasCrown = before == defender;
    final hadInitiative = initiativeBefore == defender;
    if (!wasCrown && !hadInitiative) {
      notifyListeners();
      return;
    }
    final name = playerById(attackerId).name;
    final lostName = playerById(defender).name;
    final label = wasCrown ? '$name prend la couronne' : '$name prend l’initiative';
    _commit(label, () {
      if (wasCrown) game.monarchId = attackerId;
      if (hadInitiative) _giveInitiative(defender, attackerId);
    });
    _noteCrown(before, lostName: lostName);
    _noteInitiative(initiativeBefore, monarchBefore: before);
  }

  void addLife(String playerId, int delta, {String? dealtBy}) {
    if (delta == 0) return;
    final player = playerById(playerId);
    final before = player.life;
    final next = (before + delta).clamp(-99, 999);
    if (next == before) return;
    final wasAlive = !game.lifeLethal(player);
    final monarchBefore = game.monarchId;
    final initiativeBefore = game.initiativeId;
    final label =
        '${_groupLabel(player)} $before → $next (${next > before ? '+' : ''}${next - before})';
    final source = dealtBy != null && dealtBy != player.id ? dealtBy : null;
    _commit(label, () {
      _setLife(player, next);
      _rehomeCrown();
      _rehomeInitiative();
      _recordLife(
        player: player,
        from: before,
        to: next,
        sourceId: source,
      );
      if (next < before) _markVictim(player.id);
    });
    _noteCrown(monarchBefore);
    _noteInitiative(initiativeBefore, monarchBefore: monarchBefore);
    if (wasAlive && next <= 0) {
      flash('${player.name} est à terre');
    } else if (next < before &&
        (game.monarchId == player.id || game.initiativeId == player.id)) {
      _offerCombat(defenderId: player.id, dealtBy: dealtBy);
    }
    lifeSound?.call(player.cast, next - before);
  }

  /// Un seul annuler pour plusieurs joueurs (tous les adversaires, zone…).
  void addLifeMany(Iterable<String> playerIds, int delta, {String? dealtBy}) {
    if (delta == 0) return;
    final ids = <String>[];
    for (final id in playerIds) {
      if (game.indexOf(id) < 0 || ids.contains(id)) continue;
      ids.add(id);
    }
    if (ids.isEmpty) return;
    if (ids.length == 1) {
      addLife(ids.first, delta, dealtBy: dealtBy);
      return;
    }

    final plans = <({String id, int from, int to})>[];
    for (final id in ids) {
      final from = playerById(id).life;
      final to = (from + delta).clamp(-99, 999);
      if (to != from) plans.add((id: id, from: from, to: to));
    }
    if (plans.isEmpty) return;
    final losers = [
      for (final plan in plans)
        if (plan.to < plan.from) plan.id,
    ];

    final sign = delta > 0 ? '+$delta' : '$delta';
    final everyone = ids.length == game.players.length;
    final label = everyone
        ? 'Tous $sign'
        : '${plans.length} joueurs $sign';
    final monarchBefore = game.monarchId;
    final initiativeBefore = game.initiativeId;
    final monarchDropped =
        monarchBefore != null &&
        plans.any((plan) => plan.id == monarchBefore && plan.to < plan.from);
    final initiativeDropped =
        initiativeBefore != null &&
        plans.any((plan) => plan.id == initiativeBefore && plan.to < plan.from);
    _commit(label, () {
      final teams = <int>{};
      for (final plan in plans) {
        final player = playerById(plan.id);
        if (game.sharedLife) {
          final team = game.indexOf(plan.id) ~/ 2;
          if (!teams.add(team)) continue;
          final now = player.life;
          _setLife(player, (now + delta).clamp(-99, 999));
        } else {
          _setLife(player, plan.to);
        }
      }
      _rehomeCrown();
      _rehomeInitiative();
      final source = dealtBy != null && dealtBy.isNotEmpty ? dealtBy : null;
      for (final plan in plans) {
        final player = playerById(plan.id);
        _recordLife(
          player: player,
          from: plan.from,
          to: player.life,
          sourceId: source != null && source != player.id ? source : null,
        );
      }
      if (losers.length == 1) _markVictim(losers.first);
    });
    _noteCrown(monarchBefore);
    _noteInitiative(initiativeBefore, monarchBefore: monarchBefore);
    for (final plan in plans) {
      final player = playerById(plan.id);
      if (plan.from > 0 && player.life <= 0) {
        flash('${player.name} est à terre');
      }
    }
    if (monarchDropped && game.monarchId == monarchBefore) {
      _offerCombat(defenderId: monarchBefore, dealtBy: dealtBy);
    } else if (initiativeDropped && game.initiativeId == initiativeBefore) {
      _offerCombat(defenderId: initiativeBefore, dealtBy: dealtBy);
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
    addCommanderDamageMany(
      defenderIds: [defenderId],
      commanderId: commanderId,
      delta: delta,
    );
  }

  /// Même commandant, plusieurs adversaires, un seul annuler.
  void addCommanderDamageMany({
    required Iterable<String> defenderIds,
    required String commanderId,
    required int delta,
  }) {
    if (!game.trackCommanderDamage || delta == 0) return;
    final found = findCommander(commanderId);
    if (found == null) return;
    final plans = <_CmdPlan>[];
    final seen = <String>{};
    for (final id in defenderIds) {
      if (!seen.add(id) || game.indexOf(id) < 0) continue;
      if (id == found.owner.id) continue;
      final plan = _planCommander(playerById(id), found, delta);
      if (plan != null) plans.add(plan);
    }
    if (plans.isEmpty) return;
    final source = plans.first.source;
    final monarchBefore = game.monarchId;
    final initiativeBefore = game.initiativeId;
    final label = plans.length == 1
        ? '${plans.first.defender.name} : ${plans.first.remaining} / '
            '${game.commanderThreshold} face à $source'
            ' · vie ${plans.first.lifeBefore} → ${plans.first.lifeAfter}'
        : '$source · ${plans.length} adversaires '
            '${delta > 0 ? '+$delta' : '$delta'}';
    _commit(label, () {
      for (final plan in plans) {
        final defender = plan.defender;
        defender.damageTaken[plan.commanderId] = plan.takenAfter;
        if (plan.lifeDelta != 0) {
          _setLife(
            defender,
            (defender.life + plan.lifeDelta).clamp(-99, 999),
          );
        }
        defender.lifeDrainedByCommander[plan.commanderId] = plan.drainedNext;
      }
      if (delta > 0 &&
          monarchBefore != null &&
          found.owner.id != monarchBefore &&
          plans.any(
            (plan) =>
                plan.defender.id == monarchBefore &&
                plan.takenAfter > plan.takenBefore,
          ) &&
          !game.isDefeated(found.owner)) {
        game.monarchId = found.owner.id;
      }
      if (delta > 0 && !game.isDefeated(found.owner)) {
        for (final plan in plans) {
          if (plan.takenAfter > plan.takenBefore) {
            _giveInitiative(plan.defender.id, found.owner.id);
          }
        }
      }
      _rehomeCrown();
      _rehomeInitiative();
      if (delta > 0 && plans.length == 1) {
        _markVictim(plans.first.defender.id);
      }
      for (final plan in plans) {
        if (plan.lifeBefore == plan.lifeAfter) continue;
        _recordLife(
          player: plan.defender,
          from: plan.lifeBefore,
          to: plan.lifeAfter,
          reason: plan.source,
          sourceId: found.owner.id,
        );
      }
    });
    _noteCrown(monarchBefore);
    _noteInitiative(initiativeBefore, monarchBefore: monarchBefore);
    for (final plan in plans) {
      final defender = plan.defender;
      final lifeMoved = plan.lifeBefore != defender.life;
      _recordCmdDamage(
        defender: defender,
        commanderId: plan.commanderId,
        commanderLabel: plan.source,
        fromTaken: plan.takenBefore,
        toTaken: plan.takenAfter,
        lifeFrom: lifeMoved ? plan.lifeBefore : null,
        lifeTo: lifeMoved ? defender.life : null,
      );
      if (plan.remaining == 0) {
        flash('${defender.name} hors jeu · ${plan.source}');
      } else if (game.lifeLethal(defender)) {
        flash('${defender.name} est à terre');
      }
    }
    final win = game.victoryBanner();
    if (win != null) flash(win);
  }

  _CmdPlan? _planCommander(Player defender, FoundCommander found, int delta) {
    final commanderId = found.commander.id;
    final current = defender.damageTaken[commanderId] ?? 0;
    final next = (current + delta).clamp(0, game.commanderThreshold);
    final applied = next - current;
    if (applied == 0) return null;
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
    final drainedNext = applied > 0
        ? drained + applied
        : (drained - lifeDelta).clamp(0, 99);
    return _CmdPlan(
      defender: defender,
      commanderId: commanderId,
      source: commanderChipLabel(found.owner, found.commander),
      takenBefore: current,
      takenAfter: next,
      lifeBefore: lifeBefore,
      lifeAfter: lifeAfter,
      lifeDelta: lifeDelta,
      remaining: game.commanderThreshold - next,
      drainedNext: drainedNext,
    );
  }

  void addPlayer({String? name}) {
    if (game.players.length >= maxTablePlayers) return;
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
    final monarchBefore = game.monarchId;
    final initiativeBefore = game.initiativeId;
    final heir = monarchBefore == playerId ? _crownHeir(playerId) : null;
    final initiativeHeir = initiativeBefore == playerId
        ? _crownHeir(playerId)
        : null;
    _commit('${player.name} quitte la table', () {
      final commanderIds = [for (final c in player.commanders) c.id];
      game.players.removeAt(index);
      for (final other in game.players) {
        for (final id in commanderIds) {
          other.damageTaken.remove(id);
        }
      }
      if (monarchBefore == playerId) game.monarchId = heir;
      if (initiativeBefore == playerId) game.initiativeId = initiativeHeir;
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
    if (monarchBefore == playerId) {
      _noteCrown(monarchBefore, lostName: player.name);
    }
    _noteInitiative(initiativeBefore, monarchBefore: monarchBefore);
  }

  void setPlayerCount(int count) {
    final minPlayers = game.sharedLife ? 2 : 1;
    var target = count.clamp(minPlayers, maxTablePlayers);
    if (game.sharedLife && target.isOdd) target += 1;
    target = target.clamp(minPlayers, maxTablePlayers);
    if (target == game.players.length) return;
    final monarchBefore = game.monarchId;
    final initiativeBefore = game.initiativeId;
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
        final player = game.players.last;
        final heir = game.monarchId == player.id ? _crownHeir(player.id) : null;
        final initiativeHeir = game.initiativeId == player.id
            ? _crownHeir(player.id)
            : null;
        game.players.removeLast();
        final commanderIds = [for (final c in player.commanders) c.id];
        for (final other in game.players) {
          for (final id in commanderIds) {
            other.damageTaken.remove(id);
          }
        }
        if (game.monarchId == player.id) game.monarchId = heir;
        if (initiativeHeir != null || game.initiativeId == player.id) {
          game.initiativeId = initiativeHeir;
        }
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
    _noteCrown(monarchBefore);
    _noteInitiative(initiativeBefore, monarchBefore: monarchBefore);
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

  /// Un ou deux commandants, depuis la couronne du rectangle.
  /// Un nom vide reste générique : un seul « Cdt Joueur », deux « Cdt 1 » et « Cdt 2 ».
  void setMyCommanders(
    String playerId, {
    required List<String> names,
  }) {
    if (names.isEmpty) return;
    final player = playerById(playerId);
    final count = names.length.clamp(1, 2).toInt();
    final resolved = <String>[];
    for (var i = 0; i < count; i++) {
      final raw = names[i].trim();
      resolved.add(
        raw.isEmpty ? (count == 1 ? 'Commandant' : 'Cdt ${i + 1}') : raw,
      );
    }
    final unchanged = player.commanders.length == count &&
        List.generate(count, (i) => i).every(
          (i) => player.commanders[i].name == resolved[i],
        );
    if (unchanged) return;
    final label = count == 1
        ? '${player.name} : ${resolved.first}'
        : '${player.name} : ${resolved[0]} / ${resolved[1]}';
    _commit(label, () {
      while (player.commanders.length < count) {
        player.commanders.add(
          Commander(id: newId('cmd'), name: 'Commandant'),
        );
      }
      while (player.commanders.length > count) {
        final gone = player.commanders.removeLast();
        for (final other in game.players) {
          other.damageTaken.remove(gone.id);
          other.lifeDrainedByCommander.remove(gone.id);
        }
      }
      for (var i = 0; i < count; i++) {
        player.commanders[i].name = resolved[i];
      }
    });
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
        player.lifeDrainedByCommander.remove(commanderId);
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

  void setCast(String playerId, CastTone cast) {
    final player = playerById(playerId);
    if (player.cast == cast) return;
    _commit('Animations de ${player.name}', () => player.cast = cast);
  }

  void setCastAll(CastTone cast) {
    final changed = [
      for (final player in game.players)
        if (player.cast != cast) player,
    ];
    if (changed.isEmpty) return;
    _commit('Animation', () {
      for (final player in changed) {
        player.cast = cast;
      }
    });
  }

  void setInks(String playerId, List<String> inks) {
    final player = playerById(playerId);
    final next = manaInkList(inks);
    if (next.length == player.inks.length &&
        next.every(player.inks.contains)) {
      return;
    }
    _commit('Couleurs de ${player.name}', () => player.inks = next);
  }

  void bumpStat(String playerId, Stat stat, int delta) {
    if (delta == 0) return;
    final player = playerById(playerId);
    final current = player.readStat(stat);
    final max = switch (stat) {
      Stat.poison || Stat.signature => 30,
      Stat.speed => 4,
      _ => 99,
    };
    if (stat == Stat.speed && delta > 0 && player.speedGainTurn == game.turnCount) {
      flash('${player.name} a déjà gagné en vitesse ce tour');
      return;
    }
    final next = (current + delta).clamp(0, max);
    if (next == current) return;
    final monarchBefore = game.monarchId;
    final initiativeBefore = game.initiativeId;
    _commit('${player.name} · ${statLabel(stat)} $current → $next', () {
      player.writeStat(stat, next);
      if (stat == Stat.speed && next > current) {
        player.speedGainTurn = game.turnCount;
      }
      if (stat == Stat.poison) {
        _rehomeCrown();
        _rehomeInitiative();
      }
    });
    if (stat == Stat.poison) {
      _noteCrown(monarchBefore, lostName: player.name);
      _noteInitiative(initiativeBefore, monarchBefore: monarchBefore);
    }
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
    if (player.blessing) {
      flash('${player.name} garde la bénédiction pour la partie');
      return;
    }
    _commit(
      player.blessing
          ? '${player.name} perd la bénédiction'
          : '${player.name} a la bénédiction',
      () => player.blessing = !player.blessing,
    );
  }

  void toggleMonarch(String playerId) {
    final player = playerById(playerId);
    final before = game.monarchId;
    if (before == playerId) {
      _commit('Plus de monarque', () => game.monarchId = null);
      crownChange = null;
      combatAsk = null;
      return;
    }
    _commit('Monarque : ${player.name}', () => game.monarchId = playerId);
    _noteCrown(before);
  }

  void toggleInitiative(String playerId) {
    final player = playerById(playerId);
    if (game.initiativeId == playerId) {
      _commit("Plus d'initiative", () => game.initiativeId = null);
      flash("Plus d'initiative");
      return;
    }
    _commit(
      'Initiative : ${player.name}',
      () => game.initiativeId = playerId,
    );
    flash('${player.name} s’enfonce dans le donjon');
  }

  void enterDungeon(String playerId, String dungeonId) {
    final dungeon = dungeonById(dungeonId);
    if (dungeon == null) return;
    final player = playerById(playerId);
    final room = dungeon.start;
    _commit('${player.name} entre dans ${dungeon.name}', () {
      player.dungeonId = dungeon.id;
      player.roomId = room.id;
    });
    flash('${player.name} · ${room.name}');
  }

  void venture(String playerId, String exitId) {
    final player = playerById(playerId);
    final dungeon = dungeonById(player.dungeonId);
    final room = dungeon?.room(player.roomId ?? '');
    if (dungeon == null || room == null || !room.exits.contains(exitId)) {
      return;
    }
    final next = dungeon.room(exitId);
    if (next == null) return;
    _commit('${player.name} · ${next.name}', () => player.roomId = next.id);
    flash(
      next.finished
          ? '${player.name} achève ${dungeon.name}'
          : '${player.name} · ${next.name}',
    );
  }

  void leaveDungeon(String playerId) {
    final player = playerById(playerId);
    if (player.dungeonId == null) return;
    _commit('${player.name} quitte le donjon', () {
      player.dungeonId = null;
      player.roomId = null;
    });
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
    final monarchBefore = game.monarchId;
    final initiativeBefore = game.initiativeId;
    _commit(
      value ? '${player.name} quitte la partie' : '${player.name} revient',
      () {
        player.conceded = value;
        if (value) {
          _rehomeCrown();
          _rehomeInitiative();
        }
      },
    );
    if (value) {
      _noteCrown(monarchBefore, lostName: player.name);
      _noteInitiative(initiativeBefore, monarchBefore: monarchBefore);
    }
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
    combatAsk = null;
    _commit(
      wrapped
          ? 'Manche ${game.roundNumber + 1} · ${incoming.name}'
          : 'Tour de ${incoming.name}',
      () {
        if (game.timersEnabled && game.timerMode == TimerMode.chess) {
          final bonus = game.chessBonusSeconds * 1000;
          leaving.clockBankMs = (leaving.clockBankMs - spentMs + bonus).clamp(
            -3600 * 1000,
            game.chessBankSeconds * 1000,
          );
          leaving.timeSpentMs += spentMs;
        }
        if (game.resetManaOnTurn) {
          for (final key in manaKeys) {
            leaving.mana[key] = 0;
          }
        }
        if (game.resetStormOnTurn) leaving.storm = 0;
        game.activeIndex = next;
        game.turnCount += 1;
        game.planarRolls = 0;
        if (wrapped) game.roundNumber += 1;
      },
    );
    turnStarted = DateTime.now();
    if (incoming.rad > 0) {
      flash(
        '${incoming.name} · radiation ${incoming.rad} : meule autant de cartes, puis retire 1 radiation',
      );
    }
    if (game.timersEnabled &&
        game.timerMode == TimerMode.chess &&
        leaving.clockBankMs <= 0) {
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

  void _markVictim(String playerId) {
    if (!noEndTurn) return;
    final index = game.indexOf(playerId);
    if (index < 0) return;
    game.activeIndex = index;
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

  /// Le premier lancer du tour est gratuit. Chaque suivant coûte 1 de plus.
  /// La face planeswalk ne change pas de plan : Marcher le fait, pour laisser
  /// le temps de répondre.
  PlanarRoll rollPlanarDie([int? faceIndex]) {
    if (!game.planechase) {
      flash('Pas de course planaire');
      return const PlanarRoll(PlanarFace.blank, 0);
    }
    final face = planarFaceOf((faceIndex ?? Random().nextInt(6)).clamp(0, 5));
    final cost = game.planarRolls;
    _commit('Dé planaire · $cost', () => game.planarRolls += 1);
    final detail = switch (face) {
      PlanarFace.blank => 'Face vide',
      PlanarFace.chaos => 'Chaos\n${game.currentPlaneChaos}',
      PlanarFace.planeswalk => 'Planeswalk\nTouchez Marcher pour changer de plan.',
    };
    flash('Dé planaire · coût $cost\n$detail');
    return PlanarRoll(face, cost);
  }

  void planeswalk() {
    if (game.planechase && game.planes.isNotEmpty) {
      final resolving = isPhenomenon(game.currentPlane);
      _commit(resolving ? 'Phénomène résolu' : 'Planeswalk', () {
        if (resolving) {
          final index = game.planeIndex.clamp(0, game.planes.length - 1);
          game.planes.removeAt(index);
          if (game.planes.isEmpty) {
            game.planeIndex = 0;
          } else if (game.planeIndex >= game.planes.length) {
            game.planeIndex = 0;
          }
        } else {
          game.planeIndex = (game.planeIndex + 1) % game.planes.length;
        }
      });
      final kind = isPhenomenon(game.currentPlane) ? 'Phénomène' : 'Plan';
      flash('$kind · ${game.currentPlane}');
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
      _commit('Stratagème suivant', () {
        game.schemeIndex = (game.schemeIndex + 1) % game.schemes.length;
        game.schemeNumber += 1;
      });
      flash(game.currentScheme);
      return;
    }
    _commit('Stratagème ${game.schemeNumber + 1}', () => game.schemeNumber += 1);
    flash('Stratagème ${game.schemeNumber}');
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
    final index = player.bountyIndex < 0 ? game.bountyLevel : player.bountyIndex;
    final card = bountyAtLevel(index);
    _commit('${player.name} réclame ${card.name}', () {
      player.bountyIndex = (index + 1) % officialBounties.length;
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

  void setArchenemy(String? playerId) {
    if (playerId == null) {
      if (game.archenemyId == null) return;
      _commit('Plus d’archennemi', () => game.archenemyId = null);
      return;
    }
    final player = playerById(playerId);
    if (game.archenemyId == playerId) return;
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
      player.timeSpentMs = 0;
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

  /// Revanche immédiate : tout repart, et celui qui vient de perdre commence.
  void revenge() {
    final starter = lastFallenId;
    final index = starter == null ? -1 : game.indexOf(starter);
    _commit('Revanche', () {
      _wipeBoard(resetRoundNumber: false, resetActiveSeat: false);
      if (index >= 0) game.activeIndex = index;
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
    final poison = poisonThresholdFor(game.format, settings.poisonThreshold);
    final same =
        game.resetManaOnTurn == settings.resetManaOnTurn &&
        game.resetStormOnTurn == settings.resetStormOnTurn &&
        game.commanderThreshold == settings.commanderThreshold &&
        game.poisonThreshold == poison &&
        game.turnAlertSeconds == settings.turnAlertSeconds &&
        game.timerMode == settings.timerMode &&
        game.timersEnabled == settings.timersEnabled &&
        game.tournament == settings.tournament &&
        game.chessBankSeconds == settings.chessBankSeconds &&
        game.chessBonusSeconds == settings.chessBonusSeconds;
    if (same) return;
    final bankChanged = game.chessBankSeconds != settings.chessBankSeconds;
    _commit('Réglages de partie', () {
      game.linkDamageToLife = true;
      game.resetManaOnTurn = settings.resetManaOnTurn;
      game.resetStormOnTurn = settings.resetStormOnTurn;
      game.commanderThreshold = settings.commanderThreshold.clamp(1, 99);
      game.poisonThreshold = poison;
      game.turnAlertSeconds = settings.turnAlertSeconds.clamp(0, 3600);
      game.timerMode = settings.timerMode;
      game.timersEnabled = settings.timersEnabled;
      game.tournament = settings.tournament;
      game.chessBankSeconds = settings.chessBankSeconds.clamp(60, 6 * 3600);
      game.chessBonusSeconds = settings.chessBonusSeconds.clamp(0, 60);
      if (settings.timersEnabled &&
          (bankChanged || settings.timerMode == TimerMode.chess)) {
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
    'clockPaused': clockPaused,
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
    if (json['clockPaused'] == true) controller.pauseClock();
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

  /// Remplace la partie par une session reçue d’un autre téléphone.
  void adoptSession(Map<String, dynamic> json) {
    applyingRemote = true;
    try {
      final fresh = GameController.restore(json, onChanged: onChanged);
      game = fresh.game;
      undoStack
        ..clear()
        ..addAll(fresh.undoStack);
      redoStack
        ..clear()
        ..addAll(fresh.redoStack);
      journal
        ..clear()
        ..addAll(fresh.journal);
      final known = {for (final event in lifeLog) event.id};
      String? story;
      for (final event in fresh.lifeLog) {
        if (event.id.isEmpty || known.contains(event.id)) continue;
        if (event.delta == 0) continue;
        story = event.story;
        break;
      }
      lifeLog
        ..clear()
        ..addAll(fresh.lifeLog);
      cmdDamageLog
        ..clear()
        ..addAll(fresh.cmdDamageLog);
      turnStarted = fresh.turnStarted;
      matchStarted = fresh.matchStarted;
      lastLabel = fresh.lastLabel;
      crownChange = null;
      combatAsk = null;
      if (story != null) {
        flashText = story;
        flashId++;
        lastLabel = story;
      }
      notifyListeners();
      onChanged?.call();
    } finally {
      applyingRemote = false;
    }
  }
}

class _CmdPlan {
  const _CmdPlan({
    required this.defender,
    required this.commanderId,
    required this.source,
    required this.takenBefore,
    required this.takenAfter,
    required this.lifeBefore,
    required this.lifeAfter,
    required this.lifeDelta,
    required this.remaining,
    required this.drainedNext,
  });

  final Player defender;
  final String commanderId;
  final String source;
  final int takenBefore;
  final int takenAfter;
  final int lifeBefore;
  final int lifeAfter;
  final int lifeDelta;
  final int remaining;
  final int drainedNext;
}
