import 'package:mtg_table/domain/seating.dart';

/// Combien de téléphones pour une table lisible (stratégie LifeStack).
///
/// - 1–5 : un écran suffit
/// - 6–8 : un écran compact, ou deux téléphones en carré
/// - 9–10 : trois téléphones obligatoires
enum TablePhoneNeed {
  one,
  oneOrTwo,
  three,
}

TablePhoneNeed phoneNeedFor(int players) {
  if (players <= 5) return TablePhoneNeed.one;
  if (players <= 8) return TablePhoneNeed.oneOrTwo;
  return TablePhoneNeed.three;
}

/// Nombre de panneaux conseillé (ou imposé).
int suggestedPhoneCount(int players, {required bool preferMulti}) {
  switch (phoneNeedFor(players)) {
    case TablePhoneNeed.one:
      return 1;
    case TablePhoneNeed.oneOrTwo:
      return preferMulti ? 2 : 1;
    case TablePhoneNeed.three:
      return 3;
  }
}

int minPhonesFor(int players) {
  switch (phoneNeedFor(players)) {
    case TablePhoneNeed.one:
    case TablePhoneNeed.oneOrTwo:
      return 1;
    case TablePhoneNeed.three:
      return 3;
  }
}

int maxPhonesFor(int players) {
  switch (phoneNeedFor(players)) {
    case TablePhoneNeed.one:
      return 1;
    case TablePhoneNeed.oneOrTwo:
      return 2;
    case TablePhoneNeed.three:
      return 3;
  }
}

/// Mode compact un téléphone : dès 6 joueurs sur un seul écran.
bool useMinimalBand(int players, {required int phoneCount}) {
  return players >= 6 && players <= 8 && phoneCount <= 1;
}

/// Plan poker (autour de la table), puis sièges gardés pour ce panneau.
///
/// 2 téléphones (carré) : gauche / droite.
/// 3 téléphones : gauche / centre / droite.
SeatingPlan panelPlan({
  required int players,
  required int panelIndex,
  required int panelCount,
  int shift = 0,
}) {
  final full = pokerPlan(players).oriented(shift, players);
  if (panelCount <= 1) return full;
  final index = panelIndex.clamp(0, panelCount - 1);
  final keep = panelSeatIndexes(
    players: players,
    panelIndex: index,
    panelCount: panelCount,
    shift: shift,
  );
  bool ok(int seat) => keep.contains(seat);
  return SeatingPlan(
    south: [for (final s in full.south) if (ok(s)) s],
    north: [for (final s in full.north) if (ok(s)) s],
    westTopToBottom: [
      for (final s in full.westTopToBottom)
        if (ok(s)) s,
    ],
    eastTopToBottom: [
      for (final s in full.eastTopToBottom)
        if (ok(s)) s,
    ],
    fourSides: true,
  );
}

/// Sièges (index joueur après [shift]) attribués à un panneau.
Set<int> panelSeatIndexes({
  required int players,
  required int panelIndex,
  required int panelCount,
  int shift = 0,
}) {
  final full = pokerPlan(players).oriented(shift, players);
  final all = <int>[
    ...full.south,
    ...full.westTopToBottom,
    ...full.north,
    ...full.eastTopToBottom,
  ];
  // Ordre horloge déjà dans pokerPlan ; on découpe en tranches contiguës
  // sur le cercle pour coller les téléphones côte à côte.
  final ordered = _clockwise(full);
  if (panelCount <= 1) return ordered.toSet();

  final n = ordered.length;
  final base = n ~/ panelCount;
  final extra = n % panelCount;
  var start = 0;
  for (var p = 0; p < panelCount; p++) {
    final size = base + (p < extra ? 1 : 0);
    final end = start + size;
    if (p == panelIndex) {
      return ordered.sublist(start, end).toSet();
    }
    start = end;
  }
  return all.toSet();
}

List<int> _clockwise(SeatingPlan plan) {
  // Sud gauche → ouest bas→haut → nord gauche→droite → est haut→bas → sud reste.
  return [
    ...plan.south.take(1),
    ...plan.westTopToBottom.reversed,
    ...plan.north,
    ...plan.eastTopToBottom,
    ...plan.south.skip(1),
  ];
}

/// Libellé court du panneau : A, B, C.
String panelLabel(int panelIndex) {
  const letters = 'ABCDEFGH';
  if (panelIndex < 0 || panelIndex >= letters.length) {
    return '${panelIndex + 1}';
  }
  return letters[panelIndex];
}

/// Réservation de panneau dans [TableLinkController.seats] (pas un joueur).
const panelSeatPrefix = '__panel_';

bool isPanelSeat(String? id) =>
    id != null && id.startsWith(panelSeatPrefix);

int? panelIndexFromSeat(String? id) {
  if (!isPanelSeat(id)) return null;
  return int.tryParse(id!.substring(panelSeatPrefix.length));
}

String panelSeatId(int panelIndex) => '$panelSeatPrefix$panelIndex';
