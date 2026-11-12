import 'package:mtg_table/domain/mana_curve.dart';

const deckAuditCap = 110;

enum DeckZone { commander, main, sideboard }

class ZonedDeck {
  const ZonedDeck({
    required this.commander,
    required this.main,
    required this.sideboard,
    required this.dropped,
  });

  final List<DeckLine> commander;
  final List<DeckLine> main;
  final List<DeckLine> sideboard;
  final int dropped;

  int get total =>
      _sum(commander) + _sum(main) + _sum(sideboard);

  bool get isEmpty => total == 0;
}

int _sum(List<DeckLine> lines) =>
    lines.fold<int>(0, (total, line) => total + line.count);

DeckZone? _zoneHeader(String line) {
  switch (line.toLowerCase()) {
    case 'commander':
    case 'commandant':
      return DeckZone.commander;
    case 'deck':
    case 'main':
    case 'principal':
      return DeckZone.main;
    case 'sideboard':
    case 'side':
    case 'sb':
    case 'réserve':
    case 'reserve':
      return DeckZone.sideboard;
    default:
      return null;
  }
}

DeckLine? _deckLine(String line) {
  final match = RegExp(r'^(\d+)\s*[xX]?\s+(.+)$').firstMatch(line);
  if (match != null) {
    final count = int.tryParse(match.group(1)!);
    final name = tidyCardName(match.group(2)!);
    if (count != null && count > 0 && name.isNotEmpty) {
      return DeckLine(count, name);
    }
    return null;
  }
  if (line.isEmpty) return null;
  return DeckLine(1, tidyCardName(line));
}

/// Commandant, deck et réserve. Au-delà de 110 cartes, le surplus est ignoré.
ZonedDeck parseZonedDeck(String raw) {
  final commander = <DeckLine>[];
  final main = <DeckLine>[];
  final sideboard = <DeckLine>[];
  var zone = DeckZone.main;
  var kept = 0;
  var dropped = 0;
  for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
    var line = rawLine.trim();
    if (line.isEmpty || line.startsWith('//') || line.startsWith('#')) {
      continue;
    }
    line = line.replaceFirst(RegExp(r'^[-*•]\s+'), '');
    DeckZone? forced;
    final sideMark = RegExp(
      r'^(?:sb|sideboard|réserve|reserve)\s*:\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (sideMark != null) {
      forced = DeckZone.sideboard;
      line = sideMark.group(1)!.trim();
    }
    final header = _zoneHeader(line);
    if (header != null && forced == null) {
      zone = header;
      continue;
    }
    final parsed = _deckLine(line);
    if (parsed == null) continue;
    final room = deckAuditCap - kept;
    if (room <= 0) {
      dropped += parsed.count;
      continue;
    }
    final take = parsed.count > room ? room : parsed.count;
    dropped += parsed.count - take;
    kept += take;
    final stored = DeckLine(take, parsed.name);
    switch (forced ?? zone) {
      case DeckZone.commander:
        commander.add(stored);
      case DeckZone.main:
        main.add(stored);
      case DeckZone.sideboard:
        sideboard.add(stored);
    }
  }
  return ZonedDeck(
    commander: commander,
    main: main,
    sideboard: sideboard,
    dropped: dropped,
  );
}

class DeckAudit {
  const DeckAudit({
    required this.commanderCards,
    required this.mainCards,
    required this.sideCards,
    required this.dropped,
    required this.recognized,
    required this.unknown,
    required this.curve,
    required this.creatures,
    required this.instants,
    required this.sorceries,
    required this.artifacts,
    required this.enchantments,
    required this.planeswalkers,
    required this.ramp,
    required this.draw,
    required this.interaction,
    required this.threats,
    required this.wipes,
    required this.fixing,
    required this.rarityLine,
    required this.manaLine,
    required this.unknownNames,
    required this.offIdentity,
    required this.duplicates,
    required this.rarelyPlayed,
    required this.illegal,
    required this.portrait,
    required this.advice,
    required this.strengths,
    required this.weaknesses,
  });

