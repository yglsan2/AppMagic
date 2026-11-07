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

class _FirstPlayerDrawState extends State<FirstPlayerDraw>
    with TickerProviderStateMixin {
  final Random _random = Random();
  int? _highlight;
  int? _winner;
  bool _rolling = false;
  late final AnimationController _land;
  late final AnimationController _pulse;

  List<int> get _eligible {
    return [
      for (var i = 0; i < widget.players.length; i++)
        if (!widget.players[i].conceded) i,
    ];
  }

  @override
  void initState() {
    super.initState();
    _land = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _land.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    if (_rolling) return;
    final pool = _eligible;
    if (pool.isEmpty) return;

    _land.value = 0;
    _pulse.repeat(reverse: true);
    setState(() {
      _rolling = true;
      _winner = null;
      _highlight = pool.first;
    });

    final chosen = pool[_random.nextInt(pool.length)];
    final steps = 12 + _random.nextInt(4);
    var cursor = 0;
    for (var step = 0; step < steps; step++) {
      final t = step / steps;
      final wait = (55 + 340 * t * t).round();
      await Future<void>.delayed(Duration(milliseconds: wait));
      if (!mounted) return;
      cursor = (cursor + 1) % pool.length;
      setState(() => _highlight = pool[cursor]);
    }
    var guard = 0;
    while (_highlight != chosen && guard < pool.length) {
      await Future<void>.delayed(const Duration(milliseconds: 240));
      if (!mounted) return;
      cursor = (cursor + 1) % pool.length;
      setState(() => _highlight = pool[cursor]);
      guard++;
    }
    if (!mounted) return;
    _pulse
      ..stop()
      ..value = 0;
    setState(() {
      _highlight = chosen;
      _winner = chosen;
      _rolling = false;
    });
    await _land.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final winner = _winner == null ? null : widget.players[_winner!];
    final spotlight = _highlight == null ? null : widget.players[_highlight!];

    return Scaffold(
      backgroundColor: ink,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: pageGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Qui commence ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: MediaQuery.sizeOf(context).width < 380 ? 26 : 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    _winner != null
                        ? '${winner!.name} commence.'
                        : _rolling && spotlight != null
                        ? spotlight.name
                        : 'Le nom s’arrête sur celui qui joue en premier.',
                    key: ValueKey(_winner ?? (_rolling ? _highlight : 'idle')),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _rolling ? 22 : 15,
                      fontWeight: _rolling ? FontWeight.w800 : FontWeight.w600,
                      color: _rolling
                          ? playerColor(spotlight!.color)
                          : Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final count = widget.players.length;
                      const gap = 8.0;
                      final usable = (constraints.maxHeight - gap * (count - 1))
                          .clamp(0.0, double.infinity);
                      return AnimatedBuilder(
                        animation: Listenable.merge([_land, _pulse]),
                        builder: (context, _) {
                          final grow = _winner == null ? 0.0 : _land.value;
                          final weights = [
                            for (var i = 0; i < count; i++)
                              _winner == i ? 1 + 1.2 * grow : 1.0,
                          ];
                          final sum = weights.fold<double>(
                            0,
                            (total, weight) => total + weight,
                          );
                          return Column(
                            children: [
                              for (var index = 0; index < count; index++) ...[
                                SizedBox(
                                  height: sum == 0
                                      ? 0
                                      : usable * weights[index] / sum,
                                  child: _SeatTile(
                                    player: widget.players[index],
                                    active: _highlight == index,
                                    won: _winner == index,
                                    rolling: _rolling,
                                    settled: _winner != null,
                                    land: _land,
                                    pulse: _pulse,
                                  ),
                                ),
                                if (index != count - 1)
                                  const SizedBox(height: gap),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
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
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.player,
    required this.active,
    required this.won,
    required this.rolling,
    required this.settled,
    required this.land,
    required this.pulse,
  });

  final Player player;
  final bool active;
  final bool won;
  final bool rolling;
  final bool settled;
  final Animation<double> land;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final color = playerColor(player.color);
    return AnimatedBuilder(
      animation: Listenable.merge([land, pulse]),
      builder: (context, _) {
        final beat = active && rolling ? pulse.value : 0.0;
        final pop = won ? Curves.elasticOut.transform(land.value) : 0.0;
        final scale = won
            ? 0.9 + 0.14 * pop
            : active && rolling
            ? 1 + 0.035 * beat
            : 1.0;
        return Opacity(
          opacity: !settled || won ? 1 : 0.38,
          child: Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  color.withValues(
                    alpha: won
                        ? 0.62
                        : active
                        ? 0.34 + 0.18 * beat
                        : 0.12,
                  ),
                  panelInk,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: won || active ? color : color.withValues(alpha: 0.28),
                  width: won
                      ? 2.6
                      : active
                      ? 2
                      : 1,
                ),
                boxShadow: active || won
                    ? [
                        BoxShadow(
                          color: color.withValues(
                            alpha: won ? 0.45 : 0.16 + 0.3 * beat,
                          ),
                          blurRadius: won ? 28 : 12 + 18 * beat,
                          spreadRadius: won ? 1 : 0,
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
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
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                    if (won)
                      const Text(
                        'Commence',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      )
                    else if (active && rolling)
                      Icon(Icons.casino, color: color),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
