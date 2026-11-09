import 'package:flutter/material.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/widgets/name_dialog.dart';
import 'package:mtg_table/ui/widgets/repeat_tap.dart';

Future<void> showCountersSheet(
  BuildContext context,
  GameController controller,
  String playerId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: CountersSheet(controller: controller, playerId: playerId),
      );
    },
  );
}

class CountersSheet extends StatelessWidget {
  const CountersSheet({
    super.key,
    required this.controller,
    required this.playerId,
  });

  final GameController controller;
  final String playerId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final player = controller.playerById(playerId);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              player.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Monarque'),
              subtitle: const Text(
                'Un seul à la table. Pioche en fin de tour.',
              ),
              value: controller.game.monarchId == playerId,
              onChanged: (_) => controller.toggleMonarch(playerId),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Initiative'),
              subtitle: const Text('Donjon. Une seule personne à la fois.'),
              value: controller.game.initiativeId == playerId,
              onChanged: (_) => controller.toggleInitiative(playerId),
            ),
            if (controller.game.trackCommanderTax)
              for (final commander in player.commanders)
                _StatRow(
                  label: player.commanders.length == 1
                      ? 'Taxe ${commander.name}'
                      : 'Taxe ${commander.name}',
                  value: commander.tax,
                  onDelta: (delta) =>
                      controller.castCommander(commander.id, delta),
                ),
            const Divider(),
            for (final stat in Stat.values)
              if (stat != Stat.signature ||
                  controller.game.format == MatchFormat.oathbreaker)
                _StatRow(
                  label: stat == Stat.signature
                      ? player.signatureName
                      : statLabel(stat),
                  value: player.readStat(stat),
                  onDelta: (delta) =>
                      controller.bumpStat(playerId, stat, delta),
                  onEdit: stat == Stat.signature
                      ? () async {
                          final name = await askName(
                            context,
                            title: 'Sort signature',
                            initial: player.signatureName,
                          );
                          if (name == null) return;
                          controller.setSignatureName(playerId, name);
                        }
                      : null,
                ),
            _StatRow(
              label: 'Anneau',
              value: player.ring,
              onDelta: (delta) =>
                  controller.setRing(playerId, player.ring + delta),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bénédiction de la Cité'),
              value: player.blessing,
              onChanged: (_) => controller.toggleBlessing(playerId),
            ),
            const Divider(),
            const Text(
              'Mana',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
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
              'Suivis libres',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            for (final counter in player.custom)
              _StatRow(
                label: counter.name,
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
                    hint: 'Ex. expérience de salle, indices…',
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
    this.onDelete,
    this.onEdit,
  });

  final String label;
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
          Expanded(
            child: onEdit == null
                ? Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  )
                : InkWell(
                    onTap: onEdit,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
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
    return SizedBox(
      width: 108,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.7)),
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
