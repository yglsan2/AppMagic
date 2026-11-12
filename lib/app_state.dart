import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:mtg_table/data/app_log.dart';
import 'package:mtg_table/data/repository.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/night_session.dart';
import 'package:mtg_table/net/table_link.dart';
import 'package:mtg_table/domain/player_profile.dart';
import 'package:mtg_table/domain/stats.dart';

class AppController extends ChangeNotifier {
  AppController(this.repo);

  final AppRepository repo;
  AppSettings settings = AppSettings.defaults;
  Playgroup? group;
  LocalLedger ledger = LocalLedger();
  List<PlayerProfile> profiles = [];
  NightSession? night;
  GameController? match;
  final tableLink = TableLinkController();
  String? resumeLabel;
  bool ready = false;
  bool awaitingFirstPlayer = false;
  Timer? _saveTimer;

  Future<void> boot() async {
    try {
      settings = await repo.loadSettings();
      group = await repo.loadGroup();
      ledger = await repo.loadLedger();
      profiles = await repo.loadProfiles();
      night = await repo.loadNight();
      final session = await repo.loadSession();
      if (session != null) {
        final preview = GameController.restore(session);
        final names = preview.game.players
            .map((player) => player.name)
            .join(', ');
        resumeLabel = 'Reprendre · manche ${preview.game.roundNumber} · $names';
        preview.dispose();
      }
    } on Object catch (error, stack) {
      AppLog.error('boot', error, stack);
      resumeLabel = null;
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _persistNight() async {
    await repo.saveNight(night);
  }

  Future<void> startNight({
    String? title,
    int podCount = 2,
    List<NightPlayer>? roster,
  }) async {
    night = NightSession.create(
      title: title,
      podCount: podCount,
      roster: roster,
    );
    // Préremplir le roster depuis les profils / le groupe.
    if (night!.roster.isEmpty) {
      if (group != null) {
        for (final p in group!.players) {
          night!.addPlayer(p.name, color: p.color);
        }
      }
      for (final profile in profiles.take(12)) {
        night!.addPlayer(profile.name, color: profile.color);
      }
    }
    notifyListeners();
    await _persistNight();
  }

  Future<void> updateNight(void Function(NightSession n) edit) async {
    final current = night;
    if (current == null) return;
    edit(current);
    notifyListeners();
    await _persistNight();
  }

  Future<bool> importNight(NightSession incoming) async {
    try {
      if (night == null) {
        night = incoming;
      } else if (night!.id == incoming.id || night!.code == incoming.code) {
        night!.mergeFrom(incoming);
      } else {
        // Nouvelle soirée importée : remplace si l’actuelle est vide.
        if (night!.games.isEmpty && night!.roster.isEmpty) {
          night = incoming;
        } else {
          night!.mergeFrom(incoming);
        }
      }
      notifyListeners();
      await _persistNight();
      return true;
    } on Object catch (error, stack) {
      AppLog.error('importNight', error, stack);
      return false;
    }
  }

  Future<void> endNight() async {
    final current = night;
    if (current == null) return;
    current.endNight();
    notifyListeners();
    await _persistNight();
  }

  Future<void> clearNight() async {
    night = null;
    notifyListeners();
    await _persistNight();
  }

  /// Met la partie courante en pause sur le pod actif, puis bascule.
  Future<void> switchPod(String podId) async {
    final n = night;
    if (n == null) return;
    final target = n.podById(podId);
    if (target == null) return;

    final current = match;
    final activeId = n.activePodId;
    if (current != null && activeId != null) {
      final active = n.podById(activeId);
      if (active != null) {
        active.session = current.exportSession();
        active.status = PodStatus.paused;
      }
      _saveTimer?.cancel();
      match = null;
      awaitingFirstPlayer = false;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        current.dispose();
      });
    }

    n.activePodId = podId;
    if (target.session != null) {
      final ok = await openSession(target.session!, drawFirst: false);
      if (ok) {
        target.status = PodStatus.playing;
        target.session = null;
      }
    } else {
      target.status = PodStatus.idle;
    }
    notifyListeners();
    await _persistNight();
  }

  /// Démarre une partie sur un pod (noms déjà assignés ou fournis).
  Future<void> startPodGame(Game game, {required String podId}) async {
    final n = night;
    if (n == null) return;
    final pod = n.podById(podId);
    if (pod == null) return;

    // Pause éventuelle de l’autre table.
    if (match != null && n.activePodId != null && n.activePodId != podId) {
      await switchPod(podId);
    }

    n.activePodId = podId;
    pod.status = PodStatus.playing;
    pod.session = null;
    pod.playerNames = [for (final p in game.players) p.name];
    await start(game);
    await _persistNight();
  }

  Future<void> upsertProfile(PlayerProfile profile) async {
    final index = profiles.indexWhere(
      (p) => p.name.toLowerCase() == profile.name.toLowerCase(),
    );
    if (index >= 0) {
      final existingId = profiles[index].id;
      profiles = [
        for (var i = 0; i < profiles.length; i++)
          if (i == index)
            PlayerProfile(
              id: existingId,
              name: profile.name,
              color: profile.color,
              commanders: profile.commanders,
              commanderArts: profile.commanderArts,
              panelArtUrl: profile.panelArtUrl,
            )
          else
            profiles[i],
      ];
    } else {
      profiles = [...profiles, profile];
    }
    if (profiles.length > 40) {
      profiles = profiles.sublist(profiles.length - 40);
    }
    notifyListeners();
    await repo.saveProfiles(profiles);
  }

