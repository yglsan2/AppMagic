/// Handicaps pour équilibrer des decks de niveaux différents.
///
/// Les paliers sont des raccourcis. La valeur réelle est toujours
/// [handicapLifeDelta] (PV), librement personnalisable.
/// Le seuil de commandant (21) reste inchangé.
enum DeckBracket {
  precon,
  budget,
  fair,
  strong,
  cedh,

  /// Valeur libre fixée par la table.
  custom,
}

extension DeckBracketX on DeckBracket {
  /// Points de handicap (−2 … +2) pour les paliers prédéfinis.
  int get handicapPoints => switch (this) {
    DeckBracket.precon => 2,
    DeckBracket.budget => 1,
    DeckBracket.fair => 0,
    DeckBracket.strong => -1,
    DeckBracket.cedh => -2,
    DeckBracket.custom => 0,
  };

  /// PV suggérés par le palier (hors personnalisé).
  int get suggestedLifeDelta =>
      this == DeckBracket.custom ? 0 : handicapPoints * lifePerHandicapPoint;

  String get label => switch (this) {
    DeckBracket.precon => 'Préconstruit',
    DeckBracket.budget => 'Petit budget',
    DeckBracket.fair => 'Équilibré',
    DeckBracket.strong => 'Optimisé',
    DeckBracket.cedh => 'Compétitif (cEDH)',
    DeckBracket.custom => 'Personnalisé',
  };

  String get help => switch (this) {
    DeckBracket.precon =>
      'Deck prêt à jouer, ou très tranquille. +10 points de vie '
          'face à des decks plus forts.',
    DeckBracket.budget =>
      'Deck modeste. +5 points de vie.',
    DeckBracket.fair =>
      'Même niveau que la table : aucun bonus ni malus de PV.',
    DeckBracket.strong =>
      'Deck très optimisé. −5 points de vie pour rééquilibrer.',
    DeckBracket.cedh =>
      'Deck de tournoi, souvent très cher. −10 points de vie.',
    DeckBracket.custom =>
      'Valeur libre : réglez le bonus ou malus de PV exactement '
          'comme la table le souhaite (−30 à +30).',
  };

  String detailFor(int lifeDelta) {
    if (this == DeckBracket.custom) {
      return 'Personnalisé · ${formatLifeDelta(lifeDelta)} PV';
    }
    return switch (this) {
      DeckBracket.precon => '+2 pts · +10 PV — préconstruit',
      DeckBracket.budget => '+1 pt · +5 PV — petit budget',
      DeckBracket.fair => '0 · table au même niveau',
      DeckBracket.strong => '−1 pt · −5 PV — deck optimisé',
      DeckBracket.cedh => '−2 pts · −10 PV — compétitif (cEDH)',
      DeckBracket.custom => 'Personnalisé · ${formatLifeDelta(lifeDelta)} PV',
    };
  }

  String chipLabel(int lifeDelta) {
    if (this == DeckBracket.custom) {
      return 'Perso ${formatLifeDelta(lifeDelta)}';
    }
    return '$label ${formatLifeDelta(suggestedLifeDelta)}';
  }
}

/// 1 point de handicap = 5 PV sur les raccourcis.
const lifePerHandicapPoint = 5;

/// Plage libre de bonus / malus de PV.
const handicapLifeMin = -30;
const handicapLifeMax = 30;

DeckBracket deckBracketFromName(String? name) {
  return DeckBracket.values.firstWhere(
    (b) => b.name == name,
    orElse: () => DeckBracket.fair,
  );
}

int clampHandicapLife(int value) => value.clamp(handicapLifeMin, handicapLifeMax);

/// @Deprecated — alias de [clampHandicapLife] pour anciennes API.
int clampFineTune(int value) => clampHandicapLife(value);

String formatLifeDelta(int delta) {
  if (delta == 0) return '±0';
  if (delta > 0) return '+$delta';
  return '$delta';
}

/// Retrouve le palier qui correspond exactement à un delta, sinon [custom].
DeckBracket bracketMatchingLifeDelta(int lifeDelta) {
  for (final bracket in DeckBracket.values) {
    if (bracket == DeckBracket.custom) continue;
    if (bracket.suggestedLifeDelta == lifeDelta) return bracket;
  }
  return DeckBracket.custom;
}

/// Vie de départ effective pour un joueur.
int effectiveStartingLife({
  required int baseLife,
  required bool handicapsEnabled,
  required int lifeDelta,
}) {
  if (!handicapsEnabled) return baseLife;
  return (baseLife + clampHandicapLife(lifeDelta)).clamp(1, 200);
}
