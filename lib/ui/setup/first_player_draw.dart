import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';

class FirstPlayerDraw extends StatefulWidget {
  const FirstPlayerDraw({
    super.key,
    required this.players,
    required this.onPicked,
    required this.onSkip,
  });

  final List<Player> players;
  final ValueChanged<int> onPicked;
  final VoidCallback onSkip;

  @override
  State<FirstPlayerDraw> createState() => _FirstPlayerDrawState();
}

class _FirstPlayerDrawState extends State<FirstPlayerDraw> {
  final Random _random = Random();
  int? _highlight;
  int? _winner;
  bool _rolling = false;

  List<int> get _eligible {
    return [
      for (var i = 0; i < widget.players.length; i++)
        if (!widget.players[i].conceded) i,
    ];
  }

  Future<void> _draw() async {
    if (_rolling) return;
    final pool = _eligible;
    if (pool.isEmpty) return;

    setState(() {
      _rolling = true;
      _winner = null;
      _highlight = pool.first;
    });

    final chosen = pool[_random.nextInt(pool.length)];
    // Roulette courte : on tourne parmi les joueurs, puis on s'arrête.
    for (var step = 0; step < 14 + _random.nextInt(6); step++) {
      await Future<void>.delayed(Duration(milliseconds: 60 + step * 18));
      if (!mounted) return;
      setState(() => _highlight = pool[step % pool.length]);
    }
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    setState(() {
      _highlight = chosen;
      _winner = chosen;
      _rolling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final winner = _winner == null ? null : widget.players[_winner!];
    final winnerColor = winner == null ? null : playerColor(winner.color);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              const Text(
                'Qui commence ?',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _winner == null
                    ? 'Un joueur est tiré au sort. Appuyez sur le bouton, puis validez.'
                    : '${winner!.name} commence la partie.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 20),
              if (_winner != null) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      winnerColor!.withValues(alpha: 0.35),
                      panelInk,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: winnerColor, width: 3),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: winnerColor,
                        child: Text(
                          playerInitial(winner!.name),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        winner.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'Commence',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: ListView.separated(
                  itemCount: widget.players.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final player = widget.players[index];
                    final color = playerColor(player.color);
                    final active = _highlight == index;
                    final won = _winner == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          color.withValues(
                            alpha: won
                                ? 0.4
                                : active
                                ? 0.28
                                : 0.12,
                          ),
                          panelInk,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: won || active
                              ? color
                              : color.withValues(alpha: 0.25),
                          width: won ? 2.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: color,
                            child: Text(
                              playerInitial(player.name),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              player.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (won)
                            const Text(
                              '✓',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          else if (active && _rolling)
                            Icon(Icons.casino, color: color),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (_winner == null)
                FilledButton(
                  onPressed: _rolling ? null : _draw,
                  child: Text(_rolling ? 'Tirage…' : 'Tirer au sort'),
                )
              else ...[
                FilledButton(
                  onPressed: () => widget.onPicked(_winner!),
                  child: Text('C’est parti · ${winner!.name}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _rolling ? null : _draw,
                  child: const Text('Retirer'),
                ),
              ],
              TextButton(
                onPressed: _rolling ? null : widget.onSkip,
                child: const Text('Passer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
