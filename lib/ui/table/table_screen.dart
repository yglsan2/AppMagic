import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/seating.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/setup/first_player_draw.dart';
import 'package:mtg_table/ui/sheets/card_journal_sheet.dart';
import 'package:mtg_table/ui/sheets/dice_sheet.dart';
import 'package:mtg_table/ui/sheets/history_sheet.dart';
import 'package:mtg_table/ui/sheets/life_log_sheet.dart';
import 'package:mtg_table/ui/sheets/players_sheet.dart';
import 'package:mtg_table/ui/sheets/restart_sheet.dart';
import 'package:mtg_table/ui/sheets/settings_sheet.dart';
import 'package:mtg_table/ui/sheets/recap_sheet.dart';
import 'package:mtg_table/ui/sheets/transfer_sheet.dart';
import 'package:mtg_table/ui/tools/card_search_screen.dart';
import 'package:mtg_table/ui/widgets/name_dialog.dart';
import 'package:mtg_table/ui/widgets/help_tip.dart';
import 'package:mtg_table/ui/widgets/player_panel.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({
    super.key,
    required this.controller,
    required this.settings,
    required this.onSettings,
    required this.onLeave,
    required this.onCoachDismissed,
    this.onArchiveWin,
  });

  final GameController controller;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettings;
  final VoidCallback onLeave;
  // Conservé : le bandeau global a été retiré, le tour s’affiche sur le siège.
  // ignore: unused_field
  final VoidCallback onCoachDismissed;
  final Future<bool> Function()? onArchiveWin;

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  Timer? _toastTimer;
  String? _toast;
  int _seenFlash = 0;

  /// Siège affiché en mode Focus (indépendant du tour actif).
  String? _focusPlayerId;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onGame);
  }

  @override
  void didUpdateWidget(TableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onGame);
      widget.controller.addListener(_onGame);
    }
  }

  void _onGame() {
    if (!mounted) return;
    final id = widget.controller.flashId;
    if (id != _seenFlash) {
      _seenFlash = id;
      _toast = widget.controller.flashText;
      _toastTimer?.cancel();
      _toastTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _toast = null);
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    widget.controller.removeListener(_onGame);
    super.dispose();
  }

  Future<void> _leave() async {
    final ok = await confirmAction(
      context,
      title: 'Retour au salon',
      message: 'La partie reste enregistrée sur cet appareil.',
      confirmLabel: 'Quitter la table',
    );
    if (!ok || !mounted) return;
    widget.onLeave();
  }

  Future<void> _restart({RestartKind initial = RestartKind.rematch}) async {
    if (initial == RestartKind.rematch) {
      await widget.onArchiveWin?.call();
    }
    if (!mounted) return;
    await showRestartSheet(
      context,
      controller: widget.controller,
      initial: initial,
    );
  }

  Future<void> _redrawFirst() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => FirstPlayerDraw(
          players: widget.controller.game.players,
          onPicked: (index) {
            widget.controller.setActive(index);
            Navigator.of(context).pop();
          },
          onSkip: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _about() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('LifeStack'),
        content: const SingleChildScrollView(
          child: Text(
            'Compteur de partie pour Magic. Les dégâts de chaque commandant '
            'se comptent d’un geste, partenaires compris.\n\n'
            'Le journal de cartes, en option, passe par Scryfall et reste '
            'sur l’appareil : il propose les effets simples, et attend une '
            'confirmation avant de toucher aux points de vie. Ce n’est pas '
            'un moteur de règles complet.\n\n'
            'LifeStack est un projet de fan, non officiel. Il suit la '
            'politique Fan Content de Wizards of the Coast. Wizards of the '
            'Coast ne l’approuve pas et ne le sponsorise pas. Les noms de '
            'cartes et les règles restent la propriété de Wizards of the Coast LLC.\n\n'
            'Recherche de cartes : Scryfall.\n\n'
            'Vie privée : avant la partie, Outils, puis Vie privée. '
            'Les données restent sur l’appareil, et on peut les effacer.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.controller.game;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: pageGradient),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _Bar(
                      controller: widget.controller,
                      canUndo: widget.controller.canUndo,
                      canRedo: widget.controller.canRedo,
                      onLeave: _leave,
                      onUndo: widget.controller.undo,
                      onRedo: widget.controller.redo,
                      onDice: () => showDiceSheet(context, widget.controller),
                      onHistory: () =>
                          showHistorySheet(context, widget.controller),
                      onMenu: (action) {
                        switch (action) {
                          case _Menu.players:
                            showPlayersSheet(context, widget.controller);
                          case _Menu.first:
                            _redrawFirst();
                          case _Menu.cardJournal:
                            showCardJournalSheet(context, widget.controller);
                          case _Menu.history:
                            showHistorySheet(context, widget.controller);
                          case _Menu.dayNight:
                            final next = switch (game.dayState) {
                              DayState.unset || DayState.night => DayState.day,
                              DayState.day => DayState.night,
                            };
                            widget.controller.setDay(next);
                          case _Menu.tips:
                            final tipsOn = !widget.settings.beginnerTips;
                            widget.onSettings(
                              widget.settings.copyWith(beginnerTips: tipsOn),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  tipsOn
                                      ? 'Bulles d’aide activées — appui long '
                                            'sur Monarque, poison…'
                                      : 'Bulles d’aide désactivées',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          case _Menu.transfer:
                            showExportTransferSheet(context, widget.controller);
                          case _Menu.search:
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const CardSearchScreen(),
                              ),
                            );
                          case _Menu.settings:
                            showSettingsSheet(
                              context,
                              settings: widget.settings,
                              onChanged: widget.onSettings,
                            );
                          case _Menu.rotate:
                            widget.controller.rotateSeats();
                          case _Menu.shuffle:
                            widget.controller.shuffleSeats();
                          case _Menu.treacheryDeal:
                            widget.controller.dealTreacheryRoles();
                          case _Menu.rematch:
                            _restart(initial: RestartKind.rematch);
                          case _Menu.reset:
                            _restart(initial: RestartKind.zero);
                          case _Menu.recap:
                            showGameRecapSheet(context, widget.controller);
                          case _Menu.about:
                            _about();
                        }
                      },
                      showCardJournal: widget.settings.cardJournalAssist,
                      showTreachery: game.format == MatchFormat.treachery,
                      beginnerTips: widget.settings.beginnerTips,
                    ),
                    if (game.victoryBanner() != null)
                      _VictoryBanner(
                        text: game.victoryBanner()!,
                        onRematch: () => _restart(initial: RestartKind.rematch),
                        onZero: () => _restart(initial: RestartKind.zero),
                        onRecap: () =>
                            showGameRecapSheet(context, widget.controller),
                      ),
                    if (widget.settings.showLifeFeed &&
                        widget.controller.lifeLog.isNotEmpty)
                      _LifeFeedStrip(controller: widget.controller),
                    if (game.timersEnabled)
                      _TurnTimerBar(controller: widget.controller),
                    _TableExtras(controller: widget.controller),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final fourSides = useFourSides(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            players: game.players.length,
                          );
                          final plan = planFor(
                            players: game.players.length,
                            fourSides: fourSides,
                          ).oriented(game.seatShift, game.players.length);
                          final list = preferList(
                            mode: widget.settings.viewMode,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            plan: plan,
                          );
                          if (list) {
                            final focusMode =
                                widget.settings.viewMode == ViewMode.focus;
                            final focusId =
                                _focusPlayerId ??
                                game.players[game.activeIndex].id;
                            return _ListTable(
                              controller: widget.controller,
                              haptic: widget.settings.haptic,
                              showTips: widget.settings.beginnerTips,
                              height: constraints.maxHeight,
                              focusMode: focusMode,
                              focusPlayerId: focusId,
                              onFocusPlayer: focusMode
                                  ? (id) => setState(() => _focusPlayerId = id)
                                  : null,
                            );
                          }
                          if (plan.fourSides) {
                            return _FourSides(
                              plan: plan,
                              controller: widget.controller,
                              haptic: widget.settings.haptic,
                              showTips: widget.settings.beginnerTips,
                            );
                          }
                          return _TwoSides(
                            plan: plan,
                            controller: widget.controller,
                            haptic: widget.settings.haptic,
                            showTips: widget.settings.beginnerTips,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (_toast != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 64,
                    child: Material(
                      elevation: 8,
                      color: accent,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _toast!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Menu {
  players,
  first,
  cardJournal,
  history,
  dayNight,
  tips,
  transfer,
  search,
  settings,
  rotate,
  shuffle,
  treacheryDeal,
  recap,
  rematch,
  reset,
  about,
}

class _LifeFeedStrip extends StatelessWidget {
  const _LifeFeedStrip({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final log = controller.lifeLog;
    if (log.isEmpty) return const SizedBox.shrink();
    final latest = log.first;
    final preview = log
        .take(3)
        .map((e) {
          if (e.delta == 0) return e.line;
          return '${e.playerName} ${e.deltaLabel}';
        })
        .join(' · ');
    final extra = log.length > 3 ? log.length - 3 : 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Material(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showLifeLogSheet(context, controller),
          child: Semantics(
            button: true,
            label: 'Voir tous les décomptes de points de vie',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      extra > 0
                          ? '$preview · +$extra'
                          : '$preview · ${latest.from}→${latest.to}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  Text(
                    'Tout',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.controller,
    required this.canUndo,
    required this.canRedo,
    required this.onLeave,
    required this.onUndo,
    required this.onRedo,
    required this.onDice,
    required this.onHistory,
    required this.onMenu,
    this.showCardJournal = true,
    this.showTreachery = false,
    this.beginnerTips = true,
  });

  final GameController controller;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onLeave;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onDice;
  final VoidCallback onHistory;
  final ValueChanged<_Menu> onMenu;
  final bool showCardJournal;
  final bool showTreachery;
  final bool beginnerTips;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          _BarIcon(
            icon: Icons.arrow_back,
            tooltip: 'Salon',
            onPressed: onLeave,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manche ${game.roundNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (game.timersEnabled) _LiveClocks(controller: controller),
              ],
            ),
          ),
          _BarIcon(
            icon: Icons.undo,
            tooltip: 'Annuler',
            onPressed: canUndo ? onUndo : null,
            emphasize: true,
          ),
          _BarIcon(
            icon: Icons.redo,
            tooltip: 'Rétablir',
            onPressed: canRedo ? onRedo : null,
          ),
          _BarIcon(
            icon: Icons.history,
            tooltip: 'Historique',
            onPressed: onHistory,
          ),
          _BarIcon(icon: Icons.casino, tooltip: 'Dés', onPressed: onDice),
          PopupMenuButton<_Menu>(
            tooltip: 'Menu',
            padding: EdgeInsets.zero,
            onSelected: onMenu,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _Menu.players,
                child: Text('Joueurs / places'),
              ),
              const PopupMenuItem(
                value: _Menu.first,
                child: Text('Tirage : qui commence'),
              ),
              if (showCardJournal)
                const PopupMenuItem(
                  value: _Menu.cardJournal,
                  child: Text('Noter une carte'),
                ),
              const PopupMenuItem(
                value: _Menu.dayNight,
                child: Text('Jour / nuit'),
              ),
              PopupMenuItem(
                value: _Menu.tips,
                child: Text(
                  beginnerTips
                      ? 'Désactiver les bulles d’aide'
                      : 'Activer les bulles d’aide',
                ),
              ),
              const PopupMenuItem(
                value: _Menu.history,
                child: Text('Historique & journal'),
              ),
              const PopupMenuItem(
                value: _Menu.transfer,
                child: Text('Transférer (QR)'),
              ),
              const PopupMenuItem(
                value: _Menu.search,
                child: Text('Recherche de carte'),
              ),
              const PopupMenuItem(
                value: _Menu.settings,
                child: Text('Réglages'),
              ),
              const PopupMenuItem(
                value: _Menu.rotate,
                child: Text('Tourner les places'),
              ),
              const PopupMenuItem(
                value: _Menu.shuffle,
                child: Text('Mélanger les places'),
              ),
              if (showTreachery)
                const PopupMenuItem(
                  value: _Menu.treacheryDeal,
                  child: Text('Distribuer rôles Traîtrise'),
                ),
              const PopupMenuItem(
                value: _Menu.recap,
                child: Text('Récap partageable'),
              ),
              const PopupMenuItem(
                value: _Menu.rematch,
                child: Text('Revanche'),
              ),
              const PopupMenuItem(
                value: _Menu.reset,
                child: Text('Remise à zéro'),
              ),
              const PopupMenuItem(value: _Menu.about, child: Text('À propos')),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatClock(Duration d) {
  final total = d.inSeconds.clamp(0, 99 * 3600);
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  if (total >= 3600) {
    final h = total ~/ 3600;
    final mm = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    return '$h:$mm:$s';
  }
  return '$m:$s';
}

class _LiveClocks extends StatefulWidget {
  const _LiveClocks({required this.controller});

  final GameController controller;

  @override
  State<_LiveClocks> createState() => _LiveClocksState();
}

class _LiveClocksState extends State<_LiveClocks> {
  Timer? _tick;
  bool _alerted = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final over = widget.controller.turnOverAlert;
      if (over && !_alerted) {
        _alerted = true;
        final chess = widget.controller.game.timerMode == TimerMode.chess;
        widget.controller.flash(
          chess
              ? 'Banque épuisée — passez la main ?'
              : 'Tour trop long — passez ?',
        );
      }
      if (!over) _alerted = false;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.controller.game;
    final over = widget.controller.turnOverAlert;
    final turn = _formatClock(widget.controller.turnElapsed);
    final match = _formatClock(widget.controller.matchElapsed);
    final limit = game.turnAlertSeconds;
    final active = game.players[game.activeIndex];
    final chess = game.timerMode == TimerMode.chess;
    final bank = widget.controller.activeBankRemaining;
    final label = chess
        ? '${active.name} ${_formatClock(bank)} · tour $turn · $match'
        : over
        ? 'Tour $turn · alerte ${limit}s · partie $match'
        : 'Tour $turn · partie $match';
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: (over || (chess && bank.inSeconds < 60))
            ? loss
            : Colors.white.withValues(alpha: 0.55),
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.emphasize = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints(
        minWidth: emphasize ? 44 : 36,
        minHeight: emphasize ? 44 : 36,
      ),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: emphasize ? 28 : 22,
        color: emphasize && enabled ? accentGold : null,
      ),
    );
  }
}

class _VictoryBanner extends StatelessWidget {
  const _VictoryBanner({
    required this.text,
    required this.onRematch,
    required this.onZero,
    required this.onRecap,
  });

  final String text;
  final VoidCallback onRematch;
  final VoidCallback onZero;
  final VoidCallback onRecap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(color: accent.withValues(alpha: 0.45)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRecap,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Récap'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onRematch,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Revanche'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onZero,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('À zéro'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TurnTimerBar extends StatefulWidget {
  const _TurnTimerBar({required this.controller});

  final GameController controller;

  @override
  State<_TurnTimerBar> createState() => _TurnTimerBarState();
}

class _TurnTimerBarState extends State<_TurnTimerBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.controller.game;
    if (game.timerMode == TimerMode.chess) {
      final bankSec = widget.controller.activeBankRemaining.inSeconds;
      final total = game.chessBankSeconds.clamp(1, 6 * 3600);
      final remaining = (bankSec / total).clamp(0.0, 1.0);
      final low = bankSec < 60;
      final empty = widget.controller.turnOverAlert;
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: remaining,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: empty || low
                    ? dangerCrit
                    : (remaining < 0.25 ? dangerWarn : accent),
              ),
            ),
            if (empty)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  'Banque épuisée — passez la main ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: dangerCrit,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    final limit = game.turnAlertSeconds;
    if (limit <= 0) return const SizedBox.shrink();
    final elapsed = widget.controller.turnElapsed.inSeconds.clamp(0, limit * 2);
    final progress = (elapsed / limit).clamp(0.0, 1.0);
    final over = widget.controller.turnOverAlert;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: over
                  ? dangerCrit
                  : (progress > 0.75 ? dangerWarn : accent),
            ),
          ),
          if (over)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Tour dépassé — passez la main ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: dangerCrit,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _ExtraKind { plane, scheme, bounty }

/// Plans / schémas / primes : chips repliables pour garder le pad de vie grand.
class _TableExtras extends StatefulWidget {
  const _TableExtras({required this.controller});

  final GameController controller;

  @override
  State<_TableExtras> createState() => _TableExtrasState();
}

class _TableExtrasState extends State<_TableExtras> {
  _ExtraKind? _open;

  void _toggle(_ExtraKind kind) {
    setState(() => _open = _open == kind ? null : kind);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.controller.game;
    final hasPlane = game.planechase;
    final hasScheme = game.archenemy;
    final hasBounty = game.bounty;
    if (!hasPlane && !hasScheme && !hasBounty) {
      return const SizedBox.shrink();
    }

    // Si le mode actif disparaît, refermer le panneau.
    final open = _open;
    final effectiveOpen = switch (open) {
      _ExtraKind.plane when !hasPlane => null,
      _ExtraKind.scheme when !hasScheme => null,
      _ExtraKind.bounty when !hasBounty => null,
      _ => open,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (hasPlane)
                  _ExtraChip(
                    selected: effectiveOpen == _ExtraKind.plane,
                    icon: Icons.public,
                    color: const Color(0xFF7EB6FF),
                    label: game.currentPlane,
                    onTap: () => _toggle(_ExtraKind.plane),
                  ),
                if (hasScheme) ...[
                  if (hasPlane) const SizedBox(width: 6),
                  _ExtraChip(
                    selected: effectiveOpen == _ExtraKind.scheme,
                    icon: Icons.whatshot,
                    color: const Color(0xFFFF7A6E),
                    label: game.currentScheme,
                    onTap: () => _toggle(_ExtraKind.scheme),
                  ),
                ],
                if (hasBounty) ...[
                  if (hasPlane || hasScheme) const SizedBox(width: 6),
                  _ExtraChip(
                    selected: effectiveOpen == _ExtraKind.bounty,
                    icon: Icons.military_tech,
                    color: accentGold,
                    label: 'Prime ${game.bountyLevel + 1}',
                    onTap: () => _toggle(_ExtraKind.bounty),
                  ),
                ],
              ],
            ),
          ),
          if (effectiveOpen != null) ...[
            const SizedBox(height: 4),
            switch (effectiveOpen) {
              _ExtraKind.plane => _PlanePanel(controller: widget.controller),
              _ExtraKind.scheme => _SchemePanel(controller: widget.controller),
              _ExtraKind.bounty => _BountyPanel(controller: widget.controller),
            },
          ],
        ],
      ),
    );
  }
}

