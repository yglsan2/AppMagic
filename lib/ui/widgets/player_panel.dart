import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mtg_table/data/safe_image.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/handicap.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/sheets/amount_sheet.dart';
import 'package:mtg_table/ui/sheets/counters_sheet.dart';
import 'package:mtg_table/ui/sheets/life_log_sheet.dart';
import 'package:mtg_table/ui/sheets/player_sheet.dart';
import 'package:mtg_table/ui/widgets/danger_life.dart';
import 'package:mtg_table/ui/help/option_help.dart';
import 'package:mtg_table/ui/widgets/help_tip.dart';
import 'package:mtg_table/ui/widgets/repeat_tap.dart';

/// Fin de tour. Si le joueur actif est monarque, on lui demande d’abord
/// s’il a pioché la carte de son étape de fin.
Future<void> endPlayerTurn(
  BuildContext context,
  GameController controller,
) async {
  final game = controller.game;
  if (game.players.isEmpty) return;
  final active = game.players[game.activeIndex];
  if (game.monarchId == active.id) {
    final drew = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Étape de fin'),
        content: Text(
          '${active.name}, vous êtes monarque. Au début de cette étape, '
          'vous piochiez une carte. C’est fait ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Pas encore'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Oui, carte piochée'),
          ),
        ],
      ),
    );
    if (drew != true) return;
  }
  controller.nextTurn();
}

/// Affichage choisi pour chaque siège de la partie en cours.
class SeatPanes extends InheritedWidget {
  const SeatPanes({
    required this.byId,
    required this.onChoose,
    required this.onSave,
    required super.child,
  });

  final Map<String, ScorePane> byId;
  final void Function(String playerId, ScorePane pane) onChoose;
  final void Function(String playerId) onSave;

  static ScorePane paneOf(BuildContext context, String playerId) {
    final scope = context.dependOnInheritedWidgetOfExactType<SeatPanes>();
    return scope?.byId[playerId] ?? ScorePane.foes;
  }

  static SeatPanes? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SeatPanes>();

  @override
  bool updateShouldNotify(SeatPanes oldWidget) {
    if (oldWidget.byId.length != byId.length) return true;
    for (final entry in byId.entries) {
      if (oldWidget.byId[entry.key] != entry.value) return true;
    }
    return false;
  }
}

/// + et +5 partagent une famille. Le saut est plus sombre, comme − et −5.
/// La couleur du joueur reste sur son badge.
const _gainStep = Color(0xFF157A52);
const _gainJump = Color(0xFF0E5A38);
const _gainInk = Color(0xFFE8FFF2);

class PlayerPanel extends StatelessWidget {
  const PlayerPanel({
    super.key,
    required this.controller,
    required this.playerId,
    required this.haptic,

    /// Sur table à deux : le pad retire les PV de l’adversaire en face.
    /// Les PV de [playerId] restent les siens, affichés en grand.
    this.lifeTargetId,
    this.showTips = true,

    /// Partie à 3 ou 4 : bandeau horizontal, sans pastilles, avec ciblage.
    this.band = false,
  });

