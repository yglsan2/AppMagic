class DeckLine {
  const DeckLine(this.count, this.name);

  final int count;
  final String name;
}

class CurveCard {
  const CurveCard({
    required this.name,
    required this.count,
    required this.mv,
    this.land = false,
    this.manaCost = '',
    this.produces = const [],
    this.creature = false,
    this.ramp = false,
    this.draw = false,
    this.instant = false,
    this.sorcery = false,
    this.artifact = false,
    this.enchantment = false,
    this.planeswalker = false,
    this.interaction = false,
    this.wipe = false,
    this.basic = false,
    this.anyNumber = false,
    this.unknown = false,
    this.legalCommander = true,
    this.rarity = '',
    this.edhrecRank,
    this.colorIdentity = const [],
  });

  final String name;
  final int count;
  final int mv;
  final bool land;
  final String manaCost;
  final List<String> produces;
  final bool creature;
  final bool ramp;
  final bool draw;
  final bool instant;
  final bool sorcery;
  final bool artifact;
  final bool enchantment;
  final bool planeswalker;
  final bool interaction;
  final bool wipe;
  final bool basic;
  final bool anyNumber;
  final bool unknown;
  final bool legalCommander;
  final String rarity;
  final int? edhrecRank;
  final List<String> colorIdentity;
}

class CurveReport {
  const CurveReport({
    required this.buckets,
    required this.lands,
    required this.spells,
    required this.averageSpellMv,
    required this.suggestedLands,
    required this.pips,
    required this.sources,
    required this.advice,
  });

  /// Index 0 à 6, puis 7 pour « 7 ou plus ». Sorts seulement.
  final List<int> buckets;
  final int lands;
  final int spells;
  final double averageSpellMv;
  final int suggestedLands;
  final Map<String, int> pips;
  final Map<String, int> sources;
  final List<String> advice;
}

class CurveContext {
  const CurveContext({
    this.averageGameSec,
    this.commanderWins,
    this.commanderGames,
    this.commanderName,
  });

  final int? averageGameSec;
  final int? commanderWins;
  final int? commanderGames;
  final String? commanderName;
}

const curveColors = ['W', 'U', 'B', 'R', 'G'];

List<DeckLine> parseDeckList(String raw) {
  final lines = <DeckLine>[];
  for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('//') || line.startsWith('#')) {
      continue;
    }
    final lower = line.toLowerCase();
    if (lower == 'deck' ||
        lower == 'sideboard' ||
        lower == 'commander' ||
        lower == 'commandant') {
      continue;
    }
    final match = RegExp(r'^(\d+)\s*[xX]?\s+(.+)$').firstMatch(line);
    if (match != null) {
      final count = int.tryParse(match.group(1)!);
      final name = tidyCardName(match.group(2)!);
      if (count != null && count > 0 && name.isNotEmpty) {
        lines.add(DeckLine(count, name));
      }
      continue;
    }
    lines.add(DeckLine(1, tidyCardName(line)));
  }
  return lines;
}

Map<String, int> manaPips(String cost) {
  final pips = {for (final color in curveColors) color: 0};
  for (final match in RegExp(r'\{([^}]+)\}').allMatches(cost)) {
    final body = match.group(1)!;
    if (body.contains('/')) {
      for (final part in body.split('/')) {
        if (pips.containsKey(part)) pips[part] = pips[part]! + 1;
      }
      continue;
    }
    if (pips.containsKey(body)) pips[body] = pips[body]! + 1;
  }
  return pips;
}

