import 'package:flutter/material.dart';
import 'package:mtg_table/domain/dungeons.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/help/option_help.dart';
import 'package:mtg_table/ui/widgets/help_tip.dart';
import 'package:mtg_table/ui/widgets/name_dialog.dart';
import 'package:mtg_table/ui/widgets/option_glyphs.dart';
import 'package:mtg_table/ui/widgets/repeat_tap.dart';

Future<void> showCountersSheet(
  BuildContext context,
  GameController controller,
  String playerId, {
  bool tips = false,
}) {
  return presentForSeat<void>(
    context,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: CountersSheet(
          controller: controller,
          playerId: playerId,
          tips: tips,
        ),
      );
    },
  );
}

class CountersSheet extends StatelessWidget {
  const CountersSheet({
    super.key,
    required this.controller,
    required this.playerId,
    this.tips = false,
  });

  final GameController controller;
  final String playerId;
  final bool tips;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final player = controller.playerById(playerId);
        final tips = this.tips;
        Widget bubble(OptionTip tip, Widget child) {
          if (!tips) return child;
          return HelpTip(
            title: tip.title,
            message: tip.message,
            showIcon: true,
            child: child,
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              player.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (controller.game.trackCommanderTax)
              for (final commander in player.commanders)
                _StatRow(
                  label: 'Taxe ${commander.name}',
                  note: 'Taxe de commandement : +2 à chaque lancement.',
                  tip: tips ? tipTax : null,
                  mark: OptionMarkKind.tax,
                  value: commander.tax,
                  onDelta: (delta) =>
                      controller.castCommander(commander.id, delta),
                ),
            _StatRow(
              label: statLabel(Stat.poison),
              note:
                  'À ${controller.game.poisonThreshold} marqueurs, défaite. '
                  'Ce n’est pas une perte de vie.',
              tip: tips ? tipPoison(controller.game.poisonThreshold) : null,
              mark: OptionMarkKind.poison,
              danger: player.readStat(Stat.poison) >=
                      controller.game.poisonThreshold - 1 &&
                  player.readStat(Stat.poison) > 0,
              value: player.readStat(Stat.poison),
              onDelta: (delta) =>
                  controller.bumpStat(playerId, Stat.poison, delta),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  OptionMark(
                    kind: OptionMarkKind.crown,
                    lit: controller.game.monarchId == playerId,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: bubble(tipMonarch, const Text('Monarque'))),
                ],
              ),
              subtitle: const Text(
                'Un seul à la table. Pioche au début de son étape de fin. '
                'Les dégâts de combat le transmettent.',
              ),
              value: controller.game.monarchId == playerId,
              onChanged: (_) => controller.toggleMonarch(playerId),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  OptionMark(
                    kind: OptionMarkKind.initiative,
                    lit: controller.game.initiativeId == playerId,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: bubble(tipInitiative, const Text('Initiative')),
                  ),
                ],
              ),
              subtitle: const Text(
                'Une seule personne. Les salles se suivent dessous. '
                'Les dégâts de combat la transmettent.',
              ),
              value: controller.game.initiativeId == playerId,
              onChanged: (_) => controller.toggleInitiative(playerId),
            ),
            _DungeonBlock(controller: controller, player: player),
            for (final stat in statPlayOrder)
              if (stat != Stat.poison &&
                  stat != Stat.rad &&
                  stat != Stat.speed &&
                  stat != Stat.signature)
              _StatRow(
                label: statLabel(stat),
                note: switch (stat) {
                  Stat.storm =>
                    'Sorts déjà lancés ce tour. Remis à zéro en fin de tour.',
                  Stat.treasure => 'Jetons Trésor, sacrifiés pour un mana.',
                  Stat.energy => 'Marqueurs énergie, gagnés et dépensés à la main.',
                  Stat.experience =>
                    'Marqueurs expérience, souvent à la mort d’une créature.',
                  Stat.clue => 'Jeton Indice.',
                  Stat.food => 'Jeton Nourriture.',
                  Stat.blood => 'Jeton Sang.',
                  Stat.trail => 'Jeton Carte, pour l’exploration.',
                  Stat.gold => 'Jeton Or, un mana de n’importe quelle couleur.',
                  Stat.powerstone =>
                    'Jeton Pierre de puissance, un mana incolore, pas un sort.',
                  _ => null,
                },
                tip: tips ? tipForStat(stat, player) : null,
                mark: kindForStat(stat),
                value: player.readStat(stat),
                onDelta: (delta) => controller.bumpStat(playerId, stat, delta),
              ),
            const Divider(),
            bubble(
              tipMana,
              const Text(
                'Mana',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mana flottant. Vidé en fin de tour si le réglage est actif.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in manaKeys)
                  _ManaPip(
                    symbol: key,
                    value: player.mana[key] ?? 0,
                    onDelta: (delta) =>
                        controller.bumpMana(playerId, key, delta),
                  ),
              ],
            ),
            const Divider(),
            const Text(
              'Plus rares',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            const Text(
              'Toujours dans les règles, simplement moins vus à la table.',
            ),
            _StatRow(
              label: 'Anneau',
              note: 'Nombre de tentations. Le dernier palier est à 4.',
              tip: tips ? tipRing : null,
              mark: OptionMarkKind.ring,
              level: player.ring,
              value: player.ring,
              onDelta: (delta) =>
                  controller.setRing(playerId, player.ring + delta),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  OptionMark(
                    kind: OptionMarkKind.blessing,
                    lit: player.blessing,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: bubble(
                      tipBlessing,
                      const Text('Bénédiction de la Cité'),
                    ),
                  ),
                ],
              ),
              subtitle: const Text(
                'Une fois obtenue, elle reste pour la partie.',
              ),
              value: player.blessing,
              onChanged: player.blessing
                  ? null
                  : (_) => controller.toggleBlessing(playerId),
            ),
            for (final stat in [Stat.rad, Stat.speed])
              _StatRow(
                label: statLabel(stat),
                note: stat == Stat.speed
                    ? 'De 0 à 4. Une seule hausse par tour.'
                    : 'Rappel au début du tour : meule, puis retire 1 à la main.',
                tip: tips ? tipForStat(stat, player) : null,
                mark: kindForStat(stat),
                value: player.readStat(stat),
                onDelta: (delta) => controller.bumpStat(playerId, stat, delta),
              ),
            if (controller.game.format == MatchFormat.oathbreaker)
              _StatRow(
                label: player.signatureName,
                note:
                    'Sort signature. Surcoût actuel : ${player.signatureCasts * 2}.',
                tip: tips ? tipSignature : null,
                mark: OptionMarkKind.signature,
                value: player.readStat(Stat.signature),
                onDelta: (delta) =>
                    controller.bumpStat(playerId, Stat.signature, delta),
                onEdit: () async {
                  final name = await askName(
                    context,
                    title: 'Sort signature',
                    initial: player.signatureName,
                  );
                  if (name == null) return;
                  controller.setSignatureName(playerId, name);
                },
              ),
            const Divider(),
            bubble(
              tipCustom,
              const Text(
                'Suivis libres',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            for (final counter in player.custom)
              _StatRow(
                label: counter.name,
                tip: tips ? OptionTip(counter.name, tipCustom.message) : null,
                mark: OptionMarkKind.letter,
                letter: counter.name.trim().isEmpty
                    ? '?'
                    : counter.name.trim().substring(0, 1).toUpperCase(),
                value: counter.value,
                onDelta: (delta) =>
                    controller.bumpCustom(playerId, counter.id, delta),
                onDelete: () => controller.removeCustom(playerId, counter.id),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final name = await askName(
                    context,
                    title: 'Nouveau suivi',
                    hint: 'Ex. indices, nourriture, sang…',
                  );
                  if (name == null) return;
                  controller.addCustom(playerId, name);
                },
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un suivi'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.onDelta,
    this.note,
    this.tip,
    this.mark,
    this.level,
    this.letter,
    this.danger = false,
    this.onDelete,
    this.onEdit,
  });

  final String label;
  final String? note;
  final OptionTip? tip;
  final OptionMarkKind? mark;
  final int? level;
  final String? letter;
  final bool danger;
  final int value;
  final void Function(int delta) onDelta;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (mark != null) ...[
            OptionMark(
              kind: mark!,
              lit: value != 0,
              danger: danger,
              level: level,
              letter: letter,
              size: 36,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: onEdit == null
                ? _explained(label: label, note: note, tip: tip)
                : InkWell(
                    onTap: onEdit,
                    child: Row(
                      children: [
                        Flexible(
                          child: _explained(label: label, note: note, tip: tip),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
          ),
          RepeatTap(
            onTick: () => onDelta(-1),
            child: const _RoundIcon(icon: Icons.remove),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: lifeStyle(22, Colors.white),
            ),
          ),
          RepeatTap(
            onTick: () => onDelta(1),
            child: const _RoundIcon(icon: Icons.add),
          ),
          if (onDelete != null)
            IconButton(onPressed: onDelete, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

Widget _explained({
  required String label,
  required String? note,
  required OptionTip? tip,
}) {
  final text = _StatLabel(label: label, note: note);
  if (tip == null) return text;
  return HelpTip(
    title: tip.title,
    message: tip.message,
    showIcon: true,
    child: text,
  );
}

class _StatLabel extends StatelessWidget {
  const _StatLabel({required this.label, this.note});

  final String label;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (note != null)
          Text(
            note!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          shape: BoxShape.circle,
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _ManaPip extends StatelessWidget {
  const _ManaPip({
    required this.symbol,
    required this.value,
    required this.onDelta,
  });

  final String symbol;
  final int value;
  final void Function(int delta) onDelta;

  @override
  Widget build(BuildContext context) {
    final color = manaPalette[symbol] ?? Colors.white;
    final lit = value > 0;
    return SizedBox(
      width: 108,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: lit ? 0.22 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: lit ? 0.9 : 0.28),
          ),
          boxShadow: lit
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            RepeatTap(
              onTick: () => onDelta(-1),
              child: const SizedBox(
                width: 44,
                height: 48,
                child: Icon(Icons.remove),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    symbol,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '$value',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            RepeatTap(
              onTick: () => onDelta(1),
              child: const SizedBox(
                width: 44,
                height: 48,
                child: Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DungeonBlock extends StatelessWidget {
  const _DungeonBlock({required this.controller, required this.player});

  final GameController controller;
  final Player player;

  @override
  Widget build(BuildContext context) {
    final dungeon = dungeonById(player.dungeonId);
    final room = dungeon?.room(player.roomId ?? '');
    if (dungeon == null || room == null) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final def in dungeons)
            OutlinedButton(
              onPressed: () => controller.enterDungeon(player.id, def.id),
              child: Text(def.name),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${dungeon.name} · ${room.name}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(room.hint),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final exit in room.exits)
              FilledButton(
                onPressed: () => controller.venture(player.id, exit),
                child: Text(dungeon.room(exit)?.name ?? exit),
              ),
            if (room.finished)
              TextButton(
                onPressed: () => controller.leaveDungeon(player.id),
                child: const Text('Recommencer'),
              ),
          ],
        ),
      ],
    );
  }
}
