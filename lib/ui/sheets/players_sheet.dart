import 'package:flutter/material.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/widgets/name_dialog.dart';

Future<void> showPlayersSheet(BuildContext context, GameController controller) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: PlayersSheet(controller: controller),
      );
    },
  );
}

class PlayersSheet extends StatelessWidget {
  const PlayersSheet({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final game = controller.game;
        final count = game.players.length;
        final minPlayers = game.sharedLife ? 2 : 1;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const Text(
              'Joueurs à table',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              game.sharedLife
                  ? 'Vie partagée : le nombre reste pair.'
                  : 'Changez le nombre sans quitter la partie.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var n = minPlayers; n <= maxTablePlayers; n++)
                  if (!game.sharedLife || n.isEven)
                    ChoiceChip(
                      label: Text('$n'),
                      selected: count == n,
                      onSelected: (_) => controller.setPlayerCount(n),
                    ),
              ],
            ),
            const SizedBox(height: 16),
            for (final player in game.players)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: playerColor(player.color),
                  child: Text(
                    playerInitial(player.name),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(player.name),
                subtitle: Text('${player.life} PV'),
                trailing: IconButton(
                  tooltip: 'Retirer',
                  onPressed: count <= minPlayers
                      ? null
                      : () => controller.removePlayer(player.id),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                onTap: () async {
                  final name = await askName(
                    context,
                    title: 'Nom du joueur',
                    initial: player.name,
                  );
                  if (name == null) return;
                  controller.renamePlayer(player.id, name);
                },
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: count >= maxTablePlayers
                    ? null
                    : () => controller.addPlayer(),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Ajouter un joueur'),
              ),
            ),
          ],
        );
      },
    );
  }
}