class _ExtraChip extends StatelessWidget {
  const _ExtraChip({
    required this.selected,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? color.withValues(alpha: 0.28)
          : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                selected ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanePanel extends StatelessWidget {
  const _PlanePanel({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    return Material(
      color: const Color(0xFF1A2434),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(game.currentPlane),
                      content: Text(game.currentPlaneChaos),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.currentPlane,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      game.currentPlaneChaos,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: controller.planeswalk,
              child: const Text('Marcher'),
            ),
            TextButton(
              onPressed: () => controller.flash(game.currentPlaneChaos),
              child: const Text('Chaos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchemePanel extends StatelessWidget {
  const _SchemePanel({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final villain = game.archenemyId == null
        ? 'Archennemi'
        : game.playerById(game.archenemyId!).name;
    return Material(
      color: const Color(0xFF2A1A22),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(game.currentScheme),
                      content: Text('$villain\n\n${game.currentSchemeEffect}'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$villain · ${game.currentScheme}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      game.currentSchemeEffect,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: controller.nextScheme,
              child: const Text('Suivant'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BountyPanel extends StatelessWidget {
  const _BountyPanel({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final card = game.currentBounty;
    return Material(
      color: const Color(0xFF2A2418),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prime Nv.${game.bountyLevel + 1} · ${card.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    card.reward,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: controller.raiseBounty,
              child: const Text('↑ Niveau'),
            ),
            TextButton(
              onPressed: () {
                final active = game.players[game.activeIndex];
                controller.claimBounty(active.id);
              },
              child: const Text('Réclamer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListTable extends StatelessWidget {
  const _ListTable({
    required this.controller,
    required this.haptic,
    required this.showTips,
    required this.height,
    this.focusMode = false,
    this.focusPlayerId,
    this.onFocusPlayer,
  });

  final GameController controller;
  final bool haptic;
  final bool showTips;
  final double height;
  final bool focusMode;
  final String? focusPlayerId;
  final ValueChanged<String>? onFocusPlayer;

  @override
  Widget build(BuildContext context) {
    final players = controller.game.players;
    if (focusMode && players.isNotEmpty) {
      final focusId = focusPlayerId ?? players[controller.game.activeIndex].id;
      final focused = players.firstWhere(
        (p) => p.id == focusId,
        orElse: () => players[controller.game.activeIndex],
      );
      return Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: players.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final player = players[index];
                final selected = player.id == focused.id;
                final isTurn = index == controller.game.activeIndex;
                return ActionChip(
                  avatar: CircleAvatar(
                    backgroundColor: playerColor(player.color),
                    radius: 10,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  label: Text(
                    '${player.name} · ${player.life}${isTurn ? ' · tour' : ''}',
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                  onPressed: () => onFocusPlayer?.call(player.id),
                );
              },
            ),
          ),
          Expanded(child: _seat(focused.id)),
        ],
      );
    }
    final each = (height / players.length).clamp(280.0, 520.0);
    if (players.length <= 2 && each * players.length <= height + 1) {
      return Column(
        children: [
          for (final player in players) Expanded(child: _seat(player.id)),
        ],
      );
    }
    return ListView.builder(
      itemCount: players.length,
      itemBuilder: (context, index) {
        return SizedBox(height: each, child: _seat(players[index].id));
      },
    );
  }

  Widget _seat(String id) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: PlayerPanel(
        controller: controller,
        playerId: id,
        haptic: haptic,
        showTips: showTips,
      ),
    );
  }
}

class _TwoSides extends StatelessWidget {
  const _TwoSides({
    required this.plan,
    required this.controller,
    required this.haptic,
    required this.showTips,
  });

  final SeatingPlan plan;
  final GameController controller;
  final bool haptic;
  final bool showTips;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (plan.north.isNotEmpty)
          Expanded(
            child: Row(
              children: [
                for (final index in plan.north)
                  Expanded(child: _turned(index, 2)),
              ],
            ),
          ),
        if (plan.south.isNotEmpty)
          Expanded(
            child: Row(
              children: [
                for (final index in plan.south)
                  Expanded(child: _turned(index, 0)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _turned(int index, int turns) {
    final players = controller.game.players;
    final face = facingSeatIndex(plan, index);
    return _RotatedSeat(
      quarterTurns: turns,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: PlayerPanel(
          controller: controller,
          playerId: players[index].id,
          haptic: haptic,
          lifeTargetId: face == null ? null : players[face].id,
          showTips: showTips,
        ),
      ),
    );
  }
}

class _FourSides extends StatelessWidget {
  const _FourSides({
    required this.plan,
    required this.controller,
    required this.haptic,
    required this.showTips,
  });

  final SeatingPlan plan;
  final GameController controller;
  final bool haptic;
  final bool showTips;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Row(
            children: [
              for (final index in plan.north) Expanded(child: _seat(index, 2)),
            ],
          ),
        ),
        Expanded(
          flex: 6,
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    for (final index in plan.westTopToBottom)
                      Expanded(child: _seat(index, 1)),
                  ],
                ),
              ),
              const Expanded(
                flex: 3,
                child: Center(
                  child: Text(
                    'Sens horaire',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    for (final index in plan.eastTopToBottom)
                      Expanded(child: _seat(index, 3)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: Row(
            children: [
              for (final index in plan.south) Expanded(child: _seat(index, 0)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seat(int index, int turns) {
    final players = controller.game.players;
    final face = facingSeatIndex(plan, index);
    return _RotatedSeat(
      quarterTurns: turns,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: PlayerPanel(
          controller: controller,
          playerId: players[index].id,
          haptic: haptic,
          lifeTargetId: face == null ? null : players[face].id,
          showTips: showTips,
        ),
      ),
    );
  }
}

class _RotatedSeat extends StatelessWidget {
  const _RotatedSeat({required this.quarterTurns, required this.child});

  final int quarterTurns;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final turns = quarterTurns % 4;
    final body = turns == 0
        ? child
        : RotatedBox(quarterTurns: turns, child: child);
    return SeatReading(quarterTurns: turns, child: body);
  }
}
