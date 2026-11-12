import 'package:mtg_table/domain/models.dart';

class LifePoint {
  const LifePoint(this.step, this.life);

  final int step;
  final int life;
}

/// Points de vie dans l’ordre de la partie. Le journal est stocké du plus récent
/// au plus ancien.
Map<String, List<LifePoint>> lifeSeries(Game game, List<LifeChange> log) {
  final series = <String, List<LifePoint>>{
    for (final player in game.players)
      player.id: [LifePoint(0, player.startingLifeFor(game))],
  };
  final ordered = [
    for (final change in log.reversed)
      if (!change.retracted && change.from != change.to) change,
  ];
  for (var i = 0; i < ordered.length; i++) {
    final change = ordered[i];
    series.putIfAbsent(change.playerId, () => [LifePoint(0, change.from)]);
    series[change.playerId]!.add(LifePoint(i + 1, change.to));
  }
  return series;
}