/// Repère de construction, pas une règle. Commander à partir de 80 cartes.
CurveReport buildCurve(List<CurveCard> cards, {CurveContext? context}) {
  final buckets = List<int>.filled(8, 0);
  var lands = 0;
  var spells = 0;
  var spellMv = 0;
  final pips = {for (final color in curveColors) color: 0};
  final sources = {for (final color in curveColors) color: 0};
  var total = 0;
  for (final card in cards) {
    if (card.count <= 0 || card.unknown) continue;
    total += card.count;
    if (card.land) {
      lands += card.count;
      for (final color in card.produces) {
        if (sources.containsKey(color)) {
          sources[color] = sources[color]! + card.count;
        }
      }
      continue;
    }
    spells += card.count;
    spellMv += card.mv * card.count;
    final bucket = card.mv.clamp(0, 7);
    buckets[bucket] += card.count;
    final cardPips = manaPips(card.manaCost);
    for (final color in curveColors) {
      pips[color] = pips[color]! + cardPips[color]! * card.count;
    }
  }
  final average = spells == 0 ? 0.0 : spellMv / spells;
  final commander = total >= 80;
  final shift = ((average - 3).clamp(-1.5, 2.0) * 2).round();
  final suggested = (commander ? 37 : 24) + shift;
  final advice = <String>[];
  if (spells == 0) {
    advice.add('Ajoutez des sorts pour lire une courbe.');
  } else {
    final gap = lands - suggested.clamp(commander ? 30 : 16, commander ? 45 : 30);
    final target = suggested.clamp(commander ? 30 : 16, commander ? 45 : 30);
    if (gap <= -2) {
      advice.add(
        'Pour une moyenne de ${average.toStringAsFixed(1)}, '
        'le repère est d’environ $target terrains. Il en manque ${-gap}.',
      );
    } else if (gap >= 3) {
      advice.add(
        'Pour cette moyenne, $target terrains suffisent souvent. '
        'Il y en a $gap de plus.',
      );
    } else {
      advice.add(
        'Le nombre de terrains est proche du repère ($target) '
        'pour une moyenne de ${average.toStringAsFixed(1)}.',
      );
    }
    final expensive = buckets[6] + buckets[7];
    if (expensive > buckets[2] && spells >= 12) {
      advice.add(
        'La courbe est lourde : plus de sorts à 6 ou plus qu’à 2.',
      );
    }
    if (buckets[2] + buckets[3] < (spells * 0.35).round() && spells >= 12) {
      advice.add('Peu de sorts à 2 et 3. Le début de partie est lent.');
    }
    final pipTotal = pips.values.fold<int>(0, (sum, value) => sum + value);
    final sourceTotal = sources.values.fold<int>(0, (sum, value) => sum + value);
    if (pipTotal > 0 && sourceTotal > 0) {
      for (final color in curveColors) {
        final pipShare = pips[color]! / pipTotal;
        final sourceShare = sources[color]! / sourceTotal;
        if (pipShare >= 0.2 && sourceShare + 0.12 < pipShare) {
          advice.add(
            '${_colorName(color)} demande beaucoup de symboles '
            'et peu de sources le produisent.',
          );
        }
      }
    }
  }
  final minutes = context?.averageGameSec;
  if (minutes != null && minutes >= 75 * 60 && average >= 3.2) {
    advice.add(
      'Les parties ici durent longtemps, et cette courbe est haute. '
      'Quelques sorts à 2 ou 3 accélèrent le début.',
    );
  }
  final games = context?.commanderGames ?? 0;
  final wins = context?.commanderWins;
  final name = context?.commanderName;
  if (name != null && wins != null && games >= 3) {
    final rate = (wins / games * 100).round();
    advice.add(
      '$name est à $rate % sur $games parties enregistrées sur cet appareil.',
    );
  }
  return CurveReport(
    buckets: buckets,
    lands: lands,
    spells: spells,
    averageSpellMv: average,
    suggestedLands: suggested.clamp(commander ? 30 : 16, commander ? 45 : 30),
    pips: pips,
    sources: sources,
    advice: advice,
  );
}

CurveCard copyCount(CurveCard card, int count) {
  return CurveCard(
    name: card.name,
    count: count,
    mv: card.mv,
    land: card.land,
    manaCost: card.manaCost,
    produces: card.produces,
    creature: card.creature,
    ramp: card.ramp,
    draw: card.draw,
    instant: card.instant,
    sorcery: card.sorcery,
    artifact: card.artifact,
    enchantment: card.enchantment,
    planeswalker: card.planeswalker,
    interaction: card.interaction,
    wipe: card.wipe,
    basic: card.basic,
    anyNumber: card.anyNumber,
    unknown: card.unknown,
    legalCommander: card.legalCommander,
    rarity: card.rarity,
    edhrecRank: card.edhrecRank,
    colorIdentity: card.colorIdentity,
  );
}

int countRole(List<CurveCard> cards, bool Function(CurveCard card) test) {
  var total = 0;
  for (final card in cards) {
    if (test(card)) total += card.count;
  }
  return total;
}

String _colorName(String color) => switch (color) {
  'W' => 'Le blanc',
  'U' => 'Le bleu',
  'B' => 'Le noir',
  'R' => 'Le rouge',
  'G' => 'Le vert',
  _ => color,
};

const basicProduces = <String, List<String>>{
  'plains': ['W'],
  'plaine': ['W'],
  'island': ['U'],
  'île': ['U'],
  'ile': ['U'],
  'swamp': ['B'],
  'marais': ['B'],
  'mountain': ['R'],
  'montagne': ['R'],
  'forest': ['G'],
  'forêt': ['G'],
  'foret': ['G'],
  'snow-covered plains': ['W'],
  'snow-covered island': ['U'],
  'snow-covered swamp': ['B'],
  'snow-covered mountain': ['R'],
  'snow-covered forest': ['G'],
  'plaine enneigée': ['W'],
  'île enneigée': ['U'],
  'ile enneigée': ['U'],
  'marais enneigé': ['B'],
  'montagne enneigée': ['R'],
  'forêt enneigée': ['G'],
  'foret enneigee': ['G'],
  'wastes': <String>[],
};

CurveCard? basicCurveCard(String name, int count) {
  final key = name.trim().toLowerCase();
  final produces = basicProduces[key];
  if (produces == null) return null;
  return CurveCard(
    name: name.trim(),
    count: count,
    mv: 0,
    land: true,
    basic: true,
    produces: produces,
    colorIdentity: produces,
  );
}

/// Enlève le code d’édition collé en fin de ligne : « (C21) 263 ».
String tidyCardName(String raw) {
  var name = raw.trim();
  name = name.replaceFirst(RegExp(r'^[-*•]\s+'), '');
  name = name.replaceFirst(
    RegExp(r'\s+\([A-Za-z0-9]{2,8}\)(?:\s+\d+[a-z]?)?\s*$'),
    '',
  );
  name = name.replaceFirst(RegExp(r'\s+\[[^\]]{1,12}\]\s*$'), '');
  name = name.replaceFirst(RegExp(r'\s+\*[A-Za-z]{1,4}\*\s*$'), '');
  return name.trim();
}