  final int commanderCards;
  final int mainCards;
  final int sideCards;
  final int dropped;
  final int recognized;
  final int unknown;
  final CurveReport curve;
  final int creatures;
  final int instants;
  final int sorceries;
  final int artifacts;
  final int enchantments;
  final int planeswalkers;
  final int ramp;
  final int draw;
  final int interaction;
  final int threats;
  final int wipes;
  final int fixing;
  final String rarityLine;
  final String manaLine;
  final List<String> unknownNames;
  final List<String> offIdentity;
  final List<String> duplicates;
  final List<String> rarelyPlayed;
  final List<String> illegal;
  final String portrait;
  final List<String> advice;
  final List<String> strengths;
  final List<String> weaknesses;
}

int _count(List<CurveCard> cards, bool Function(CurveCard card) test) {
  var total = 0;
  for (final card in cards) {
    if (test(card)) total += card.count;
  }
  return total;
}

bool _littlePlayed(CurveCard card) {
  if (card.unknown || card.basic || card.land) return false;
  final rank = card.edhrecRank;
  return rank == null || rank > 15000;
}

List<String> _names(Iterable<CurveCard> cards, {int cap = 8}) {
  final names = <String>[];
  for (final card in cards) {
    if (names.length == cap) break;
    if (names.contains(card.name)) continue;
    names.add(card.name);
  }
  return names;
}

String _manaLine(CurveReport curve) {
  const labels = {
    'W': 'Blanc',
    'U': 'Bleu',
    'B': 'Noir',
    'R': 'Rouge',
    'G': 'Vert',
  };
  final parts = <String>[];
  for (final color in curveColors) {
    final pips = curve.pips[color] ?? 0;
    final sources = curve.sources[color] ?? 0;
    if (pips == 0 && sources == 0) continue;
    parts.add('${labels[color]} $sources sources / $pips symboles');
  }
  return parts.join(' · ');
}

Map<String, CurveCard> _byName(List<CurveCard> cards) {
  final totals = <String, int>{};
  final sample = <String, CurveCard>{};
  for (final card in cards) {
    final key = card.name.toLowerCase();
    totals[key] = (totals[key] ?? 0) + card.count;
    sample[key] = card;
  }
  return {
    for (final entry in sample.entries)
      entry.key: copyCount(entry.value, totals[entry.key]!),
  };
}

