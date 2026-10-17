import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/theme/app_theme.dart';

Future<void> showDiceSheet(BuildContext context, GameController controller) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: DiceSheet(controller: controller),
      );
    },
  );
}

class DiceSheet extends StatefulWidget {
  const DiceSheet({super.key, required this.controller});

  final GameController controller;

  @override
  State<DiceSheet> createState() => _DiceSheetState();
}

class _DiceSheetState extends State<DiceSheet> {
  final Random _random = Random();
  int _sides = 20;
  int _count = 1;
  String _result = 'Prêt';
  String _detail = '';

  void _roll() {
    final dice = [for (var i = 0; i < _count; i++) _random.nextInt(_sides) + 1];
    final total = dice.fold<int>(0, (sum, value) => sum + value);
    setState(() {
      _result = '$total';
      _detail = _count == 1
          ? 'd$_sides'
          : '${dice.join(' + ')}  ·  ${_count}d$_sides';
    });
  }

  void _coin() {
    final face = _random.nextBool();
    setState(() {
      _result = face ? 'Pile' : 'Face';
      _detail = 'Pièce';
    });
  }

  void _planar() {
    final roll = _random.nextInt(6);
    if (roll == 0) {
      widget.controller.planeswalk();
      setState(() {
        _result = 'Planeswalk';
        _detail = widget.controller.game.planechase
            ? widget.controller.game.currentPlane
            : 'Dé planaire';
      });
      return;
    }
    if (roll == 1) {
      widget.controller.flash('Chaos — résolvez le phénomène du plan');
      setState(() {
        _result = 'Chaos';
        _detail = 'Résolvez le phénomène du plan en jeu';
      });
      return;
    }
    setState(() {
      _result = 'Vide';
      _detail = 'Dé planaire';
    });
  }

  void _starter() {
    final players = widget.controller.game.players;
    final open = [
      for (var i = 0; i < players.length; i++)
        if (!players[i].conceded) i,
    ];
    if (open.isEmpty) return;
    final index = open[_random.nextInt(open.length)];
    widget.controller.setActive(index);
    setState(() {
      _result = players[index].name;
      _detail = 'Commence';
    });
  }

  void _highRoll() {
    final players = widget.controller.game.players;
    final rolls = <String>[];
    var best = -1;
    final winners = <int>[];
    for (var i = 0; i < players.length; i++) {
      if (players[i].conceded) continue;
      final value = _random.nextInt(20) + 1;
      rolls.add('${players[i].name} $value');
      if (value > best) {
        best = value;
        winners
          ..clear()
          ..add(i);
      } else if (value == best) {
        winners.add(i);
      }
    }
    setState(() {
      if (winners.length == 1) {
        _result = players[winners.first].name;
        _detail = 'Plus haut dé · $best\n${rolls.join(' · ')}';
        widget.controller.setActive(winners.first);
      } else {
        _result = 'Égalité';
        _detail = rolls.join(' · ');
      }
    });
  }

  void _randomOpponent() {
    final players = widget.controller.game.players;
    final active = players[widget.controller.game.activeIndex].id;
    final open = [
      for (final player in players)
        if (!player.conceded && player.id != active) player,
    ];
    if (open.isEmpty) {
      setState(() {
        _result = '—';
        _detail = 'Pas d’adversaire';
      });
      return;
    }
    final pick = open[_random.nextInt(open.length)];
    setState(() {
      _result = pick.name;
      _detail = 'Adversaire au hasard';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(
          _result,
          textAlign: TextAlign.center,
          style: lifeStyle(64, Colors.white),
        ),
        Text(_detail, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final sides in const [2, 4, 6, 8, 10, 12, 20, 100])
              ChoiceChip(
                label: Text('d$sides'),
                selected: _sides == sides,
                onSelected: (_) => setState(() => _sides = sides),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _count > 1 ? () => setState(() => _count--) : null,
              icon: const Icon(Icons.remove),
            ),
            Text(
              '$_count dé${_count > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 18),
            ),
            IconButton(
              onPressed: _count < 12 ? () => setState(() => _count++) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        FilledButton(onPressed: _roll, child: const Text('Lancer')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton(onPressed: _coin, child: const Text('Pièce')),
            OutlinedButton(
              onPressed: _planar,
              child: const Text('Dé planaire'),
            ),
            OutlinedButton(
              onPressed: _starter,
              child: const Text('Qui commence'),
            ),
            OutlinedButton(
              onPressed: _highRoll,
              child: const Text('Plus haut d20'),
            ),
            OutlinedButton(
              onPressed: _randomOpponent,
              child: const Text('Adversaire au hasard'),
            ),
          ],
        ),
      ],
    );
  }
}
