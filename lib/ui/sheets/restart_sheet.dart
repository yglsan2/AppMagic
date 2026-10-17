import 'package:flutter/material.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/setup/first_player_draw.dart';

enum RestartKind { zero, rematch }

Future<void> showRestartSheet(
  BuildContext context, {
  required GameController controller,
  RestartKind initial = RestartKind.rematch,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _RestartSheet(controller: controller, initial: initial),
  );
}

class _RestartSheet extends StatelessWidget {
  const _RestartSheet({required this.controller, required this.initial});

  final GameController controller;
  final RestartKind initial;

  Future<void> _afterWipe(BuildContext context) async {
    if (!context.mounted) return;
    final choice = await showModalBottomSheet<_StartChoice>(
      context: context,
      builder: (context) => const _WhoStartsSheet(),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case _StartChoice.keep:
        break;
      case _StartChoice.shuffle:
        controller.shuffleSeats();
        if (!context.mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => FirstPlayerDraw(
              players: controller.game.players,
              onPicked: (index) {
                controller.setActive(index);
                Navigator.of(context).pop();
              },
              onSkip: () => Navigator.of(context).pop(),
            ),
          ),
        );
      case _StartChoice.draw:
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => FirstPlayerDraw(
              players: controller.game.players,
              onPicked: (index) {
                controller.setActive(index);
                Navigator.of(context).pop();
              },
              onSkip: () => Navigator.of(context).pop(),
            ),
          ),
        );
      case _StartChoice.pick:
        final index = await showModalBottomSheet<int>(
          context: context,
          builder: (context) => _PickStarterSheet(controller: controller),
        );
        if (index != null) controller.setActive(index);
    }
  }

  Future<void> _run(BuildContext context, RestartKind kind) async {
    Navigator.of(context).pop();
    if (kind == RestartKind.zero) {
      controller.resetRound();
    } else {
      controller.rematch();
    }
    await _afterWipe(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              initial == RestartKind.rematch ? 'Revanche' : 'Remise à zéro',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Les noms, couleurs et commandants restent. '
              'Vies, dégâts, poison et taxes repartent au départ.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _run(context, RestartKind.rematch),
              icon: const Icon(Icons.sports_esports_outlined),
              label: const Text('Revanche'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF2F6B4F),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Manche suivante · sans tirage automatique · vous choisissez qui commence.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _run(context, RestartKind.zero),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Remise à zéro'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tout remettre comme au début (manche 1).',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StartChoice { keep, draw, pick, shuffle }

class _WhoStartsSheet extends StatelessWidget {
  const _WhoStartsSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Qui commence ?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Demandez à la table : perdant d’abord, même ordre, ou nouveau tirage.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, _StartChoice.keep),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Garder l’ordre actuel'),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, _StartChoice.pick),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Choisir un joueur'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, _StartChoice.draw),
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Tirage au sort'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, _StartChoice.shuffle),
              icon: const Icon(Icons.shuffle),
              label: const Text('Mélanger les places puis tirer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickStarterSheet extends StatelessWidget {
  const _PickStarterSheet({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final players = controller.game.players;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Text(
              'Premier joueur',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          for (var i = 0; i < players.length; i++)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: playerColor(players[i].color),
                child: Text(
                  playerInitial(players[i].name),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              title: Text(players[i].name),
              onTap: () => Navigator.pop(context, i),
            ),
        ],
      ),
    );
  }
}