  final GameController controller;
  final String playerId;
  final bool haptic;
  final String? lifeTargetId;
  final bool showTips;
  final bool band;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final player = game.playerById(playerId);
    final targetId = lifeTargetId ?? playerId;
    final target = game.playerById(targetId);
    final color = playerColor(player.color);
    final targetColor = playerColor(target.color);
    final active = game.players[game.activeIndex].id == player.id;
    final defeated = game.isDefeated(player);
    final reason = game.lethalBanner(player);
    final startLife = player.startingLifeFor(game);
    final targetStart = target.startingLifeFor(game);
    final threat = lifeBand(life: player.life, startingLife: startLife);
    final multi = band;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 360.0;
        // Cdt toujours visible si le format le suit (sinon le zoom « disparaît »).
        final pane = SeatPanes.paneOf(context, playerId);
        final showCmd = game.trackCommanderDamage && !multi;
        final opponentPad = !multi && target.id != player.id;
        // Poison, monarque et taxe seulement s’il reste de la place pour le pad.
        final showQuick = !multi && height >= 340;
        final showFive = height >= 210;
        final ownSize = height < 360 ? 48.0 : 60.0;
        final opponentSize = height < 360 ? 34.0 : 44.0;
        final artUrl = player.displayArtUrl;
        return SizedBox(
          width: width,
          height: height,
          child: ThreatPanelShell(
            band: threat,
            playerTint: color,
            active: active,
            defeated: defeated,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (artUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Opacity(
                      opacity: 0.22,
                      child: SafeNetworkImage(url: artUrl, fit: BoxFit.cover),
                    ),
                  ),
                multi
                    ? _BandSeat(
                        controller: controller,
                        player: player,
                        color: color,
                        active: active,
                        haptic: haptic,
                        startLife: startLife,
                        showTips: showTips,
                      )
                    : Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    children: [
                      _TopBar(
                        controller: controller,
                        player: player,
                        color: color,
                        active: active,
                        band: threat,
                        showTips: showTips,
                      ),
                      if (opponentPad && pane == ScorePane.foes)
                        _OwnLifeRow(
                          controller: controller,
                          player: player,
                          haptic: haptic,
                          startLife: startLife,
                          fontSize: ownSize,
                        ),
                      if (pane != ScorePane.foes)
                        pane == ScorePane.own
                            ? Expanded(
                                child: _OwnLosses(
                                  controller: controller,
                                  player: player,
                                  color: color,
                                  haptic: haptic,
                                  startLife: startLife,
                                  showTips: showTips,
                                  expand: true,
                                  active: active,
                                ),
                              )
                            : _OwnLosses(
                                controller: controller,
                                player: player,
                                color: color,
                                haptic: haptic,
                                startLife: startLife,
                                showTips: showTips,
                                expand: false,
                              ),
                      _SeatOptions(
                        controller: controller,
                        player: player,
                        color: color,
                        haptic: haptic,
                        showTips: showTips,
                        full: pane != ScorePane.foes || showQuick,
                      ),
                      if (pane != ScorePane.own)
                      Expanded(
                        child: _LifePad(
                          controller: controller,
                          seatPlayer: player,
                          target: target,
                          color: targetColor,
                          haptic: haptic,
                          compact: height < 260 || opponentPad,
                          showFive: showFive,
                          startingLife: targetStart,
                          seatActive: active,
                          numberSize: opponentPad ? opponentSize : null,
                          showTips: showTips,
                        ),
                      ),
                      if (opponentPad && pane == ScorePane.foes)
                        _ReceivedCommanders(
                          controller: controller,
                          player: player,
                        ),
                      if (showCmd && pane != ScorePane.own)
                        _CommanderStrip(
                          controller: controller,
                          attacker: player,
                          defender: target,
                          haptic: haptic,
                          panelWidth: width - 20,
                          compact: height < 340 || opponentPad,
                        ),
                    ],
                  ),
                ),
                if (showTips) _CrownMood(controller: controller, playerId: player.id),
                if (defeated)
                  Positioned.fill(
                    child: _DefeatOverlay(
                      title: game.defeatTitle(player),
                      reason: reason ?? 'Hors jeu',
                      onRevive: () => controller.revivePlayer(player.id),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tête triste ou sourire, quelques secondes, seulement avec l’aide débutant.
class _CrownMood extends StatelessWidget {
  const _CrownMood({required this.controller, required this.playerId});

  final GameController controller;
  final String playerId;

  @override
  Widget build(BuildContext context) {
    final shift = controller.crownChange;
    final at = controller.crownAt;
    if (shift == null || at == null) return const SizedBox.shrink();
    if (DateTime.now().difference(at) >= const Duration(seconds: 5)) {
      return const SizedBox.shrink();
    }
    final lost = shift.lostId == playerId;
    final gained = shift.gainedId == playerId;
    if (!lost && !gained) return const SizedBox.shrink();
    final icon = gained
        ? Icons.sentiment_very_satisfied
        : Icons.sentiment_dissatisfied;
    final color = gained ? const Color(0xFFE8FFF2) : const Color(0xFFFFE4E8);
    final fill = gained ? const Color(0xFF157A52) : const Color(0xFF5C2432);
    return Positioned(
      top: 8,
      right: 8,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.player,
    required this.color,
    required this.active,
    required this.band,
    required this.showTips,
  });

  final GameController controller;
  final Player player;
  final Color color;
  final bool active;
  final LifeBand band;
  final bool showTips;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: active ? color : color.withValues(alpha: 0.45),
                child: Text(
                  playerInitial(player.name),
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: active ? 1 : 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () => showPlayerSheet(
                  context,
                  controller,
                  player.id,
                  tips: showTips,
                ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            height: 1.1,
                            color: active
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.38),
                            shadows: active
                                ? [
                                    Shadow(
                                      color: color.withValues(alpha: 0.85),
                                      blurRadius: 12,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                      if (player.treacheryRevealed) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.masks_outlined,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                      if (band != LifeBand.safe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          band == LifeBand.critical
                              ? Icons.warning_amber_rounded
                              : Icons.priority_high_rounded,
                          size: 15,
                          color: lifeBandColor(band),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (game.handicapsEnabled && player.handicapDelta(true) != 0)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: player.deckBracket.detailFor(
                      player.handicapLifeDelta,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        formatLifeDelta(player.handicapLifeDelta),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              _PaneButton(
                player: player,
                size: 44,
                showTips: showTips,
              ),
              HelpTip(
                enabled: showTips,
                longPress: false,
                title: tipGear.title,
                message: tipGear.message,
                child: _CmdIconButton(
                  tooltip: 'Options',
                  background: Colors.white.withValues(alpha: 0.08),
                  foreground: Colors.white,
                  icon: Icons.settings,
                  onPressed: () => showCountersSheet(
                    context,
                    controller,
                    player.id,
                    tips: showTips,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaneButton extends StatelessWidget {
  const _PaneButton({
    required this.player,
    required this.size,
    required this.showTips,
  });

  final Player player;
  final double size;
  final bool showTips;

  @override
  Widget build(BuildContext context) {
    final scope = SeatPanes.maybeOf(context);
    final pane = scope?.byId[player.id] ?? ScorePane.foes;
    String mark(ScorePane value) {
      final label = scorePaneLabel(value);
      return pane == value ? '$label  · actuel' : label;
    }

    return HelpTip(
      enabled: showTips,
      longPress: false,
      title: tipPane.title,
      message: tipPane.message,
      child: PopupMenuButton<int>(
      tooltip: 'Affichage des points',
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (scope == null) return;
        if (value == 3) {
          scope.onSave(player.id);
        } else {
          scope.onChoose(player.id, ScorePane.values[value]);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 0, child: Text(mark(ScorePane.own))),
        PopupMenuItem(value: 1, child: Text(mark(ScorePane.both))),
        PopupMenuItem(value: 2, child: Text(mark(ScorePane.foes))),
        PopupMenuItem(
          value: 3,
          child: Text('Enregistrer pour ${player.name}'),
        ),
      ],
      child: SizedBox(
        key: ValueKey('pane-${player.id}'),
        width: size,
        height: size,
        child: Icon(
          Icons.visibility,
          size: size < 36 ? 18 : 22,
          color: pane == ScorePane.foes ? Colors.white70 : accent,
        ),
      ),
    ),
    );
  }
}

class _CmdIconButton extends StatelessWidget {
  const _CmdIconButton({
    required this.tooltip,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final Color background;
  final Color foreground;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 22, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

bool _coreOptions(Game game, Player player, {required bool full}) {
  if (full || player.poison != 0 || game.monarchId == player.id) return true;
  if (game.initiativeId == player.id || player.blessing) return true;
  return game.trackCommanderTax &&
      player.commanders.any((commander) => full || commander.tax > 0);
}

int _parameterCount(Game game, Player player) {
  var count = player.custom.length + (player.ring != 0 ? 1 : 0);
  for (final stat in Stat.values) {
    if (stat == Stat.poison) continue;
    if (stat == Stat.signature && game.format != MatchFormat.oathbreaker) {
      continue;
    }
    if (player.readStat(stat) != 0) count++;
  }
  for (final key in manaKeys) {
    if ((player.mana[key] ?? 0) != 0) count++;
  }
  return count;
}

/// Hauteur réservée aux options. 0 si rien n’est à montrer.
/// [full] : poison, monarque et taxe restent affichés même à zéro.
double seatOptionsExtent(Game game, Player player, {required bool full}) {
  final core = _coreOptions(game, player, full: full) ? 56.0 : 0.0;
  return core + _parameterCount(game, player) * 56.0;
}

/// Compteurs ouverts depuis la roue crantée, avec leur valeur.
class _SeatOptions extends StatelessWidget {
  const _SeatOptions({
    required this.controller,
    required this.player,
    required this.color,
    required this.haptic,
    required this.showTips,
    required this.full,
  });

  final GameController controller;
  final Player player;
  final Color color;
  final bool haptic;
  final bool showTips;

  /// Poison, monarque et taxe visibles même à zéro.
  final bool full;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    if (seatOptionsExtent(game, player, full: full) == 0) {
      return const SizedBox.shrink();
    }
    final poisonMax = game.poisonThreshold;
    final poisonTip = tipPoison(poisonMax);
    Widget explain(OptionTip tip, Widget child, {bool longPress = true}) {
      return HelpTip(
        enabled: showTips,
        title: tip.title,
        message: tip.message,
        longPress: longPress,
        child: child,
      );
    }

    String shortCmd(String name) {
      final trimmed = name.trim();
      if (trimmed.length <= 10) return trimmed;
      return '${trimmed.substring(0, 9)}…';
    }

    final core = <Widget>[
      if (full || player.poison != 0)
        explain(
          poisonTip,
          _StatusChip(
            label: '☠ ${player.poison}',
            active: player.poison > 0,
            danger: player.poison >= poisonMax - 1,
            onMinus: () {
              controller.bumpStat(player.id, Stat.poison, -1);
              buzz(haptic);
            },
            onPlus: () {
              controller.bumpStat(player.id, Stat.poison, 1);
              buzz(haptic);
            },
          ),
        ),
      if (full || game.monarchId == player.id)
        explain(
          tipMonarch,
          _ToggleChip(
            icon: Icons.workspace_premium,
            label: 'Monarque',
            active: game.monarchId == player.id,
            color: color,
            onTap: () {
              controller.toggleMonarch(player.id);
              buzz(haptic);
            },
          ),
        ),
      if (game.initiativeId == player.id)
        explain(
          tipInitiative,
          _ToggleChip(
            icon: Icons.flag,
            label: 'Initiative',
            active: true,
            color: color,
            onTap: () {
              controller.toggleInitiative(player.id);
              buzz(haptic);
            },
          ),
        ),
      if (game.trackCommanderTax)
        for (final commander in player.commanders)
          if (full || commander.tax > 0)
            explain(
              tipTax,
              _StatusChip(
                label: player.commanders.length == 1
                    ? 'Taxe +${commander.tax}'
                    : '${shortCmd(commander.name)} +${commander.tax}',
                active: commander.tax > 0,
                danger: false,
                onMinus: () {
                  controller.castCommander(commander.id, -1);
                  buzz(haptic);
                },
                onPlus: () {
                  controller.castCommander(commander.id, 1);
                  buzz(haptic);
                },
              ),
            ),
      if (player.blessing)
        explain(
          tipBlessing,
          _ToggleChip(
            icon: Icons.apartment,
            label: 'Cité',
            active: true,
            color: color,
            onTap: () {
              controller.toggleBlessing(player.id);
              buzz(haptic);
            },
          ),
        ),
    ];
    final parameters = <Widget>[
      for (final stat in statPlayOrder)
        if (stat != Stat.poison &&
            stat != Stat.rad &&
            stat != Stat.speed &&
            stat != Stat.signature &&
            player.readStat(stat) != 0)
          explain(
            tipForStat(stat, player),
            _StatusChip(
              label: '${_statShort(stat, player)} ${player.readStat(stat)}',
              active: true,
              danger: false,
              onMinus: () {
                controller.bumpStat(player.id, stat, -1);
                buzz(haptic);
              },
              onPlus: () {
                controller.bumpStat(player.id, stat, 1);
                buzz(haptic);
              },
            ),
          ),
      for (final key in manaKeys)
        if ((player.mana[key] ?? 0) != 0)
          explain(
            tipMana,
            _StatusChip(
            label: '$key ${player.mana[key]}',
            active: true,
            danger: false,
            onMinus: () {
              controller.bumpMana(player.id, key, -1);
              buzz(haptic);
            },
            onPlus: () {
              controller.bumpMana(player.id, key, 1);
              buzz(haptic);
            },
          ),
          ),
      if (player.ring != 0)
        explain(
          tipRing,
          _StatusChip(
          label: 'Anneau ${player.ring}',
          active: true,
          danger: false,
          onMinus: () {
            controller.setRing(player.id, player.ring - 1);
            buzz(haptic);
          },
          onPlus: () {
            controller.setRing(player.id, player.ring + 1);
            buzz(haptic);
          },
        ),
        ),
      for (final stat in [Stat.rad, Stat.speed, Stat.signature])
        if ((stat != Stat.signature ||
                game.format == MatchFormat.oathbreaker) &&
            player.readStat(stat) != 0)
          explain(
            tipForStat(stat, player),
            _StatusChip(
              label: '${_statShort(stat, player)} ${player.readStat(stat)}',
              active: true,
              danger: false,
              onMinus: () {
                controller.bumpStat(player.id, stat, -1);
                buzz(haptic);
              },
              onPlus: () {
                controller.bumpStat(player.id, stat, 1);
                buzz(haptic);
              },
            ),
          ),
      for (final counter in player.custom)
        explain(
          OptionTip(counter.name, tipCustom.message),
          _StatusChip(
          label: '${counter.name} ${counter.value}',
          active: counter.value != 0,
          danger: false,
          onMinus: () {
            controller.bumpCustom(player.id, counter.id, -1);
            buzz(haptic);
          },
          onPlus: () {
            controller.bumpCustom(player.id, counter.id, 1);
            buzz(haptic);
          },
        ),
        ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (core.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: _ChipScroller(children: core),
          ),
        if (parameters.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Wrap(spacing: 6, runSpacing: 6, children: parameters),
          ),
      ],
    );
  }
}

String _statShort(Stat stat, Player player) => switch (stat) {
  Stat.poison => 'Poison',
  Stat.energy => 'Énergie',
  Stat.experience => 'XP',
  Stat.rad => 'Rad',
  Stat.speed => 'Vitesse',
  Stat.treasure => 'Trésors',
  Stat.storm => 'Tempête',
  Stat.signature => player.signatureName,
};

/// Pastilles en lignes, sans liste qui vole le doigt.
class _ChipScroller extends StatelessWidget {
  const _ChipScroller({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, index) => children[index],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.active,
    required this.danger,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final bool active;
  final bool danger;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFF3A1822)
        : active
        ? accent.withValues(alpha: 0.16)
        : panelInk;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: danger
              ? dangerCrit.withValues(alpha: 0.8)
              : active
              ? accent.withValues(alpha: 0.55)
              : line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepeatTap(
            onTick: onMinus,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.remove, size: 22),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          RepeatTap(
            onTick: onPlus,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.add, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.28)
              : Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? color : Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: active ? color : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? color : Colors.white70,
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

class _LifePad extends StatelessWidget {
  const _LifePad({
    required this.controller,
    required this.seatPlayer,
    required this.target,
    required this.color,
    required this.haptic,
    required this.compact,
    required this.showFive,
    required this.startingLife,
    required this.seatActive,
    this.numberSize,
    this.showHistory = true,
    this.showTips = false,
  });

  final GameController controller;

  /// Joueur du siège (son nom / badge).
  final Player seatPlayer;

  /// Joueur dont le gros pad change les PV (souvent l’adversaire en face).
  final Player target;
  final Color color;
  final bool haptic;
  final bool compact;
  final bool showFive;
  final int startingLife;
  final bool seatActive;
  final bool showTips;

  /// Chiffre de l’adversaire, plus petit que les PV perso.
  final double? numberSize;

  /// Lignes d’historique au-dessus du gros chiffre.
  final bool showHistory;

  void _delta(int value) {
    controller.addLife(
      target.id,
      value,
      dealtBy: target.id == seatPlayer.id ? null : seatPlayer.id,
    );
    buzz(haptic);
  }

  Widget _side({
    required String big,
    required String five,
    required Color fill,
    required Color fiveFill,
    required Color textColor,
    required int step,
    required int jump,
    String? semantics,
  }) {
    final button = Semantics(
      button: true,
      label: semantics,
      child: RepeatTap(
      onTick: () => _delta(step),
      child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                big,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: TextStyle(
                  fontSize: 64,
                  height: 1,
                  leadingDistribution: TextLeadingDistribution.even,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!showFive) return button;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 100) return button;
        return Column(
          children: [
            Expanded(child: button),
            const SizedBox(height: 5),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: Material(
                color: fiveFill,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => _delta(jump),
                  onLongPress: () => _delta(jump * 2),
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: Text(
                      five,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final opponent = target.id != seatPlayer.id;
        final caption = opponent ? 'Vie de ${target.name}' : 'Mes PV';
        const endTurnHeight = 48.0;
        final room =
            constraints.maxHeight - (seatActive ? endTurnHeight : 0);
        final histLines = room >= 220
            ? 3
            : room >= 150
            ? 2
            : room >= 108
            ? 1
            : 0;
        final pad = Row(
          children: [
            Expanded(
              child: _side(
                big: '−',
                five: '−5',
                fill: const Color(0xFF5C2432).withValues(alpha: 0.92),
                fiveFill: const Color(0xFF421824),
                textColor: const Color(0xFFFFE4E8),
                step: -1,
                jump: -5,
                semantics: opponent
                    ? 'Retirer un point à ${target.name}'
                    : 'Retirer un point de ma vie',
              ),
            ),
            Expanded(
              flex: 2,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: compact ? 18 : 24),
                    child: DangerLifeDisplay(
                      life: target.life,
                      startingLife: startingLife,
                      compact: compact,
                      fontSize: numberSize,
                      tight: numberSize != null,
                      lifeKey: ValueKey(
                        'life-pad-${seatPlayer.id}-${target.id}',
                      ),
                      onTap: () => showAmountSheet(
                        context,
                        title: 'PV de ${target.name}',
                        subtitle: target.id == seatPlayer.id
                            ? '− enlève un point, + le rend.'
                            : 'Vie de l’adversaire. − enlève, + rend.',
                        listenable: controller,
                        current: () => controller.playerById(target.id).life,
                        onDelta: (delta) => controller.addLife(
                          target.id,
                          delta,
                          dealtBy: target.id == seatPlayer.id
                              ? null
                              : seatPlayer.id,
                        ),
                        onSet: (value) => controller.setLife(target.id, value),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 2,
                    right: 2,
                    child: Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compact ? 10 : 12,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: color.withValues(alpha: 0.95),
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                  // Lifetap-style : un seul ± qui reste puis s’efface.
                  Positioned(
                    right: 0,
                    top: compact ? 28 : 36,
                    child: _LingeringDelta(
                      controller: controller,
                      playerId: target.id,
                      compact: compact,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _side(
                big: '+',
                five: '+5',
                fill: _gainStep,
                fiveFill: _gainJump,
                textColor: _gainInk,
                step: 1,
                jump: 5,
              ),
            ),
          ],
        );
        return Column(
          children: [
            if (showHistory && histLines > 0)
              _CountHistory(
                controller: controller,
                playerId: target.id,
                threshold: controller.game.commanderThreshold,
                lines: histLines,
                trackCommander: controller.game.trackCommanderDamage,
              ),
            Expanded(child: pad),
            if (seatActive)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  height: endTurnHeight,
                  width: double.infinity,
                  child: HelpTip(
                    enabled: showTips,
                    title: tipEndTurn.title,
                    message: tipEndTurn.message,
                    child: FilledButton(
                    key: ValueKey('fin-de-tour-${seatPlayer.id}'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    onPressed: () {
                      endPlayerTurn(context, controller);
                      buzz(haptic);
                    },
                    child: const Text(
                      'Fin de tour',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Derniers décomptes du siège, du plus récent au plus ancien.
class _CountHistory extends StatelessWidget {
  const _CountHistory({
    required this.controller,
    required this.playerId,
    required this.threshold,
    required this.lines,
    required this.trackCommander,
  });

  final GameController controller;
  final String playerId;
  final int threshold;
  final int lines;
  final bool trackCommander;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final rows = _rows();
        final style = TextStyle(
          fontSize: 11,
          height: 1.15,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.78),
        );
        if (rows.isEmpty) {
          return Text(
            '− enlève un point · + le rend',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: style,
          );
        }
        return Column(
          children: [
            for (final row in rows.take(lines))
              Text(
                row,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: style,
              ),
          ],
        );
      },
    );
  }

  List<String> _rows() {
    final stamped = <({int at, String text})>[];
    for (final change in controller.recentLifeChangesFor(playerId, limit: 12)) {
      if (change.reason != null) continue;
      stamped.add((
        at: change.atMs ?? 0,
        text: 'Vie ${change.deltaLabel} · ${change.from} → ${change.to}',
      ));
    }
    if (trackCommander) {
      for (final change in controller.cmdDamageLog) {
        if (change.defenderId != playerId || change.delta == 0) continue;
        final signed = -change.delta;
        final mark = signed > 0 ? '+$signed' : '$signed';
        final life =
            change.lifeFrom != null &&
                change.lifeTo != null &&
                change.lifeFrom != change.lifeTo
            ? ' · vie ${change.lifeFrom} → ${change.lifeTo}'
            : '';
        final who = change.commanderLabel.replaceFirst(RegExp(r'^Cdt '), '');
        stamped.add((
          at: change.atMs ?? 0,
          text: '$who $mark · ${change.toTaken}/$threshold$life',
        ));
      }
    }
    stamped.sort((a, b) => b.at.compareTo(a.at));
    return [for (final row in stamped) row.text];
  }
}

/// Un seul ± PV à côté du total (style Lifetap) : reste ~3,5 s puis disparaît.
class _LingeringDelta extends StatefulWidget {
  const _LingeringDelta({
    required this.controller,
    required this.playerId,
    required this.compact,
  });

  final GameController controller;
  final String playerId;
  final bool compact;

  @override
  State<_LingeringDelta> createState() => _LingeringDeltaState();
}

class _LingeringDeltaState extends State<_LingeringDelta> {
  static const _hold = Duration(milliseconds: 3500);

  Timer? _hide;
  int? _delta;
  int _stamp = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    _sync();
  }

  @override
  void didUpdateWidget(covariant _LingeringDelta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.playerId != widget.playerId) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
      _sync();
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    _sync();
  }

  void _sync() {
    final stack = widget.controller.recentLifeChangesFor(
      widget.playerId,
      limit: 1,
    );
    if (stack.isEmpty) {
      if (_delta != null) {
        setState(() => _delta = null);
      }
      return;
    }
    final hit = stack.first;
    final stamp = (hit.atMs ?? 0) ^ hit.delta ^ hit.to ^ hit.from;
    // Même coup déjà vu (affiché ou déjà effacé) → ne pas le ressusciter.
    if (stamp == _stamp) return;
    _stamp = stamp;
    _hide?.cancel();
    setState(() => _delta = hit.delta);
    _hide = Timer(_hold, () {
      if (!mounted) return;
      setState(() => _delta = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final delta = _delta;
    return AnimatedOpacity(
      opacity: delta == null ? 0 : 1,
      duration: const Duration(milliseconds: 280),
      child: delta == null
          ? const SizedBox.shrink()
          : GestureDetector(
              onTap: () => showLifeLogSheet(
                context,
                widget.controller,
                playerId: widget.playerId,
              ),
              child: Text(
                delta > 0 ? '+$delta' : '$delta',
                style: TextStyle(
                  fontSize: widget.compact ? 22 : 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: delta < 0
                      ? const Color(0xFFFF8A9A)
                      : const Color(0xFF7DFFB2),
                  shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
                ),
              ),
            ),
    );
  }
}

class _Incoming {
  const _Incoming(this.owner, this.commander, this.remaining, this.taken);

  final Player owner;
  final Commander commander;
  final int remaining;
  final int taken;
}

class _CommanderStrip extends StatelessWidget {
  const _CommanderStrip({
    required this.controller,
    required this.attacker,
    required this.defender,
    required this.haptic,
    required this.panelWidth,
    this.compact = false,
  });

  final GameController controller;

  /// Siège : propriétaire des Cdt affichés.
  final Player attacker;

  /// Gros pad : qui subit les Cdt (adversaire en face).
  final Player defender;
  final bool haptic;
  final double panelWidth;
  final bool compact;

  /// Table en face : mes Cdt → adversaire.
  /// Liste (pad = soi) : Cdt adverses reçus (repli).
  List<_Incoming> _hits() {
    final hits = <_Incoming>[];
    final outgoing = attacker.id != defender.id;
    if (outgoing) {
      for (final commander in attacker.commanders) {
        final taken = defender.damageTaken[commander.id] ?? 0;
        hits.add(
          _Incoming(
            attacker,
            commander,
            controller.game.commanderRemaining(defender, commander.id),
            taken,
          ),
        );
      }
      return hits;
    }
    final players = controller.game.players;
    final start = controller.game.indexOf(defender.id);
    for (var step = 1; step < players.length; step++) {
      final owner = players[(start + step) % players.length];
      for (final commander in owner.commanders) {
        final taken = defender.damageTaken[commander.id] ?? 0;
        hits.add(
          _Incoming(
            owner,
            commander,
            controller.game.commanderRemaining(defender, commander.id),
            taken,
          ),
        );
      }
    }
    return hits;
  }

  @override
  Widget build(BuildContext context) {
    final hits = _hits();
    final threshold = controller.game.commanderThreshold;
    final outgoing = attacker.id != defender.id;
    if (hits.isEmpty && !outgoing) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Touchez le nom du joueur pour ajouter un commandant',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12,
          ),
        ),
      );
    }

    const gap = 8.0;
    const maxW = 240.0;
    final count = hits.isEmpty ? 1 : hits.length;
    final available = panelWidth.clamp(0.0, maxW);
    final share = count <= 1
        ? available
        : (panelWidth - gap * (count - 1)) / count;
    final fitted = share >= 132 && share <= maxW
        ? share
        : (available < 132 ? available : 148.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 2),
          child: Text(
            outgoing
                ? 'Commandant · − enlève 1 vie · + rend'
                : 'Commandant reçu · − enlève · + rend',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
        if (hits.isNotEmpty)
          SizedBox(
            height: compact ? 56 : 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hits.length,
              separatorBuilder: (_, _) => const SizedBox(width: gap),
              itemBuilder: (_, index) {
                return _CmdChip(
                  hit: hits[index],
                  threshold: threshold,
                  haptic: haptic,
                  defender: defender,
                  controller: controller,
                  width: fitted,
                  dense: compact,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CmdChip extends StatefulWidget {
  const _CmdChip({
    required this.hit,
    required this.threshold,
    required this.haptic,
    required this.defender,
    required this.controller,
    required this.width,
    this.dense = false,
  });

  final _Incoming hit;
  final int threshold;
  final bool haptic;
  final Player defender;
  final GameController controller;
  final double width;
  final bool dense;

  String get defenderId => defender.id;

  @override
  State<_CmdChip> createState() => _CmdChipState();
}

class _CmdChipState extends State<_CmdChip> {
  String get _label =>
      commanderChipLabel(widget.hit.owner, widget.hit.commander);

  void _hit(int delta) {
    widget.controller.addCommanderDamage(
      defenderId: widget.defenderId,
      commanderId: widget.hit.commander.id,
      delta: delta,
    );
    buzz(widget.haptic);
  }

  Future<void> _openZoom() async {
    final label = _label;
    final color = playerColor(widget.hit.owner.color);
    final threshold = widget.threshold;
    final defenderId = widget.defenderId;
    final commanderId = widget.hit.commander.id;
    final owner = widget.hit.owner;
    final controller = widget.controller;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final defender = controller.playerById(defenderId);
            final remaining = controller.game.commanderRemaining(
              defender,
              commanderId,
            );
            final lethal = remaining <= 0;
            final warn = !lethal && remaining <= 6;
            final numberColor = lethal
                ? const Color(0xFFFFB4BC)
                : warn
                ? const Color(0xFFFFC46B)
                : Colors.white;
            final progress = (remaining / threshold).clamp(0.0, 1.0);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: lethal
                          ? const [Color(0xFF4A1824), Color(0xFF2A1018)]
                          : [
                              Color.alphaBlend(
                                color.withValues(alpha: 0.22),
                                const Color(0xFF1A2030),
                              ),
                              const Color(0xFF10141C),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: lethal ? const Color(0xFFFF6B7A) : color,
                      width: 2.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: color,
                              child: Text(
                                playerInitial(owner.name),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.1,
                            ),
                            color: lethal
                                ? const Color(0xFFFF6B7A)
                                : warn
                                ? const Color(0xFFFFC46B)
                                : color,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // − enlève 1 point (vie comprise). + rend le point.
                        _CmdSideButton(
                          key: ValueKey('chip-minus-$defenderId-$commanderId'),
                          icon: Icons.remove_rounded,
                          label: 'ENLEVER 1',
                          tooltip: 'Enlève 1 point de commandant et 1 vie',
                          foreground: const Color(0xFFFFF0F2),
                          background: const Color(0xFFB03A4A),
                          wide: true,
                          height: 72,
                          onTick: () => _hit(1),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          key: ValueKey(
                            'chip-open-zoom-$defenderId-$commanderId',
                          ),
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            showAmountSheet(
                              this.context,
                              title: label,
                              subtitle: 'Points restants sur $threshold.',
                              listenable: controller,
                              current: () => controller.game.commanderRemaining(
                                controller.playerById(defenderId),
                                commanderId,
                              ),
                              lethalAt: 0,
                              onDelta: (delta) => _hit(-delta),
                              onSet: (value) => controller.setCommanderDamage(
                                defenderId: defenderId,
                                commanderId: commanderId,
                                value: (threshold - value).clamp(0, threshold),
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              Text(
                                '$remaining',
                                style: lifeStyle(64, numberColor),
                              ),
                              Text(
                                'reste / $threshold  ·  toucher pour un montant',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.58),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _CmdSideButton(
                          key: ValueKey('chip-plus-$defenderId-$commanderId'),
                          icon: Icons.add_rounded,
                          label: 'RENDRE 1',
                          tooltip: 'Rend 1 point de commandant et 1 vie',
                          foreground: const Color(0xFFE8FFF2),
                          background: const Color(0xFF1F8A58),
                          wide: true,
                          height: 72,
                          onTick: () => _hit(-1),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Maintenez pour enchaîner · dehors = fermer',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = playerColor(widget.hit.owner.color);
    final lethal = widget.hit.remaining <= 0;
    final label = _label;

    final side = widget.width < 170 ? 44.0 : 48.0;
    return SizedBox(
      width: widget.width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: lethal ? const Color(0xFF3A1822) : panelInk,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: lethal ? dangerCrit : color.withValues(alpha: 0.7),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Row(
            children: [
              // − gauche = enlever un point (vie comprise).
              SizedBox(
                width: side,
                child: Column(
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Enlever un point de commandant',
                        child: RepeatTap(
                          onTick: () => _hit(1),
                          child: ColoredBox(
                            key: ValueKey(
                              'chip-minus-${widget.defenderId}-${widget.hit.commander.id}',
                            ),
                            color: const Color(0xFF6A2A38),
                            child: const Center(
                              child: Text(
                                '−',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFFFE4E8),
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Enlever cinq points de commandant',
                        child: RepeatTap(
                          onTick: () => _hit(5),
                          child: const ColoredBox(
                            color: Color(0xFF421824),
                            child: Center(
                              child: Text(
                                '−5',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFFE4E8),
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InkWell(
                  key: ValueKey(
                    'chip-open-${widget.defenderId}-${widget.hit.commander.id}',
                  ),
                  onTap: _openZoom,
                  onLongPress: () => showLifeLogSheet(
                    context,
                    widget.controller,
                    playerId: widget.defenderId,
                    initialTab: LifeLogTab.commander,
                    commanderId: widget.hit.commander.id,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ListenableBuilder(
                      listenable: widget.controller,
                      builder: (context, _) {
                        final taken =
                            widget.controller
                                .playerById(widget.defenderId)
                                .damageTaken[widget.hit.commander.id] ??
                            0;
                        final remaining = (widget.threshold - taken).clamp(
                          0,
                          widget.threshold,
                        );
                        final ko = remaining <= 0;
                        final liveColor = ko
                            ? const Color(0xFFFFB4BC)
                            : remaining <= 6
                            ? const Color(0xFFFFC46B)
                            : Colors.white;
                        final dense = widget.dense;
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: dense ? 7 : 8,
                                    backgroundColor: color,
                                    child: Text(
                                      playerInitial(widget.hit.owner.name),
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: dense ? 8 : 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: dense ? 9 : 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '$remaining',
                                style: lifeStyle(dense ? 18 : 22, liveColor),
                              ),
                              Text(
                                ko ? 'KO' : '$taken / ${widget.threshold}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: dense ? 9 : 10,
                                  fontWeight: FontWeight.w800,
                                  color: liveColor.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // + droite = rendre le point.
              SizedBox(
                width: side,
                child: Column(
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Rendre un point de commandant',
                        child: RepeatTap(
                          onTick: () => _hit(-1),
                          child: ColoredBox(
                            key: ValueKey(
                              'chip-plus-${widget.defenderId}-${widget.hit.commander.id}',
                            ),
                            color: _gainStep,
                            child: const Center(
                              child: Text(
                                '+',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFE8FFF2),
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Rendre cinq points de commandant',
                        child: RepeatTap(
                          onTick: () => _hit(-5),
                          child: const ColoredBox(
                            color: _gainJump,
                            child: Center(
                              child: Text(
                                '+5',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFE8FFF2),
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CmdSideButton extends StatelessWidget {
  const _CmdSideButton({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.foreground,
    required this.background,
    required this.onTick,
    this.wide = false,
    this.height,
  });

  static const double _size = 64;

  final IconData icon;
  final String label;
  final String tooltip;
  final Color foreground;
  final Color background;
  final VoidCallback onTick;
  final bool wide;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final h = height ?? _size;
    return Tooltip(
      message: tooltip,
      child: RepeatTap(
        onTick: onTick,
        child: SizedBox(
          width: wide ? double.infinity : _size,
          height: h,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(wide ? 22 : 20),
              boxShadow: [
                BoxShadow(
                  color: background.withValues(alpha: 0.5),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: wide
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 34, color: foreground),
                          const SizedBox(width: 10),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                              color: foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: _size * 0.38, color: foreground),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: foreground.withValues(alpha: 0.95),
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

class _OwnLifeRow extends StatelessWidget {
  const _OwnLifeRow({
    required this.controller,
    required this.player,
    required this.haptic,
    required this.startLife,
    required this.fontSize,
  });

  final GameController controller;
  final Player player;
  final bool haptic;
  final int startLife;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final tint = playerColor(player.color);
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            _StepKey(
              label: '−',
              semantics: 'Enlever un point de vie personnel',
              fill: const Color(0xFF5C2432),
              foreground: const Color(0xFFFFE4E8),
              onStep: () {
                controller.addLife(player.id, -1);
                buzz(haptic);
              },
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mes PV',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: tint.withValues(alpha: 0.95),
                        height: 1,
                      ),
                    ),
                    DangerLifeDisplay(
                      life: player.life,
                      startingLife: startLife,
                      compact: true,
                      fontSize: fontSize,
                      tight: true,
                      onTap: () => showAmountSheet(
                        context,
                        title: 'Mes PV',
                        subtitle: '− enlève un point, + le rend.',
                        listenable: controller,
                        current: () => controller.playerById(player.id).life,
                        onDelta: (delta) => controller.addLife(player.id, delta),
                        onSet: (value) => controller.setLife(player.id, value),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _StepKey(
              label: '+',
              semantics: 'Ajouter un point de vie personnel',
              fill: _gainStep,
              foreground: _gainInk,
              onStep: () {
                controller.addLife(player.id, 1);
                buzz(haptic);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Partie haute : ma vie, et les commandants adverses déjà reçus.
class _OwnLosses extends StatelessWidget {
  const _OwnLosses({
    required this.controller,
    required this.player,
    required this.color,
    required this.haptic,
    required this.startLife,
    required this.showTips,
    required this.expand,
    this.active = false,
  });

  final GameController controller;
  final Player player;
  final Color color;
  final bool haptic;
  final int startLife;
  final bool showTips;
  final bool expand;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final life = _LifePad(
      controller: controller,
      seatPlayer: player,
      target: player,
      color: color,
      haptic: haptic,
      compact: !expand,
      showFive: true,
      startingLife: startLife,
      seatActive: active,
      showHistory: false,
      showTips: showTips,
    );
    final strip = controller.game.trackCommanderDamage
        ? _BandCmdStrip(
            controller: controller,
            seat: player,
            haptic: haptic,
            dealing: false,
            showTips: showTips,
          )
        : null;
    if (!expand) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 112, child: life),
          if (strip != null) strip,
        ],
      );
    }
    return Column(
      children: [
        Expanded(child: life),
        if (strip != null) strip,
      ],
    );
  }
}

class _StepKey extends StatelessWidget {
  const _StepKey({
    required this.label,
    required this.semantics,
    required this.fill,
    required this.foreground,
    required this.onStep,
    this.width = 56,
    this.height = 56,
    this.fontSize = 32,
  });

  final String label;
  final String semantics;
  final Color fill;
  final Color foreground;
  final VoidCallback onStep;
  final double width;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      child: RepeatTap(
        onTick: onStep,
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dégâts de commandant déjà subis, avec la couleur du propriétaire.
class _ReceivedCommanders extends StatelessWidget {
  const _ReceivedCommanders({required this.controller, required this.player});

  final GameController controller;
  final Player player;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (final owner in controller.game.players) {
      if (owner.id == player.id) continue;
      for (final commander in owner.commanders) {
        final taken = player.damageTaken[commander.id] ?? 0;
        if (taken <= 0) continue;
        final color = playerColor(owner.color);
        final name = isGenericCommanderName(commander.name)
            ? 'Cdt'
            : commander.name;
        chips.add(
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 9,
                  backgroundColor: color,
                  child: Text(
                    playerInitial(owner.name),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$name $taken',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Text(
              'Reçu',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: chips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, index) => chips[index],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compteurs de commandant d’une bande à 3 ou 4.
/// À ton tour : tes commandants frappent les cibles choisies.
/// Toujours : les commandants reçus, avec la couleur de leur propriétaire.
class _BandCmdStrip extends StatelessWidget {
  const _BandCmdStrip({
    required this.controller,
    required this.seat,
    required this.haptic,
    required this.dealing,
    this.showTips = false,
    this.selected = const {},
    this.zone = false,
    this.received = true,
  });

  final GameController controller;
  final Player seat;
  final bool haptic;
  final bool dealing;
  final bool showTips;
  final Set<String> selected;
  final bool zone;

  /// Vrai : commandants adverses reçus. Faux : mes commandants infligés.
  final bool received;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    if (!game.trackCommanderDamage) return const SizedBox.shrink();
    final opponents = [
      for (final player in game.players)
        if (player.id != seat.id) player,
    ];
    final mine = dealing ? seat.commanders : const <Commander>[];
    final incoming = [
      for (final owner in opponents)
        for (final commander in owner.commanders) (owner: owner, commander: commander),
    ];
    if (received && incoming.isEmpty) return const SizedBox.shrink();
    if (!received && mine.isEmpty) return const SizedBox.shrink();

    final targets = zone
        ? [for (final player in opponents) player.id]
        : [
            for (final id in selected)
              if (opponents.any((player) => player.id == id)) id,
          ];
    Player? only;
    if (targets.length == 1) {
      only = controller.playerById(targets.first);
    }

    return SizedBox(
      height: 46,
      child: Row(
        children: [
          HelpTip(
            enabled: showTips,
            title: received ? 'Commandant reçu' : 'Commandant infligé',
            message: received
                ? 'Commandant adverse, en haut du profil. '
                    'Le nombre monte : ce sont les points déjà pris. '
                    '− et −5 t’enlèvent cette vie. + et +5 te la rendent.'
                : 'Tes commandants, sur les profils choisis plus haut. '
                    '− et −5 retirent cette vie à chaque cible. '
                    '+ et +5 la rendent.',
            child: Text(
              received ? 'Reçu' : 'Infligé',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (received)
                for (final hit in incoming)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _CmdTick(
                      controller: controller,
                      haptic: haptic,
                      owner: hit.owner,
                      commander: hit.commander,
                      defender: seat,
                      taken: seat.damageTaken[hit.commander.id] ?? 0,
                      remaining: game.commanderRemaining(
                        seat,
                        hit.commander.id,
                      ),
                      onDelta: (delta) {
                        controller.addCommanderDamage(
                          defenderId: seat.id,
                          commanderId: hit.commander.id,
                          delta: delta,
                        );
                        buzz(haptic);
                      },
                    ),
                  ),
                if (!received)
                  for (final commander in mine)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _CmdTick(
                        controller: controller,
                        haptic: haptic,
                        owner: seat,
                        commander: commander,
                        defender: only,
                        taken: only == null
                            ? null
                            : (only.damageTaken[commander.id] ?? 0),
                        remaining: only == null
                            ? null
                            : game.commanderRemaining(only, commander.id),
                        hint: targets.isEmpty
                            ? 'cible'
                            : targets.length == 1
                            ? null
                            : '×${targets.length}',
                        label: isGenericCommanderName(commander.name)
                            ? 'Cdt'
                            : commander.name,
                        onDelta: (delta) {
                          if (targets.isEmpty) {
                            controller.flash(
                              'Choisis qui subit le commandant',
                            );
                            return;
                          }
                          controller.addCommanderDamageMany(
                            defenderIds: targets,
                            commanderId: commander.id,
                            delta: delta,
                          );
                          buzz(haptic);
                        },
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CmdTick extends StatelessWidget {
  const _CmdTick({
    required this.controller,
    required this.haptic,
    required this.owner,
    required this.commander,
    required this.onDelta,
    this.defender,
    this.taken,
    this.remaining,
    this.hint,
    this.label,
  });

  final GameController controller;
  final bool haptic;
  final Player owner;
  final Commander commander;
  final Player? defender;
  final int? taken;
  final int? remaining;
  final String? hint;
  final String? label;
  final void Function(int delta) onDelta;

  void _openMemory(BuildContext context) {
    final who = defender;
    if (!controller.rememberCommanderLog || who == null) return;
    showLifeLogSheet(
      context,
      controller,
      playerId: who.id,
      initialTab: LifeLogTab.commander,
      commanderId: commander.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = playerColor(owner.color);
    final name = label ??
        (isGenericCommanderName(commander.name) ? owner.name : commander.name);
    final number = hint ?? (taken == null ? '—' : '$taken');
    final detail = hint != null || remaining == null
        ? null
        : 'reste $remaining';
    final warn = remaining != null && remaining! <= 6 && hint == null;
    final lethal = remaining != null && remaining! <= 0 && hint == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: lethal ? const Color(0xFF3A1822) : panelInk,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lethal ? dangerCrit : color, width: 1.4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          RepeatTap(
            onTick: () => onDelta(1),
            child: const SizedBox(
              width: 36,
              height: 44,
              child: ColoredBox(
                color: Color(0xFF6A2A38),
                child: Center(
                  child: Text(
                    '−',
                    style: TextStyle(
                      fontSize: 22,
                      height: 1,
                      color: Color(0xFFFFE4E8),
                    ),
                  ),
                ),
              ),
            ),
          ),
          RepeatTap(
            onTick: () => onDelta(5),
            child: const SizedBox(
              width: 34,
              height: 44,
              child: ColoredBox(
                color: Color(0xFF421824),
                child: Center(
                  child: Text(
                    '−5',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFE4E8),
                    ),
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _openMemory(context),
            onLongPress: () => _openMemory(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 72, maxWidth: 120),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 7,
                          backgroundColor: color,
                          child: Text(
                            playerInitial(owner.name),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      detail == null ? number : '$number · $detail',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: lifeStyle(
                        13,
                        lethal
                            ? const Color(0xFFFFB4BC)
                            : warn
                            ? const Color(0xFFFFC46B)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          RepeatTap(
            onTick: () => onDelta(-5),
            child: const SizedBox(
              width: 34,
              height: 44,
              child: ColoredBox(
                color: _gainJump,
                child: Center(
                  child: Text(
                    '+5',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE8FFF2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          RepeatTap(
            onTick: () => onDelta(-1),
            child: const SizedBox(
              width: 36,
              height: 44,
              child: ColoredBox(
                color: _gainStep,
                child: Center(
                  child: Text(
                    '+',
                    style: TextStyle(
                      fontSize: 22,
                      height: 1,
                      color: Color(0xFFE8FFF2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _BandSeat extends StatelessWidget {
  const _BandSeat({
    required this.controller,
    required this.player,
    required this.color,
    required this.active,
    required this.haptic,
    required this.startLife,
    required this.showTips,
  });

  final GameController controller;
  final Player player;
  final Color color;
  final bool active;
  final bool haptic;
  final int startLife;
  final bool showTips;

  @override
  Widget _body({required bool showStrip, required ScorePane pane}) {
    final own = pane != ScorePane.foes;
    final foes = pane != ScorePane.own;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: _BandHeader(
              controller: controller,
              player: player,
              color: color,
              active: active,
              haptic: haptic,
              startLife: startLife,
              showTips: showTips,
              ownLife: !own,
            ),
          ),
          _SeatOptions(
            controller: controller,
            player: player,
            color: color,
            haptic: haptic,
            showTips: showTips,
            full: pane != ScorePane.foes,
          ),
          if (own && foes)
            _OwnLosses(
              controller: controller,
              player: player,
              color: color,
              haptic: haptic,
              startLife: startLife,
              showTips: showTips,
              expand: false,
            ),
          if (own && !foes)
            Expanded(
              child: _OwnLosses(
                controller: controller,
                player: player,
                color: color,
                haptic: haptic,
                startLife: startLife,
                showTips: showTips,
                expand: true,
                active: active,
              ),
            ),
          if (foes)
            Expanded(
              child: _TurnConsole(
                controller: controller,
                seat: player,
                color: color,
                haptic: haptic,
                active: active,
                showStrip: showStrip,
                showTips: showTips,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final showStrip = controller.game.trackCommanderDamage;
        final pane = SeatPanes.paneOf(context, player.id);
        final options = seatOptionsExtent(
          controller.game,
          player,
          full: pane != ScorePane.foes,
        );
        // Taille où Mes PV, les cibles, les ±5 et les commandants tiennent.
        const designW = 300.0;
        final designH = (pane == ScorePane.both ? 380.0 : 210.0) +
            (pane == ScorePane.own ? 48.0 : 0.0) +
            options;
        final tight = !width.isFinite ||
            !height.isFinite ||
            width < designW ||
            height < designH;
        if (!tight) return _body(showStrip: showStrip, pane: pane);
        final boxW = width.isFinite && width > designW ? width : designW;
        final boxH = height.isFinite && height > designH ? height : designH;
        return FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: boxW,
            height: boxH,
            child: _body(showStrip: showStrip, pane: pane),
          ),
        );
      },
    );
  }
}

class _BandLifePad extends StatelessWidget {
  const _BandLifePad({
    required this.controller,
    required this.player,
    required this.color,
    required this.haptic,
    required this.startLife,
  });

  final GameController controller;
  final Player player;
  final Color color;
  final bool haptic;
  final int startLife;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepKey(
          label: '−',
          semantics: 'Enlever un point de vie personnel',
          fill: const Color(0xFF5C2432),
          foreground: const Color(0xFFFFE4E8),
          width: 56,
          height: double.infinity,
          onStep: () {
            controller.addLife(player.id, -1);
            buzz(haptic);
          },
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mes PV',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
                DangerLifeDisplay(
                  life: player.life,
                  startingLife: startLife,
                  compact: true,
                  tight: true,
                  fontSize: 48,
                  lifeKey: ValueKey('life-pad-${player.id}-${player.id}'),
                  onTap: () => showAmountSheet(
                    context,
                    title: 'Mes PV',
                    subtitle: '− enlève un point, + le rend.',
                    listenable: controller,
                    current: () => controller.playerById(player.id).life,
                    onDelta: (delta) => controller.addLife(player.id, delta),
                    onSet: (value) => controller.setLife(player.id, value),
                  ),
                ),
              ],
            ),
          ),
        ),
        _StepKey(
          label: '+',
          semantics: 'Ajouter un point de vie personnel',
          fill: _gainStep,
          foreground: _gainInk,
          width: 56,
          height: double.infinity,
          onStep: () {
            controller.addLife(player.id, 1);
            buzz(haptic);
          },
        ),
      ],
    );
  }
}

class _BandHeader extends StatelessWidget {
  const _BandHeader({
    required this.controller,
    required this.player,
    required this.color,
    required this.active,
    required this.haptic,
    required this.startLife,
    required this.showTips,
    this.ownLife = true,
  });

  final GameController controller;
  final Player player;
  final Color color;
  final bool active;
  final bool haptic;
  final int startLife;
  final bool showTips;
  final bool ownLife;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final button = constraints.maxWidth < 210
            ? 32.0
            : constraints.maxWidth < 280
            ? 36.0
            : 44.0;
        return Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: active ? color : color.withValues(alpha: 0.45),
              child: Text(
                playerInitial(player.name),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: () => showPlayerSheet(
                  context,
                  controller,
                  player.id,
                  tips: showTips,
                ),
                child: Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
            if (ownLife) ...[
              Flexible(
                flex: 2,
                child: HelpTip(
                  enabled: showTips,
                  title: 'Mes PV',
                  message:
                      'Ta vie, rien que la tienne. − enlève un point, '
                      '+ en rend un. Le gros compteur plus bas change '
                      'les joueurs choisis avec leur badge.',
                  child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Mes PV',
                        style: TextStyle(
                          fontSize: 9,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: color.withValues(alpha: 0.9),
                        ),
                      ),
                      DangerLifeDisplay(
                        life: player.life,
                        startingLife: startLife,
                        compact: true,
                        tight: true,
                        fontSize: 32,
                        lifeKey: ValueKey('life-pad-${player.id}-${player.id}'),
                        onTap: () => showAmountSheet(
                          context,
                          title: 'Mes PV',
                          subtitle: '− enlève un point, + le rend.',
                          listenable: controller,
                          current: () =>
                              controller.playerById(player.id).life,
                          onDelta: (delta) =>
                              controller.addLife(player.id, delta),
                          onSet: (value) =>
                              controller.setLife(player.id, value),
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ),
              _StepKey(
                label: '−',
                semantics: 'Enlever un point de vie personnel',
                fill: const Color(0xFF5C2432),
                foreground: const Color(0xFFFFE4E8),
                width: button,
                height: button,
                onStep: () {
                  controller.addLife(player.id, -1);
                  buzz(haptic);
                },
              ),
              _StepKey(
                label: '+',
                semantics: 'Ajouter un point de vie personnel',
                fill: _gainStep,
                foreground: _gainInk,
                width: button,
                height: button,
                onStep: () {
                  controller.addLife(player.id, 1);
                  buzz(haptic);
                },
              ),
            ],
            _PaneButton(player: player, size: button, showTips: showTips),
            HelpTip(
              enabled: showTips,
              longPress: false,
              title: tipGear.title,
              message: tipGear.message,
              child: RepeatTap(
                repeat: false,
                onTick: () => showCountersSheet(
                  context,
                  controller,
                  player.id,
                  tips: showTips,
                ),
                child: SizedBox(
                  width: button,
                  height: button,
                  child: const Icon(Icons.settings, size: 22),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TurnConsole extends StatefulWidget {
  const _TurnConsole({
    required this.controller,
    required this.seat,
    required this.color,
    required this.haptic,
    required this.active,
    required this.showStrip,
    required this.showTips,
  });

  final GameController controller;
  final Player seat;
  final Color color;
  final bool haptic;
  final bool active;
  final bool showStrip;
  final bool showTips;

  @override
  State<_TurnConsole> createState() => _TurnConsoleState();
}

class _TurnConsoleState extends State<_TurnConsole> {
  final Set<String> _selected = {};
  bool _zone = false;

  void _togglePlayer(String id) {
    setState(() {
      _zone = false;
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  void _allOpponents(List<Player> opponents) {
    setState(() {
      _zone = false;
      _selected
        ..clear()
        ..addAll(opponents.map((player) => player.id));
    });
  }

  void _toggleZone() {
    setState(() {
      _zone = !_zone;
      if (_zone) _selected.clear();
    });
  }

  void _apply(int delta) {
    final game = widget.controller.game;
    final opponents = [
      for (final player in game.players)
        if (player.id != widget.seat.id) player,
    ];
    final selected = _selected
        .where((id) => opponents.any((player) => player.id == id))
        .toList();
    final targets = _zone
        ? [for (final player in game.players) player.id]
        : selected;
    if (targets.isEmpty) {
      widget.controller.flash('Choisis une cible');
      return;
    }
    widget.controller.addLifeMany(
      targets,
      delta,
      dealtBy: widget.seat.id,
    );
    buzz(widget.haptic);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.controller.game;
    final opponents = [
      for (final player in game.players)
        if (player.id != widget.seat.id) player,
    ];
    final selected = _selected
        .where((id) => opponents.any((player) => player.id == id))
        .toSet();

    final allOn =
        !_zone &&
        opponents.isNotEmpty &&
        selected.length == opponents.length;
    final chosen = _zone
        ? game.players
        : [for (final player in opponents) if (selected.contains(player.id)) player];
    const lifeSemantics = 'Enlever un point au profil choisi';
    const lifeJumpSemantics = 'Enlever cinq points au profil choisi';
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: HelpTip(
                  enabled: widget.showTips,
                  longPress: false,
                  title: 'Adversaires',
                  message:
                      'Choisis un ou plusieurs joueurs. Le compteur affiché '
                      'est le leur. − et + retirent ou rendent le même nombre '
                      'sur chaque compteur sélectionné. Tous adv. = les '
                      'adversaires. Tous = toute la table, toi compris.',
                  child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _ModePill(
                      label: 'Tous adv.',
                      selected: allOn,
                      onTap: () => _allOpponents(opponents),
                    ),
                    const SizedBox(width: 6),
                    _ModePill(
                      label: 'Tous',
                      selected: _zone,
                      onTap: _toggleZone,
                    ),
                    const SizedBox(width: 6),
                    for (final player in opponents)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _TargetPill(
                          label: player.name,
                          initial: playerTag(player.name),
                          color: playerColor(player.color),
                          selected: _zone || selected.contains(player.id),
                          onTap: () => _togglePlayer(player.id),
                        ),
                      ),
                  ],
                  ),
                ),
              ),
              if (widget.active)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: HelpTip(
                    enabled: widget.showTips,
                    title: tipEndTurn.title,
                    message: tipEndTurn.message,
                    child: _EndTurnButton(
                    seatId: widget.seat.id,
                    haptic: widget.haptic,
                    onPressed: () {
                      endPlayerTurn(context, widget.controller);
                      buzz(widget.haptic);
                    },
                    compact: true,
                  ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final stack = box.maxWidth < 300 && box.maxHeight >= 100;
              return Row(
            children: [
              HelpTip(
                enabled: widget.showTips,
                longPress: false,
                title: 'Points du profil choisi',
                message:
                    '− retire 1, −5 retire 5, sur le compteur de chaque '
                    'joueur sélectionné. 30, 35 et 39 moins 5 deviennent '
                    '25, 30 et 34.',
                child: _JumpPair(
                  stepLabel: '−',
                  jumpLabel: '−5',
                  stepSemantics: lifeSemantics,
                  jumpSemantics: lifeJumpSemantics,
                  fill: const Color(0xFF5C2432),
                  jumpFill: const Color(0xFF421824),
                  foreground: const Color(0xFFFFE4E8),
                  onStep: () => _apply(-1),
                  onJump: () => _apply(-5),
                  stack: stack,
                ),
              ),
              Expanded(
                child: _ChosenLife(
                  controller: widget.controller,
                  seatId: widget.seat.id,
                  chosen: chosen,
                ),
              ),
              HelpTip(
                enabled: widget.showTips,
                longPress: false,
                title: 'Points du profil choisi',
                message:
                    '+ rend 1, +5 rend 5, sur le compteur de chaque '
                    'joueur sélectionné, sans les aligner sur le même total.',
                child: _JumpPair(
                  stepLabel: '+',
                  jumpLabel: '+5',
                  stepSemantics: 'Ajouter un point au profil choisi',
                  jumpSemantics: 'Ajouter cinq points au profil choisi',
                  fill: _gainStep,
                  jumpFill: _gainJump,
                  foreground: _gainInk,
                  onStep: () => _apply(1),
                  onJump: () => _apply(5),
                  stack: stack,
                ),
              ),
            ],
              );
            },
          ),
        ),
        if (widget.showStrip)
          _BandCmdStrip(
            controller: widget.controller,
            seat: widget.seat,
            haptic: widget.haptic,
            dealing: true,
            received: false,
            selected: selected,
            zone: _zone,
            showTips: widget.showTips,
          ),
      ],
    );
  }
}

class _ChosenLife extends StatelessWidget {
  const _ChosenLife({
    required this.controller,
    required this.seatId,
    required this.chosen,
  });

  final GameController controller;
  final String seatId;
  final List<Player> chosen;

  @override
  Widget build(BuildContext context) {
    if (chosen.isEmpty) {
      return const Text(
        'Choisis un joueur',
        maxLines: 2,
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      );
    }
    if (chosen.length > 1) {
      return ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final player in chosen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _OneLife(
                controller: controller,
                seatId: seatId,
                player: player,
                fontSize: 28,
              ),
            ),
        ],
      );
    }
    return _OneLife(
      controller: controller,
      seatId: seatId,
      player: chosen.first,
      fontSize: 42,
    );
  }
}

class _OneLife extends StatelessWidget {
  const _OneLife({
    required this.controller,
    required this.seatId,
    required this.player,
    required this.fontSize,
  });

  final GameController controller;
  final String seatId;
  final Player player;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final color = playerColor(player.color);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 8,
                backgroundColor: color,
                child: Text(
                  playerTag(player.name),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                player.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          DangerLifeDisplay(
            life: player.life,
            startingLife: player.startingLifeFor(controller.game),
            compact: true,
            tight: true,
            fontSize: fontSize,
            lifeKey: ValueKey('life-pad-$seatId-${player.id}'),
            onTap: () => showAmountSheet(
              context,
              title: player.name,
              subtitle: player.id == seatId
                  ? 'Tes points. − enlève, + rend.'
                  : 'Points de ce joueur. − enlève, + rend.',
              listenable: controller,
              current: () => controller.playerById(player.id).life,
              onDelta: (delta) => controller.addLife(player.id, delta),
              onSet: (value) => controller.setLife(player.id, value),
            ),
          ),
        ],
      ),
    );
  }
}

class _EndTurnButton extends StatelessWidget {
  const _EndTurnButton({
    required this.seatId,
    required this.haptic,
    required this.onPressed,
    this.compact = false,
  });

  final String seatId;
  final bool haptic;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: ValueKey('fin-de-tour-$seatId'),
      style: FilledButton.styleFrom(
        minimumSize: Size(compact ? 44 : 48, compact ? 44 : 40),
        maximumSize: compact ? const Size(88, 44) : null,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
      ),
      onPressed: onPressed,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: const Text(
          'Fin de tour',
          maxLines: 1,
        ),
      ),
    );
  }
}

class _TargetPill extends StatelessWidget {
  const _TargetPill({
    required this.label,
    required this.initial,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String initial;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepeatTap(
      repeat: false,
      onTick: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? color : Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color, width: selected ? 0 : 1.4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: selected ? Colors.black.withValues(alpha: 0.25) : color,
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 84),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: selected ? Colors.black : Colors.white,
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

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepeatTap(
      repeat: false,
      onTick: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? accent : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JumpPair extends StatelessWidget {
  const _JumpPair({
    required this.stepLabel,
    required this.jumpLabel,
    required this.stepSemantics,
    required this.jumpSemantics,
    required this.fill,
    required this.jumpFill,
    required this.foreground,
    required this.onStep,
    required this.onJump,
    this.stack = false,
  });

  final String stepLabel;
  final String jumpLabel;
  final String stepSemantics;
  final String jumpSemantics;
  final Color fill;
  final Color jumpFill;
  final Color foreground;
  final VoidCallback onStep;
  final VoidCallback onJump;
  final bool stack;

  @override
  Widget build(BuildContext context) {
    final step = _StepKey(
      label: stepLabel,
      semantics: stepSemantics,
      fill: fill,
      foreground: foreground,
      width: stack ? 46 : 44,
      height: double.infinity,
      fontSize: stack ? 26 : 32,
      onStep: onStep,
    );
    final jump = _StepKey(
      label: jumpLabel,
      semantics: jumpSemantics,
      fill: jumpFill,
      foreground: foreground,
      width: stack ? 46 : 40,
      height: stack ? 32 : double.infinity,
      fontSize: 15,
      onStep: onJump,
    );
    if (stack) {
      return SizedBox(
        width: 46,
        child: Column(
          children: [
            Expanded(child: step),
            const SizedBox(height: 4),
            jump,
          ],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        step,
        const SizedBox(width: 4),
        jump,
      ],
    );
  }
}

class _JumpKey extends StatelessWidget {
  const _JumpKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepeatTap(
      onTick: onTap,
      child: SizedBox(
        height: 36,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

class _DefeatOverlay extends StatelessWidget {
  const _DefeatOverlay({
    required this.title,
    required this.reason,
    required this.onRevive,
  });

  final String title;
  final String reason;
  final VoidCallback onRevive;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: onRevive,
                child: const Text('Revenir à la table'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
