import 'package:flutter/material.dart';
import 'package:mtg_table/domain/life_series.dart';
import 'package:mtg_table/domain/models.dart';

class LifeGraph extends StatelessWidget {
  const LifeGraph({super.key, required this.game, required this.log});

  final Game game;
  final List<LifeChange> log;

  @override
  Widget build(BuildContext context) {
    final series = lifeSeries(game, log);
    final anyMove = series.values.any((points) => points.length > 1);
    if (!anyMove) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Points de vie',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: CustomPaint(
            painter: _LifePainter(game: game, series: series),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final player in game.players)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    color: Color(player.color),
                  ),
                  const SizedBox(width: 6),
                  Text(player.name),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _LifePainter extends CustomPainter {
  _LifePainter({required this.game, required this.series});

  final Game game;
  final Map<String, List<LifePoint>> series;

  @override
  void paint(Canvas canvas, Size size) {
    var maxStep = 1;
    var minLife = game.startingLife;
    var maxLife = game.startingLife;
    for (final points in series.values) {
      for (final point in points) {
        if (point.step > maxStep) maxStep = point.step;
        if (point.life < minLife) minLife = point.life;
        if (point.life > maxLife) maxLife = point.life;
      }
    }
    if (maxLife == minLife) {
      maxLife += 1;
      minLife -= 1;
    }
    final axis = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 1), Offset(size.width, size.height - 1), axis);
    for (final player in game.players) {
      final points = series[player.id];
      if (points == null || points.length < 2) continue;
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final x = size.width * points[i].step / maxStep;
        final y = size.height * (1 - (points[i].life - minLife) / (maxLife - minLife));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Color(player.color)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LifePainter oldDelegate) => true;
}
