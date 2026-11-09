import 'package:flutter/material.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/widgets/handicap_picker.dart';
import 'package:mtg_table/ui/widgets/name_dialog.dart';

Future<void> showPlayerSheet(
  BuildContext context,
  GameController controller,
  String playerId, {
  bool tips = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: PlayerSheet(
            controller: controller,
            playerId: playerId,
            tips: tips,
          ),
        ),
      );
    },
  );
}

class PlayerSheet extends StatelessWidget {
  const PlayerSheet({
    super.key,
    required this.controller,
    required this.playerId,
    this.tips = false,
  });

  final GameController controller;
  final String playerId;
  final bool tips;

  String _clockLabel(int ms) {
    final total = (ms / 1000).floor().clamp(0, 99 * 3600);
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final player = controller.playerById(playerId);
        final game = controller.game;
        final color = playerColor(player.color);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Retour',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      player.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: color,
                        child: Text(
                          playerInitial(player.name),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Couleur · nom · commandants',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final name = await askName(
                            context,
                            title: 'Nom du joueur',
                            initial: player.name,
                          );
                          if (name == null) return;
                          controller.renamePlayer(playerId, name);
                        },
                        child: const Text('Renommer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < playerPalette.length; i++)
                        GestureDetector(
                          onTap: () => controller.setColor(playerId, i),
                          child: CircleAvatar(
                            radius: player.color % playerPalette.length == i
                                ? 18
                                : 14,
                            backgroundColor: playerPalette[i],
                            child: player.color % playerPalette.length == i
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.black,
                                    size: 18,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                  if (game.tracksCommanders) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Commandants',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        if (player.commanders.length > 1)
                          IconButton.filledTonal(
                            key: ValueKey('cmd-remove-$playerId'),
                            tooltip: 'Retirer le dernier',
                            onPressed: () =>
                                controller.removeLastCommander(playerId),
                            icon: const Icon(Icons.person_remove),
                          ),
                        if (player.commanders.length < 4)
                          IconButton.filled(
                            key: ValueKey('cmd-add-$playerId'),
                            tooltip: 'Ajouter',
                            onPressed: () async {
                              final name = await askName(
                                context,
                                title: 'Nouveau commandant',
                                hint: 'Partenaire, compagnon…',
                              );
                              if (name == null) return;
                              controller.addCommander(playerId, name);
                            },
                            icon: const Icon(Icons.person_add),
                          ),
                      ],
                    ),
                    Text(
                      'Chaque commandant a son compteur sur la table. '
                      '− = dégât · + = corriger.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final commander in player.commanders)
                      Card(
                        color: const Color(0xFF12151C),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            commander.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            'Taxe +${commander.tax} · ${commander.casts} lancers',
                          ),
                          trailing: player.commanders.length > 1
                              ? IconButton(
                                  tooltip: 'Retirer',
                                  onPressed: () =>
                                      controller.removeCommander(commander.id),
                                  icon: const Icon(Icons.delete_outline),
                                )
                              : null,
                          onTap: () async {
                            final name = await askName(
                              context,
                              title: 'Nom du commandant',
                              initial: commander.name,
                            );
                            if (name == null) return;
                            controller.renameCommander(commander.id, name);
                          },
                        ),
                      ),
                  ],
                  if (!game.sharedLife) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Handicaps de deck (table)'),
                      subtitle: const Text(
                        'Ajuste les PV de départ selon le niveau du deck.',
                      ),
                      value: game.handicapsEnabled,
                      onChanged: controller.setHandicapsEnabled,
                    ),
                    if (game.handicapsEnabled) ...[
                      Text(
                        'Niveau · ${player.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      HandicapPicker(
                        tips: tips,
                        bracket: player.deckBracket,
                        lifeDelta: player.handicapLifeDelta,
                        baseLife: game.startingLife,
                        onChanged: (bracket, delta) =>
                            controller.setDeckHandicap(
                              playerId,
                              bracket: bracket,
                              lifeDelta: delta,
                            ),
                      ),
                    ],
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hors de la partie'),
                    subtitle: const Text(
                      'Concession. La vie et les dégâts restent visibles.',
                    ),
                    value: player.conceded,
                    onChanged: (value) =>
                        controller.setConceded(playerId, value),
                  ),
                  if (game.archenemy)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Archennemi (Archenemy)'),
                      value: game.archenemyId == player.id,
                      onChanged: (value) {
                        controller.setArchenemy(value ? playerId : null);
                      },
                    ),
                  if (game.format == MatchFormat.treachery &&
                      player.treacheryRole != TreacheryRole.none) ...[
                    const SizedBox(height: 8),
                    Text(
                      player.treacheryRevealed
                          ? 'Rôle révélé · ${treacheryRoleLabel(player.treacheryRole)}'
                          : 'Rôle Traîtrise (secret)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(player.name),
                                  content: Text(
                                    treacheryRoleLabel(player.treacheryRole),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('Voir (privé)'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: player.treacheryRevealed
                                ? null
                                : () {
                                    controller.revealTreachery(playerId);
                                  },
                            child: Text(
                              player.treacheryRevealed
                                  ? 'Déjà révélé'
                                  : 'Révéler',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (game.format == MatchFormat.oathbreaker) ...[
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sort signature'),
                      subtitle: Text(player.signatureName),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () async {
                        final name = await askName(
                          context,
                          title: 'Sort signature',
                          initial: player.signatureName,
                          hint: 'Ex. Lightning Bolt',
                        );
                        if (name == null) return;
                        controller.setSignatureName(playerId, name);
                      },
                    ),
                  ],
                  if (game.timersEnabled &&
                      game.timerMode == TimerMode.chess) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Banque · ${_clockLabel(player.clockBankMs)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => controller.addClockBank(
                            playerId,
                            const Duration(seconds: -30),
                          ),
                          child: const Text('−30 s'),
                        ),
                        OutlinedButton(
                          onPressed: () => controller.addClockBank(
                            playerId,
                            const Duration(seconds: 30),
                          ),
                          child: const Text('+30 s'),
                        ),
                        OutlinedButton(
                          onPressed: () => controller.addClockBank(
                            playerId,
                            const Duration(minutes: 1),
                          ),
                          child: const Text('+1 min'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check),
                    label: const Text('Retour à la table'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