/// Le commandant et la réserve ne rentrent pas dans la courbe du deck.
/// Les cartes inconnues comptent dans la taille, pas dans les rôles.
DeckAudit auditDeck({
  required List<CurveCard> commander,
  required List<CurveCard> main,
  List<CurveCard> side = const [],
  required int dropped,
  CurveContext? context,
}) {
  final knownMain = [for (final card in main) if (!card.unknown) card];
  final curve = buildCurve(knownMain, context: context);
  final commanderSize = _sumCards(commander);
  final mainSize = _sumCards(main);
  final sideCards = _sumCards(side);
  final unknownCards = [for (final card in main) if (card.unknown) card];
  final unknown = _sumCards(unknownCards);
  final recognized = mainSize - unknown;
  final commanderDeck = commanderSize > 0 || mainSize >= 80;
  final creatures = _count(knownMain, (card) => card.creature);
  final ramp = _count(knownMain, (card) => card.ramp);
  final draw = _count(knownMain, (card) => card.draw);
  final interaction = _count(knownMain, (card) => card.interaction);
  final wipes = _count(knownMain, (card) => card.wipe);
  final fixing = _count(
    knownMain,
    (card) => card.land && card.produces.length >= 2,
  );
  final threats = _count(
    knownMain,
    (card) =>
        card.mv >= 6 &&
        !card.land &&
        (card.creature || (!card.ramp && !card.draw)),
  );
  final merged = _byName(main);
  final identity = <String>{
    for (final card in commander)
      if (!card.unknown) ...card.colorIdentity,
  };
  final offCards = <CurveCard>[
    for (final card in [...main, ...side])
      if (!card.unknown &&
          identity.isNotEmpty &&
          card.colorIdentity.any((color) => !identity.contains(color)))
        card,
  ];
  final duplicateCards = <CurveCard>[
    for (final card in merged.values)
      if (card.count > (commanderDeck ? 1 : 4) &&
          !card.basic &&
          !card.anyNumber &&
          !card.unknown)
        card,
  ];
  final illegalCards = <CurveCard>[
    for (final card in [...commander, ...knownMain, ...side])
      if (commanderDeck && !card.legalCommander && !card.unknown) card,
  ];
  final rareCards = <CurveCard>[
    for (final card in knownMain)
      if (_littlePlayed(card)) card,
  ];
  final deckColors = <String>{
    for (final card in [...commander, ...knownMain]) ...card.colorIdentity,
  };
  final reading = _counsel(
    commanderDeck: commanderDeck,
    commanderSize: commanderSize,
    mainSize: mainSize,
    sideCards: sideCards,
    recognized: recognized,
    unknown: unknown,
    unknownCards: unknownCards,
    curve: curve,
    creatures: creatures,
    ramp: ramp,
    draw: draw,
    interaction: interaction,
    threats: threats,
    wipes: wipes,
    fixing: fixing,
    planeswalkers: _count(knownMain, (card) => card.planeswalker),
    colors: deckColors.length,
    offCards: offCards,
    duplicateCards: duplicateCards,
    illegalCards: illegalCards,
    rareCards: rareCards,
  );
  var commons = 0;
  var uncommons = 0;
  var rares = 0;
  var mythics = 0;
  for (final card in knownMain) {
    if (card.land) continue;
    switch (card.rarity) {
      case 'common':
        commons += card.count;
      case 'uncommon':
        uncommons += card.count;
      case 'rare':
        rares += card.count;
      case 'mythic':
        mythics += card.count;
    }
  }
  final rarityLine = commons + uncommons + rares + mythics == 0
      ? ''
      : '$commons communes, $uncommons peu communes, $rares rares, $mythics mythiques';
  return DeckAudit(
    commanderCards: commanderSize,
    mainCards: mainSize,
    sideCards: sideCards,
    dropped: dropped,
    recognized: recognized,
    unknown: unknown,
    curve: curve,
    creatures: creatures,
    instants: _count(knownMain, (card) => card.instant),
    sorceries: _count(knownMain, (card) => card.sorcery),
    artifacts: _count(knownMain, (card) => card.artifact),
    enchantments: _count(knownMain, (card) => card.enchantment),
    planeswalkers: _count(knownMain, (card) => card.planeswalker),
    ramp: ramp,
    draw: draw,
    interaction: interaction,
    threats: threats,
    wipes: wipes,
    fixing: fixing,
    rarityLine: rarityLine,
    manaLine: _manaLine(curve),
    unknownNames: _names(unknownCards),
    offIdentity: _names(offCards),
    duplicates: _names(duplicateCards),
    rarelyPlayed: commanderDeck ? _names(rareCards) : const [],
    illegal: _names(illegalCards),
    portrait: reading.portrait,
    advice: reading.advice,
    strengths: reading.strengths,
    weaknesses: reading.weaknesses,
  );
}

class _Reading {
  const _Reading(this.portrait, this.advice, this.strengths, this.weaknesses);

  final String portrait;
  final List<String> advice;
  final List<String> strengths;
  final List<String> weaknesses;
}

int _landTarget(CurveReport curve, bool commanderDeck) {
  if (!commanderDeck) return curve.suggestedLands;
  final shift = ((curve.averageSpellMv - 3).clamp(-1.5, 2.0) * 2).round();
  return (37 + shift).clamp(30, 45);
}

List<String> _shortColors(CurveReport curve) {
  const labels = {
    'W': 'blanc',
    'U': 'bleu',
    'B': 'noir',
    'R': 'rouge',
    'G': 'vert',
  };
  final pipTotal = curve.pips.values.fold<int>(0, (sum, value) => sum + value);
  final sourceTotal = curve.sources.values.fold<int>(0, (sum, value) => sum + value);
  if (pipTotal == 0 || sourceTotal == 0) return const [];
  final short = <String>[];
  for (final color in curveColors) {
    final pipShare = curve.pips[color]! / pipTotal;
    final sourceShare = curve.sources[color]! / sourceTotal;
    if (pipShare >= 0.2 && sourceShare + 0.12 < pipShare) {
      short.add(labels[color]!);
    }
  }
  return short;
}