  Future<void> deleteProfile(String id) async {
    profiles = [for (final p in profiles) if (p.id != id) p];
    notifyListeners();
    await repo.saveProfiles(profiles);
  }

  Future<void> start(Game game) async {
    _saveTimer?.cancel();
    final previous = match;
    match = GameController(game: game, onChanged: _scheduleSave);
    group = Playgroup.fromGame(game);
    resumeLabel = null;
    awaitingFirstPlayer = true;
    notifyListeners();
    SchedulerBinding.instance.addPostFrameCallback((_) => previous?.dispose());
    await repo.saveGroup(group!);
    await repo.saveSession(match!);
  }

  Future<void> resume() async {
    final session = await repo.loadSession();
    if (session == null) return;
    await openSession(session, drawFirst: false);
  }

  /// Ouvre une session importée / reprise. `false` = JSON invalide ou restore KO.
  Future<bool> openSession(
    Map<String, dynamic> session, {
    bool drawFirst = false,
  }) async {
    if (session['game'] is! Map) {
      AppLog.warn('openSession: champ game manquant');
      return false;
    }
    _saveTimer?.cancel();
    final previous = match;
    try {
      match = GameController.restore(session, onChanged: _scheduleSave);
      group = Playgroup.fromGame(match!.game);
      resumeLabel = null;
      awaitingFirstPlayer = drawFirst;
      notifyListeners();
      SchedulerBinding.instance.addPostFrameCallback((_) => previous?.dispose());
      await repo.saveGroup(group!);
      await repo.saveSession(match!);
      return true;
    } on Object catch (error, stack) {
      AppLog.error('openSession', error, stack);
      match = previous;
      notifyListeners();
      return false;
    }
  }

  void confirmFirstPlayer(int index) {
    final current = match;
    if (current == null) return;
    current.setActive(index);
    awaitingFirstPlayer = false;
    notifyListeners();
    _scheduleSave();
  }

  void skipFirstPlayerDraw() {
    awaitingFirstPlayer = false;
    notifyListeners();
  }

  void updateSettings(AppSettings next) {
    settings = next;
    match?.applyRules(next);
    notifyListeners();
    repo.saveSettings(next);
  }

  Future<void> applyGroup(Playgroup next) async {
    group = next;
    notifyListeners();
    await repo.saveGroup(next);
  }

  /// Enregistre la partie en cours si un vainqueur est clair.
  Future<bool> archiveCurrentGame({bool force = false}) async {
    final current = match;
    if (current == null) return false;
    final banner = current.game.victoryBanner();
    if (!force && banner == null) return false;
    final n = night;
    final archived = ArchivedGame.fromMatch(
      game: current.game,
      duration: current.matchElapsed,
      nightId: n?.id,
      podId: n?.activePodId,
    );
    ledger.add(archived);
    if (n != null && n.isOpen) {
      n.recordGame(archived, podId: n.activePodId);
      await _persistNight();
    }
    notifyListeners();
    await repo.saveLedger(ledger);
    return true;
  }

  Future<void> clearLedger() async {
    ledger = LocalLedger();
    notifyListeners();
    await repo.saveLedger(ledger);
  }

  /// Remise à zéro locale (RGPD) : prefs + état mémoire.
  Future<void> wipeAllLocalData() async {
    _saveTimer?.cancel();
    final previous = match;
    match = null;
    awaitingFirstPlayer = false;
    resumeLabel = null;
    night = null;
    group = null;
    profiles = [];
    ledger = LocalLedger();
    settings = AppSettings.defaults;
    await repo.clearAllLocalData();
    await repo.saveSettings(settings);
    notifyListeners();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      previous?.dispose();
    });
    AppLog.info('wipeAllLocalData terminé');
  }

  Future<void> park({bool archiveIfWon = true}) async {
    _saveTimer?.cancel();
    await tableLink.stop();
    final current = match;
    final n = night;
    if (current != null) {
      if (archiveIfWon) {
        await archiveCurrentGame();
      }
      // Si soirée active et partie non archivée gagnante : pause sur le pod.
      if (n != null && n.activePodId != null && match != null) {
        final pod = n.podById(n.activePodId!);
        if (pod != null && pod.status == PodStatus.playing) {
          // Si on vient d’archiver une win, recordGame a déjà idle le pod.
          if (current.game.victoryBanner() == null) {
            pod.session = current.exportSession();
            pod.status = PodStatus.paused;
            await _persistNight();
          }
        }
      }
      await repo.saveSession(current);
      final names = current.game.players
          .map((player) => player.name)
          .join(', ');
      resumeLabel = 'Reprendre · manche ${current.game.roundNumber} · $names';
      await repo.saveGroup(Playgroup.fromGame(current.game));
      group = Playgroup.fromGame(current.game);
    }
    match = null;
    awaitingFirstPlayer = false;
    notifyListeners();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      current?.dispose();
    });
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), () async {
      final current = match;
      if (current == null) return;
      await repo.saveSession(current);
      final n = night;
      if (n != null && n.activePodId != null) {
        final pod = n.podById(n.activePodId!);
        if (pod != null && pod.status == PodStatus.playing) {
          // Snapshot léger périodique pour reprise multi-tables.
          pod.session = current.exportSession();
          await _persistNight();
        }
      }
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    match?.dispose();
    super.dispose();
  }
}
