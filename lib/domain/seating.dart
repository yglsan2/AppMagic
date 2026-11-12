import 'dart:math' as math;

import 'package:mtg_table/domain/models.dart';

class SeatingPlan {
  const SeatingPlan({
    required this.south,
    required this.north,
    this.westTopToBottom = const [],
    this.eastTopToBottom = const [],
    required this.fourSides,
  });

  final List<int> south;
  final List<int> north;
  final List<int> westTopToBottom;
  final List<int> eastTopToBottom;
  final bool fourSides;

  SeatingPlan oriented(int orientation, int count) {
    if (count <= 0) return this;
    final shift = orientation % count;
    List<int> map(List<int> slots) => [
      for (final slot in slots) (slot + shift) % count,
    ];
    return SeatingPlan(
      south: map(south),
      north: map(north),
      westTopToBottom: map(westTopToBottom),
      eastTopToBottom: map(eastTopToBottom),
      fourSides: fourSides,
    );
  }
}

SeatingPlan phonePlan(int count) {
  if (count <= 0) {
    return const SeatingPlan(south: [], north: [], fourSides: false);
  }
  final bottomCount = (count + 1) ~/ 2;
  final topCount = count - bottomCount;
  final north = [for (var i = 1; i <= topCount; i++) i];
  final south = <int>[0];
  for (var i = 0; i < bottomCount - 1; i++) {
    south.add(count - 1 - i);
  }
  return SeatingPlan(south: south, north: north, fourSides: false);
}

SeatingPlan tabletPlan(int count) {
  if (count < 4) return phonePlan(count);
  var southCount = 1;
  var westCount = 1;
  var northCount = 1;
  var eastCount = 1;
  for (var i = 0; i < count - 4; i++) {
    switch (i % 4) {
      case 0:
        southCount++;
      case 1:
        northCount++;
      case 2:
        westCount++;
      default:
        eastCount++;
    }
  }
  var cursor = 0;
  int take() => cursor++;
  final southLeft = take();
  final westSouthToNorth = [for (var i = 0; i < westCount; i++) take()];
  final northLeftToRight = [for (var i = 0; i < northCount; i++) take()];
  final eastNorthToSouth = [for (var i = 0; i < eastCount; i++) take()];
  final southFromEast = [for (var i = 0; i < southCount - 1; i++) take()];
  return SeatingPlan(
    south: [southLeft, ...southFromEast.reversed],
    north: northLeftToRight,
    westTopToBottom: westSouthToNorth.reversed.toList(),
    eastTopToBottom: eastNorthToSouth,
    fourSides: true,
  );
}

bool useFourSides({
  required double width,
  required double height,
  required int players,
}) {
  return players >= 4 && width >= 720 && height >= 520;
}

/// Téléphone à l’horizontale : un joueur par bord, y compris les deux côtés.
bool useLandscapeEdges({
  required double width,
  required double height,
  required int players,
}) {
  return players >= 3 &&
      players <= 4 &&
      width > height &&
      width >= 520 &&
      height < 520;
}

/// 3 joueurs : bas, gauche, droite. 4 joueurs : un par bord.
SeatingPlan landscapePlan(int count) {
  if (count == 3) {
    return const SeatingPlan(
      south: [0],
      north: [],
      westTopToBottom: [1],
      eastTopToBottom: [2],
      fourSides: true,
    );
  }
  if (count == 4) return tabletPlan(4);
  return phonePlan(count);
}

/// Table type poker : un seul joueur à gauche et à droite (ils sont tournés),
/// les autres en haut et en bas, dans le sens de celui qui est assis là.
SeatingPlan pokerPlan(int count) {
  if (count < 5) return tabletPlan(count);
  const westCount = 1;
  const eastCount = 1;
  final rest = count - westCount - eastCount;
  final southCount = (rest + 1) ~/ 2;
  final northCount = rest - southCount;
  var cursor = 0;
  int take() => cursor++;
  final southLeft = take();
  final westSouthToNorth = [for (var i = 0; i < westCount; i++) take()];
  final northLeftToRight = [for (var i = 0; i < northCount; i++) take()];
  final eastNorthToSouth = [for (var i = 0; i < eastCount; i++) take()];
  final southFromEast = [for (var i = 0; i < southCount - 1; i++) take()];
  return SeatingPlan(
    south: [southLeft, ...southFromEast.reversed],
    north: northLeftToRight,
    westTopToBottom: westSouthToNorth.reversed.toList(),
    eastTopToBottom: eastNorthToSouth,
    fourSides: true,
  );
}

/// Fenêtre assez grande pour une table lue de chaque côté (TV, moniteur).
bool usePokerTable({
  required double width,
  required double height,
  required int players,
}) {
  return players >= 5 &&
      players <= maxTablePlayers &&
      width >= 1000 &&
      height >= 680;
}

SeatingPlan planFor({required int players, required bool fourSides}) {
  final plan = fourSides ? tabletPlan(players) : phonePlan(players);
  return plan;
}

bool preferList({
  required ViewMode mode,
  required double width,
  required double height,
  required SeatingPlan plan,
}) {
  if (mode == ViewMode.list || mode == ViewMode.focus) return true;
  if (mode == ViewMode.table) return false;
  if (plan.fourSides) return false;
  final columns = math.max(plan.south.length, math.max(plan.north.length, 1));
  final rows = plan.north.isNotEmpty && plan.south.isNotEmpty ? 2 : 1;
  final cellWidth = width / columns;
  final cellHeight = (height - 160) / rows;
  return cellWidth < 168 || cellHeight < 170;
}

/// Joueur en face (même colonne N/S ou E/O), sinon `null`.
/// Sur table partagée : le gros pad d’un siège touche les PV de l’adversaire.
int? facingSeatIndex(SeatingPlan plan, int seatIndex) {
  int? pair(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] == seatIndex) return b[i];
      if (b[i] == seatIndex) return a[i];
    }
    return null;
  }

  return pair(plan.north, plan.south) ??
      pair(plan.westTopToBottom, plan.eastTopToBottom);
}