_Reading _counsel({
  required bool commanderDeck,
  required int commanderSize,
  required int mainSize,
  required int sideCards,
  required int recognized,
  required int unknown,
  required List<CurveCard> unknownCards,
  required CurveReport curve,
  required int creatures,
  required int ramp,
  required int draw,
  required int interaction,
  required int threats,
  required int wipes,
  required int fixing,
  required int planeswalkers,
  required int colors,
  required List<CurveCard> offCards,
  required List<CurveCard> duplicateCards,
  required List<CurveCard> illegalCards,
  required List<CurveCard> rareCards,
}) {
  final strengths = <String>[];
  final weaknesses = <String>[];
  final advice = <String>[];
  final sentences = <String>[];
  final average = curve.averageSpellMv;
  final avgText = average.toStringAsFixed(1);
  final target = _landTarget(curve, commanderDeck);
  final landGap = curve.lands - target;
  final shortColors = _shortColors(curve);
  final early = curve.buckets[1] + curve.buckets[2];
  final top = curve.buckets[6] + curve.buckets[7];
  final middle = curve.buckets[2] + curve.buckets[3];
  final setupHeavy = commanderDeck &&
      curve.lands >= 36 &&
      ramp >= 6 &&
      creatures < 24 &&
      curve.spells >= 20;
  final canCast = recognized > 0 &&
      landGap > -4 &&
      shortColors.isEmpty &&
      (average < 4.0 || ramp >= 6);
  final obscure = commanderDeck &&
      curve.spells > 0 &&
      rareCards.length >= 8 &&
      rareCards.length >= (curve.spells * 0.25).round();
  final illegalShape = offCards.isNotEmpty ||
      duplicateCards.isNotEmpty ||
      illegalCards.isNotEmpty;

  if (recognized == 0 && unknown > 0) {
    sentences.add(
      'Aucun nom n’a été reconnu. La taille est là, la courbe et les rôles restent vides.',
    );
    advice.add(
      'Écris un nom de carte par ligne, avec le nombre devant. '
      'Le nom anglais exact est celui que la recherche reconnaît.',
    );
  } else if (recognized > 0) {
    if (commanderSize == 1 && mainSize == 99 && unknown == 0) {
      strengths.add('Taille de commandant : 1 + 99.');
    } else if (!commanderDeck && mainSize >= 58 && mainSize <= 62) {
      strengths.add('Taille de deck construit, autour de 60 cartes.');
    }
    if (landGap.abs() <= 2 && curve.spells > 0) {
      strengths.add('Les terrains suivent la courbe, autour de $target.');
    }
    if (commanderDeck && ramp >= 8 && ramp <= 14) {
      strengths.add('$ramp accélérations : un bon milieu pour un commandant.');
    }
    if ((commanderDeck && draw >= 8) || (!commanderDeck && draw >= 6)) {
      strengths.add('$draw cartes de pioche. Le deck se recharge.');
    }
    if (interaction >= (commanderDeck ? 8 : 6)) {
      strengths.add('$interaction cartes d’interaction. Le deck peut répondre.');
    }
    if (threats >= 6 || planeswalkers >= 3) {
      strengths.add('Il y a de quoi finir la partie.');
    }
    if (curve.spells >= 12 && middle >= (curve.spells * 0.35).round()) {
      strengths.add('Le milieu de courbe, à 2 et 3, est fourni.');
    }

    if (illegalShape) {
      final bits = <String>[
        if (offCards.isNotEmpty) 'des cartes sortent de l’identité',
        if (illegalCards.isNotEmpty) 'certaines sont illégales en commandant',
        if (duplicateCards.isNotEmpty) 'des doublons dépassent la limite',
      ];
      sentences.add(
        'La liste n’est pas jouable en l’état : ${_andJoin(bits)}.',
      );
    }
    if (commanderDeck && mainSize != 99 && commanderSize > 0) {
      weaknesses.add(
        'Le deck principal a $mainSize cartes. Un commandant en attend 99, hors réserve.',
      );
    }
    if (sideCards > 15) {
      weaknesses.add('La réserve a $sideCards cartes. Le repère habituel est 15.');
    }
    if (unknown > 0) {
      final shownNames = _names(unknownCards);
      final hidden = unknownCards
          .where((card) => !shownNames.contains(card.name))
          .length;
      final list = shownNames.join(', ');
      final tail = hidden > 0 ? '$list, et $hidden autres noms' : list;
      weaknesses.add(
        '$unknown cartes inconnues : $tail. Leurs rôles ne sont pas comptés.',
      );
    }
    if (offCards.isNotEmpty) {
      weaknesses.add(
        'Hors identité du commandant : ${_names(offCards).join(', ')}.',
      );
    }
    if (duplicateCards.isNotEmpty) {
      final limit = commanderDeck ? 1 : 4;
      weaknesses.add(
        'Doublons au-dessus de $limit : ${_names(duplicateCards).join(', ')}.',
      );
    }
    if (illegalCards.isNotEmpty) {
      weaknesses.add(
        'Interdites ou illégales en commandant : ${_names(illegalCards).join(', ')}.',
      );
    }
    if (setupHeavy) {
      weaknesses.add(
        '$creatures créatures pour ${curve.lands} terrains et $ramp accélérations. '
        'La préparation prend la place des cartes à jouer.',
      );
      sentences.add(
        'Le deck penche vers la préparation : ${curve.lands} terrains, '
        '$ramp accélérations et $draw pioches, pour $creatures créatures'
        '${threats < 6 ? ' et $threats gros sorts' : ''}. '
        'Une fois la mana posée, il reste peu de cartes qui gagnent.',
      );
    } else if (landGap <= -4) {
      weaknesses.add(
        '${curve.lands} terrains pour une moyenne de $avgText. '
        'Le repère est d’environ $target.',
      );
      sentences.add(
        'La mana est trop juste pour la courbe. '
        '${curve.lands} terrains, moyenne $avgText, repère autour de $target. '
        'Les sorts chers restent en main.',
      );
    } else if (landGap >= 4) {
      weaknesses.add(
        '${curve.lands} terrains, soit $landGap de plus que le repère ($target) '
        'pour une moyenne de $avgText.',
      );
    }
    if (shortColors.isNotEmpty) {
      final label = shortColors.join(' et le ');
      weaknesses.add(
        shortColors.length == 1
            ? 'Le $label demande beaucoup de symboles et peu de sources le produisent.'
            : 'Le $label demandent beaucoup de symboles et peu de sources les produisent.',
      );
      sentences.add(
        'La base de mana ne suit pas les couleurs demandées : '
        '${shortColors.join(', ')}.',
      );
    }
    if (commanderDeck && colors >= 3 && fixing < 6 && recognized >= 30 && canCast) {
      weaknesses.add(
        '$colors couleurs et $fixing terrains qui en produisent au moins deux.',
      );
    }
    if (canCast && !setupHeavy && commanderDeck && ramp < 6 && recognized >= 40) {
      weaknesses.add('Peu d’accélération ($ramp) pour un commandant.');
    } else if (commanderDeck && ramp > 16 && !setupHeavy) {
      weaknesses.add(
        '$ramp accélérations : la préparation prend la place des sorts à jouer.',
      );
    }
    if (canCast && draw < (commanderDeck ? 6 : 4) && recognized >= 40) {
      weaknesses.add('Peu de pioche ($draw). Après la mana, la main se vide.');
    }
    if (canCast && interaction < (commanderDeck ? 6 : 4) && recognized >= 40) {
      weaknesses.add(
        'Peu d’interaction ($interaction). Une menace installée reste en jeu.',
      );
    }
    if (canCast &&
        recognized >= 40 &&
        threats == 0 &&
        planeswalkers == 0 &&
        !setupHeavy) {
      weaknesses.add('Aucun sort de fin de partie repéré parmi les cartes lues.');
    }
    if (top > curve.buckets[2] &&
        curve.spells >= 12 &&
        ramp < 8 &&
        landGap > -4) {
      sentences.add(
        'La courbe est lourde : plus de sorts à 6 ou plus qu’à 2, '
        'avec $ramp accélérations.',
      );
    }
    if (curve.spells >= 15 && early == 0) {
      sentences.add('Aucun sort à 1 ou 2. Le premier tour ne pose rien.');
    }
    if (obscure) {
      weaknesses.add(
        '${rareCards.length} sorts sont peu vus dans les decks de commandant recensés. '
        'Ce rang décrit la fréquence de jeu, pas la force de la carte.',
      );
      sentences.add(
        '${rareCards.length} sorts sont peu vus en commandant. '
        'La fréquence ne dit rien de leur force : chacun a besoin d’un rôle.',
      );
    }
    for (final line in curve.advice) {
      if (line.contains('parties enregistrées') ||
          line.contains('durent longtemps')) {
        sentences.add(line);
      }
    }
    if (sentences.isEmpty && canCast) {
      sentences.add(
        commanderDeck
            ? 'Le squelette tient. Taille, terrains et rôles sont dans les repères d’un commandant.'
            : 'Le squelette tient. Taille, terrains et rôles sont dans les repères d’un deck construit.',
      );
    }
  }

  if (illegalShape) {
    final names = _names([...illegalCards, ...offCards, ...duplicateCards], cap: 4);
    advice.add(
      'Commence par rendre la liste jouable : ${names.join(', ')}. '
      'La courbe et les rôles se règlent ensuite, sur des cartes qui peuvent être là.',
    );
  }
  if (setupHeavy) {
    advice.add(
      'La mana est déjà haute. Remplace une partie des terrains au-dessus de $target '
      'et l’accélération au-dessus de dix par des créatures de coût 3 à 6.',
    );
    if (draw >= 10) {
      advice.add(
        '$draw pioches suffisent. Une pioche de plus retire encore une carte qui gagne.',
      );
    }
  } else if (landGap <= -4 || shortColors.isNotEmpty) {
    final colorBit = shortColors.isEmpty
        ? ''
        : ' Ajoute d’abord des sources ${shortColors.join(' et ')}.';
    advice.add(
      'Descends des sorts de 6 ou plus vers des sorts de 2 ou 3, '
      'ou ajoute des terrains vers $target.$colorBit '
      'Les sorts chers n’arrivent que si la mana suit.',
    );
  } else if (landGap >= 4) {
    advice.add(
      'Retire environ $landGap terrains et mets des sorts à la place. '
      'La moyenne de $avgText se lance déjà avec environ $target terrains.',
    );
  }
  if (canCast && !setupHeavy && commanderDeck && ramp < 6 && recognized >= 40) {
    advice.add(
      'Ajoute des accélérations jusqu’autour de dix. '
      'Sans elles, le commandant et les gros sorts arrivent trop tard.',
    );
  }
  if (canCast && interaction < (commanderDeck ? 6 : 4) && recognized >= 40) {
    advice.add(
      'Ajoute des réponses, autour de ${commanderDeck ? 'huit' : 'six'} : '
      'détruire, exiler ou contrer. Le deck se développe, et une menace adverse reste sinon en jeu.',
    );
  } else if (canCast && draw < (commanderDeck ? 6 : 4) && recognized >= 40) {
    advice.add(
      'Ajoute quelques pioches. Une fois les terrains posés, la main se vide et le tour s’arrête.',
    );
  }
  if (canCast && wipes >= 6) {
    advice.add(
      '$wipes cartes vident la table, y compris ton propre plateau. '
      'Deux ou trois suffisent souvent.',
    );
  }
  if (unknown >= 8 && advice.length < 4) {
    advice.add(
      '$unknown cartes n’ont pas été lues. Un nom anglais exact les fait entrer dans le jugement.',
    );
  }
  if (advice.isEmpty && recognized > 0) {
    advice.add(
      'Le squelette est en place. Le réglage suivant se voit en jouant : '
      'les cartes qui restent en main sont celles qui dépassent.',
    );
  }
  if (strengths.isEmpty && recognized > 0 && !illegalShape) {
    strengths.add('Les cartes reconnues ne dégagent pas de point fort net.');
  }
  if (sentences.isEmpty) {
    sentences.add('La lecture n’a pas assez de cartes reconnues pour conclure.');
  }
  return _Reading(
    sentences.join(' '),
    advice.take(4).toList(),
    strengths,
    weaknesses,
  );
}

int _sumCards(List<CurveCard> cards) =>
    cards.fold<int>(0, (total, card) => total + card.count);

String _andJoin(List<String> bits) {
  if (bits.length <= 1) return bits.join();
  if (bits.length == 2) return '${bits[0]} et ${bits[1]}';
  return '${bits.sublist(0, bits.length - 1).join(', ')} et ${bits.last}';
}
