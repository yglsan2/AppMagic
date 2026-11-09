import 'package:mtg_table/domain/handicap.dart';
import 'package:mtg_table/domain/planar_decks.dart';

enum MatchFormat {
  commander,
  treachery,
  duel,
  brawl,
  constructed,
  limited,
  twoHeaded,
  oathbreaker,
  custom,
}

enum TreacheryRole { none, leader, guardian, assassin, traitor }

enum DayState { unset, day, night }

enum ViewMode { auto, table, list, focus }

/// Quelle partie du profil est ouverte.
/// [own] : mes pertes et les commandants reçus.
/// [foes] : points et commandants infligés aux adversaires.
/// [both] : les deux, rien n’est rangé.
enum ScorePane { own, both, foes }

String scorePaneLabel(ScorePane pane) => switch (pane) {
  ScorePane.own => 'Mes pertes',
  ScorePane.both => 'Les deux',
  ScorePane.foes => 'Adversaires',
};

String playerNameKey(String name) => name.trim().toLowerCase();

/// Mode de chronométrage.
enum TimerMode {
  /// Compteur de tour simple + alerte (turnAlertSeconds).
  alert,
  /// Banque de temps par joueur (chess clock).
  chess,
}

enum Stat { poison, energy, experience, rad, speed, treasure, storm, signature }

/// Du plus suivi au plus rare. Tout est encore dans les règles
/// (septembre 2026) : rien de cette liste n’a été retiré.
const statPlayOrder = <Stat>[
  Stat.poison,
  Stat.treasure,
  Stat.energy,
  Stat.experience,
  Stat.storm,
  Stat.rad,
  Stat.speed,
  Stat.signature,
];

const manaKeys = ['W', 'U', 'B', 'R', 'G', 'C'];

/// Ancien paquet de démo — conservé pour compat lecture sessions.
const defaultPlaneNames = [
  'Rivage des lanternes',
  'Bois murmurant',
  'Citadelle brisée',
  'Sables miroir',
  'Tourbière pâle',
  'Crête de foudre',
  'Archipel voilé',
  'Bibliothèque noyée',
  'Nécropole calme',
  'Bazar des ombres',
  'Jardin de verre',
  'Forges endormies',
];

class FormatInfo {
  const FormatInfo({
    required this.format,
    required this.label,
    required this.detail,
    required this.help,
    required this.startingLife,
    required this.commanderDamage,
    required this.commanderTax,
    required this.sharedLife,
    required this.defaultPlayers,
    this.minPlayers = 1,
    this.maxPlayers = 8,
  });

  final MatchFormat format;
  /// Libellé FR (éventuellement avec nom EN entre parenthèses).
  final String label;
  final String detail;
  /// Texte long pour bulle / dialogue d’aide.
  final String help;
  final int startingLife;
  final bool commanderDamage;
  final bool commanderTax;
  final bool sharedLife;
  final int defaultPlayers;
  /// Borne basse du sélecteur de sièges (incluse).
  final int minPlayers;
  /// Borne haute du sélecteur de sièges (incluse).
  final int maxPlayers;

  bool get fixedPlayerCount => minPlayers == maxPlayers;
}

const formatCatalog = <FormatInfo>[
  FormatInfo(
    format: MatchFormat.commander,
    label: 'Commander (EDH)',
    detail: '40 points de vie · 2 à 8 joueurs · 21 dégâts du même commandant',
    help:
        'Un commandant et un deck de 100 cartes. Chacun commence à '
        '40 points de vie. À quatre comme à deux, un joueur perd aussi '
        's’il a reçu 21 points de dégâts de combat du même commandant. '
        'Pour une partie à deux à 20 points de vie, sans cette règle, '
        'choisissez Duel Commander.',
    startingLife: 40,
    commanderDamage: true,
    commanderTax: true,
    sharedLife: false,
    defaultPlayers: 4,
    minPlayers: 2,
    maxPlayers: 8,
  ),
  FormatInfo(
    format: MatchFormat.treachery,
    label: 'Traîtrise (Treachery)',
    detail: 'Commander + rôles secrets (Chef, Traître…)',
    help:
        'Commander, avec des rôles secrets : Chef, Gardien, Assassin, '
        'Traître. Chacun gagne selon son rôle. Les points de vie et le '
        'commandant restent ceux du Commander.',
    startingLife: 40,
    commanderDamage: true,
    commanderTax: true,
    sharedLife: false,
    defaultPlayers: 5,
    minPlayers: 3,
    maxPlayers: 8,
  ),
  FormatInfo(
    format: MatchFormat.duel,
    label: 'Duel Commander',
    detail: '2 joueurs · 20 PV · taxe · sans les 21 dégâts',
    help:
        'Le face-à-face : toujours deux joueurs, 20 points de vie, avec la '
        'taxe de commandant, et sans les 21 points de dégâts. Pour jouer à '
        'deux avec 40 points de vie et cette règle des 21, restez sur '
        'Commander et choisissez 2 joueurs.',
    startingLife: 20,
    commanderDamage: false,
    commanderTax: true,
    sharedLife: false,
    defaultPlayers: 2,
    minPlayers: 2,
    maxPlayers: 2,
  ),
  FormatInfo(
    format: MatchFormat.brawl,
    label: 'Bagarre (Brawl)',
    detail: '25 PV · dégâts de commandant · taxe',
    help:
        'Un commandant et un deck plus petit, souvent en Standard. '
        '25 points de vie, avec la taxe. Plutôt une partie courte, '
        'souvent à deux.',
    startingLife: 25,
    commanderDamage: true,
    commanderTax: true,
    sharedLife: false,
    defaultPlayers: 2,
  ),
  FormatInfo(
    format: MatchFormat.constructed,
    label: 'Construit (60 cartes)',
    detail: '20 PV · deck préparé · sans commandant',
    help:
        'Standard, Moderne, Pioneer, Legacy… Le deck est prêt avant '
        'de s’asseoir, en général 60 cartes. 20 points de vie, sans '
        'commandant.',
    startingLife: 20,
    commanderDamage: false,
    commanderTax: false,
    sharedLife: false,
    defaultPlayers: 2,
  ),
  FormatInfo(
    format: MatchFormat.limited,
    label: 'Limité (draft / scellé)',
    detail: '20 PV · deck du draft · sans commandant',
    help:
        'Draft ou scellé : le deck se monte sur place, avec les boosters '
        'ouverts à la table. 20 points de vie, sans commandant.',
    startingLife: 20,
    commanderDamage: false,
    commanderTax: false,
    sharedLife: false,
    defaultPlayers: 2,
  ),
  FormatInfo(
    format: MatchFormat.twoHeaded,
    label: 'Géant à deux têtes (2HG)',
    detail: '30 PV partagés · équipes de 2',
    help:
        'Deux équipes de deux. Chaque équipe a un seul total de points '
        'de vie, ici 30. Quinze marqueurs poison font perdre, pas dix. '
        'Les dégâts de commandant restent comptés pour chaque joueur. '
        'Les bonus de deck sont coupés, parce que la vie est commune.',
    startingLife: 30,
    commanderDamage: true,
    commanderTax: true,
    sharedLife: true,
    defaultPlayers: 4,
  ),
  FormatInfo(
    format: MatchFormat.oathbreaker,
    label: 'Briseur de serment (Oathbreaker)',
    detail: '20 PV · commandant + sort signature',
    help:
        'Chaque joueur a un planeswalker comme commandant, et un sort '
        'signature. 20 points de vie. La taxe s’ajoute quand on le lance '
        'depuis la zone de commandement. Partie plus courte que le '
        'Commander.',
    startingLife: 20,
    commanderDamage: true,
    commanderTax: true,
    sharedLife: false,
    defaultPlayers: 4,
  ),
  FormatInfo(
    format: MatchFormat.custom,
    label: 'Personnalisé',
    detail: 'Points de vie, seuils et options au choix',
    help:
        'Tout se règle à la main : points de vie, dégâts de commandant, '
        'taxe, Course planaire, Archennemi. Pratique pour une règle '
        'maison.',
    startingLife: 40,
    commanderDamage: true,
    commanderTax: true,
    sharedLife: false,
    defaultPlayers: 4,
  ),
];

FormatInfo formatInfo(MatchFormat format) {
  return formatCatalog.firstWhere((info) => info.format == format);
}

/// 10 par défaut. En Géant à deux têtes, ce 10 officiel n’existe pas :
/// le seuil est 15, sauf si la table a choisi un autre nombre.
int poisonThresholdFor(MatchFormat format, int configured) {
  final value = configured.clamp(1, 30);
  if (format == MatchFormat.twoHeaded && value == 10) return 15;
  return value;
}

int _idSeq = 0;

String newId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idSeq++}';

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

Map<String, int> intMap(Object? raw) {
  if (raw is! Map) return {};
  return raw.map((key, value) => MapEntry('$key', asInt(value)));
}

class Commander {
  Commander({
    required this.id,
    required this.name,
    this.casts = 0,
    this.artUrl,
  });

  final String id;
  String name;
  int casts;
  String? artUrl;

  int get tax => casts * 2;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'casts': casts,
    if (artUrl != null) 'artUrl': artUrl,
  };

  factory Commander.fromJson(Map<String, dynamic> json) {
    return Commander(
      id: json['id'] as String? ?? newId('cmd'),
      name: json['name'] as String? ?? 'Commandant',
      casts: asInt(json['casts']),
      artUrl: json['artUrl'] as String?,
    );
  }
}

class NamedCounter {
  NamedCounter({required this.id, required this.name, this.value = 0});

  final String id;
  String name;
  int value;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'value': value};

  factory NamedCounter.fromJson(Map<String, dynamic> json) {
    return NamedCounter(
      id: json['id'] as String? ?? newId('cnt'),
      name: json['name'] as String? ?? 'Suivi',
      value: asInt(json['value']),
    );
  }
}

class Player {
  Player({
    required this.id,
    required this.name,
    required this.color,
    required this.life,
    required this.mana,
    List<Commander>? commanders,
    Map<String, int>? damageTaken,
    Map<String, int>? lifeDrainedByCommander,
    List<NamedCounter>? custom,
    this.poison = 0,
    this.energy = 0,
    this.experience = 0,
    this.rad = 0,
    this.speed = 0,
    this.treasure = 0,
    this.storm = 0,
    this.signatureCasts = 0,
    this.signatureName = 'Sort signature',
    this.blessing = false,
    this.ring = 0,
    this.conceded = false,
    this.treacheryRole = TreacheryRole.none,
    this.treacheryRevealed = false,
    this.deckBracket = DeckBracket.fair,
    int? handicapLifeDelta,
    this.panelArtUrl,
    this.clockBankMs = 0,
  }) : handicapLifeDelta = clampHandicapLife(
         handicapLifeDelta ?? deckBracket.suggestedLifeDelta,
       ),
       commanders = commanders ?? [],
       damageTaken = damageTaken ?? {},
       lifeDrainedByCommander = lifeDrainedByCommander ?? {},
       custom = custom ?? [];

  final String id;
  String name;
  int color;
  int life;
  /// Illustration plein panneau (Scryfall) — sinon art du 1er commandant.
  String? panelArtUrl;
  /// Banque chess clock restante (ms).
  int clockBankMs;
  List<Commander> commanders;

  String? get displayArtUrl {
    if (panelArtUrl != null && panelArtUrl!.isNotEmpty) return panelArtUrl;
    for (final commander in commanders) {
      if (commander.artUrl != null && commander.artUrl!.isNotEmpty) {
        return commander.artUrl;
      }
    }
    return null;
  }
  Map<String, int> damageTaken;
  /// PV réellement retirés via le suivi de commandant (évite de « créer » de la vie en corrigeant).
  Map<String, int> lifeDrainedByCommander;
  int poison;
  int energy;
  int experience;
  int rad;
  int speed;
  int treasure;
  int storm;
  int signatureCasts;
  String signatureName;
  bool blessing;
  int ring;
  bool conceded;
  TreacheryRole treacheryRole;
  bool treacheryRevealed;
  /// Libellé du palier (raccourci ou [DeckBracket.custom]).
  DeckBracket deckBracket;
  /// Bonus / malus de PV de départ (−30…+30) — source de vérité.
  int handicapLifeDelta;
  Map<String, int> mana;
  List<NamedCounter> custom;

  int handicapDelta(bool enabled) {
    if (!enabled) return 0;
    return clampHandicapLife(handicapLifeDelta);
  }

  int startingLifeFor(Game game) {
    return effectiveStartingLife(
      baseLife: game.startingLife,
      handicapsEnabled: game.handicapsEnabled,
      lifeDelta: handicapLifeDelta,
    );
  }

  int readStat(Stat stat) {
    return switch (stat) {
      Stat.poison => poison,
      Stat.energy => energy,
      Stat.experience => experience,
      Stat.rad => rad,
      Stat.speed => speed,
      Stat.treasure => treasure,
      Stat.storm => storm,
      Stat.signature => signatureCasts,
    };
  }

  void writeStat(Stat stat, int value) {
    switch (stat) {
      case Stat.poison:
        poison = value;
      case Stat.energy:
        energy = value;
      case Stat.experience:
        experience = value;
      case Stat.rad:
        rad = value;
      case Stat.speed:
        speed = value;
      case Stat.treasure:
        treasure = value;
      case Stat.storm:
        storm = value;
      case Stat.signature:
        signatureCasts = value;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'life': life,
    'commanders': commanders.map((c) => c.toJson()).toList(),
    'damageTaken': Map<String, int>.from(damageTaken),
    'lifeDrainedByCommander': Map<String, int>.from(lifeDrainedByCommander),
    'poison': poison,
    'energy': energy,
    'experience': experience,
    'rad': rad,
    'speed': speed,
    'treasure': treasure,
    'storm': storm,
    'signatureCasts': signatureCasts,
    'signatureName': signatureName,
    'blessing': blessing,
    'ring': ring,
    'conceded': conceded,
    'treacheryRole': treacheryRole.name,
    'treacheryRevealed': treacheryRevealed,
    'deckBracket': deckBracket.name,
    'handicapLifeDelta': handicapLifeDelta,
    'mana': Map<String, int>.from(mana),
    'custom': custom.map((c) => c.toJson()).toList(),
    'panelArtUrl': panelArtUrl,
    'clockBankMs': clockBankMs,
  };

  factory Player.fromJson(Map<String, dynamic> json) {
    final mana = {for (final key in manaKeys) key: 0};
    mana.addAll(intMap(json['mana']));
    final bracket = deckBracketFromName(json['deckBracket'] as String?);
    final legacyFine = asInt(json['handicapFineTune']);
    final storedDelta = json['handicapLifeDelta'];
    final lifeDelta = storedDelta != null
        ? clampHandicapLife(asInt(storedDelta))
        : clampHandicapLife(bracket.suggestedLifeDelta + legacyFine);
    return Player(
      id: json['id'] as String? ?? newId('p'),
      name: json['name'] as String? ?? 'Joueur',
      color: asInt(json['color']),
      life: asInt(json['life'], 40),
      commanders: [
        for (final raw in (json['commanders'] as List? ?? []))
          if (raw is Map<String, dynamic>)
            Commander.fromJson(raw)
          else if (raw is Map)
            Commander.fromJson(Map<String, dynamic>.from(raw)),
      ],
      damageTaken: intMap(json['damageTaken']),
      lifeDrainedByCommander: intMap(json['lifeDrainedByCommander']),
      custom: [
        for (final raw in (json['custom'] as List? ?? []))
          if (raw is Map<String, dynamic>)
            NamedCounter.fromJson(raw)
          else if (raw is Map)
            NamedCounter.fromJson(Map<String, dynamic>.from(raw)),
      ],
      poison: asInt(json['poison']),
      energy: asInt(json['energy']),
      experience: asInt(json['experience']),
      rad: asInt(json['rad']),
      speed: asInt(json['speed']),
      treasure: asInt(json['treasure']),
      storm: asInt(json['storm']),
      signatureCasts: asInt(json['signatureCasts']),
      signatureName: json['signatureName'] as String? ?? 'Sort signature',
      blessing: json['blessing'] as bool? ?? false,
      ring: asInt(json['ring']),
      conceded: json['conceded'] as bool? ?? false,
      treacheryRole: TreacheryRole.values.firstWhere(
        (role) => role.name == json['treacheryRole'],
        orElse: () => TreacheryRole.none,
      ),
      treacheryRevealed: json['treacheryRevealed'] as bool? ?? false,
      deckBracket: bracketMatchingLifeDelta(lifeDelta),
      handicapLifeDelta: lifeDelta,
      mana: mana,
      panelArtUrl: json['panelArtUrl'] as String?,
      clockBankMs: asInt(json['clockBankMs']),
    );
  }
}

String treacheryRoleLabel(TreacheryRole role) {
  return switch (role) {
    TreacheryRole.none => 'Sans rôle',
    TreacheryRole.leader => 'Chef (Leader)',
    TreacheryRole.guardian => 'Gardien (Guardian)',
    TreacheryRole.assassin => 'Assassin',
    TreacheryRole.traitor => 'Traître (Traitor)',
  };
}

class Game {
  Game({
    required this.format,
    required this.startingLife,
    required this.commanderThreshold,
    required this.poisonThreshold,
    required this.trackCommanderDamage,
    required this.trackCommanderTax,
    required this.sharedLife,
    required this.linkDamageToLife,
    required this.resetManaOnTurn,
    required this.resetStormOnTurn,
    required this.turnAlertSeconds,
    required this.players,
    required this.planes,
    List<String>? schemes,
    this.activeIndex = 0,
    this.roundNumber = 1,
    this.turnCount = 1,
    this.monarchId,
    this.initiativeId,
    this.dayState = DayState.unset,
    this.planechase = false,
    this.planeIndex = 0,
    this.archenemy = false,
    this.archenemyId,
    this.schemeIndex = 0,
    this.schemeNumber = 0,
    this.bounty = false,
    this.bountyLevel = 0,
    this.seatShift = 0,
    this.handicapsEnabled = false,
    this.timerMode = TimerMode.alert,
    this.timersEnabled = false,
    this.chessBankSeconds = 1200,
  }) : schemes = schemes ?? [];

  MatchFormat format;
  int startingLife;
  int commanderThreshold;
  int poisonThreshold;
  bool trackCommanderDamage;
  bool trackCommanderTax;
  bool sharedLife;
  /// Legacy JSON / MTGS1 — toujours `true` (dégâts de combat → PV).
  bool linkDamageToLife;
  bool resetManaOnTurn;
  bool resetStormOnTurn;
  int turnAlertSeconds;
  List<Player> players;
  int activeIndex;
  int roundNumber;
  int turnCount;
  String? monarchId;
  String? initiativeId;
  DayState dayState;
  bool planechase;
  List<String> planes;
  int planeIndex;
  bool archenemy;
  String? archenemyId;
  List<String> schemes;
  int schemeIndex;
  /// Compteur legacy (parties anciennes) — préférer [schemeIndex] + [schemes].
  int schemeNumber;
  bool bounty;
  int bountyLevel;
  int seatShift;
  /// Handicaps de niveau de deck (PV de départ ajustés).
  bool handicapsEnabled;
  TimerMode timerMode;
  /// Faux : aucun chrono n’est affiché ni imposé.
  bool timersEnabled;
  int chessBankSeconds;

  factory Game.start({
    MatchFormat format = MatchFormat.commander,
    int playerCount = 4,
    int? startingLife,
    bool? trackCommanderDamage,
    bool? trackCommanderTax,
    bool? sharedLife,
    bool resetManaOnTurn = true,
    bool resetStormOnTurn = true,
    int commanderThreshold = 21,
    int poisonThreshold = 10,
    int turnAlertSeconds = 90,
    TimerMode timerMode = TimerMode.alert,
    bool timersEnabled = false,
    int chessBankSeconds = 1200,
    bool planechase = false,
    bool archenemy = false,
    bool bounty = false,
    bool handicapsEnabled = false,
    List<String>? names,
    List<int>? colors,
    List<List<String>>? commanderNames,
    List<List<String?>>? commanderArts,
    List<DeckBracket>? deckBrackets,
    List<int>? handicapLifeDeltas,
  }) {
    final info = formatInfo(format);
    final life = startingLife ?? info.startingLife;
    final damage = trackCommanderDamage ?? info.commanderDamage;
    final tax = trackCommanderTax ?? info.commanderTax;
    final shared = sharedLife ?? info.sharedLife;
    // Two-Headed : une seule jauge — les handicaps individuels n’ont pas de sens.
    final useHandicaps = handicapsEnabled && !shared;
    final count = playerCount.clamp(1, 8);
    final planes = shuffledPlaneNames();
    final schemes = shuffledSchemeNames();
    final players = <Player>[];
    for (var i = 0; i < count; i++) {
      final commanders = <Commander>[];
      final provided = commanderNames != null && i < commanderNames.length
          ? commanderNames[i]
          : null;
      final arts = commanderArts != null && i < commanderArts.length
          ? commanderArts[i]
          : null;
      if (provided != null) {
        for (var k = 0; k < provided.length && k < 4; k++) {
          final raw = provided[k].trim();
          commanders.add(
            Commander(
              id: newId('cmd'),
              name: raw.isEmpty ? 'Commandant ${k + 1}' : raw,
              artUrl: arts != null && k < arts.length ? arts[k] : null,
            ),
          );
        }
      } else if (damage || tax) {
        commanders.add(Commander(id: newId('cmd'), name: 'Commandant'));
      }
      final rawName = names != null && i < names.length ? names[i].trim() : '';
      final bracket =
          deckBrackets != null && i < deckBrackets.length
          ? deckBrackets[i]
          : DeckBracket.fair;
      final delta = handicapLifeDeltas != null && i < handicapLifeDeltas.length
          ? clampHandicapLife(handicapLifeDeltas[i])
          : bracket.suggestedLifeDelta;
      final resolvedBracket = handicapLifeDeltas != null
          ? bracketMatchingLifeDelta(delta)
          : bracket;
      final start = effectiveStartingLife(
        baseLife: life,
        handicapsEnabled: useHandicaps,
        lifeDelta: delta,
      );
      players.add(
        Player(
          id: newId('p'),
          name: rawName.isEmpty ? 'Joueur ${i + 1}' : rawName,
          color: colors != null && i < colors.length ? colors[i] : i,
          life: start,
          commanders: commanders,
          deckBracket: resolvedBracket,
          handicapLifeDelta: delta,
          mana: {for (final key in manaKeys) key: 0},
          clockBankMs: chessBankSeconds * 1000,
        ),
      );
    }
    return Game(
      format: format,
      startingLife: life,
      commanderThreshold: commanderThreshold,
      poisonThreshold: poisonThreshold,
      trackCommanderDamage: damage,
      trackCommanderTax: tax,
      sharedLife: shared,
      // Toujours liés aux PV (CR) — champ conservé pour compat MTGS1.
      linkDamageToLife: true,
      resetManaOnTurn: resetManaOnTurn,
      resetStormOnTurn: resetStormOnTurn,
      turnAlertSeconds: turnAlertSeconds,
      timerMode: timerMode,
      timersEnabled: timersEnabled,
      chessBankSeconds: chessBankSeconds,
      planechase: planechase,
      archenemy: archenemy,
      archenemyId: archenemy && players.isNotEmpty ? players.first.id : null,
      planes: planes,
      schemes: schemes,
      bounty: bounty,
      players: players,
      handicapsEnabled: useHandicaps,
    );
  }

  Player playerById(String id) {
    return players.firstWhere((player) => player.id == id);
  }

  int indexOf(String id) => players.indexWhere((player) => player.id == id);

  int commanderRemaining(Player player, String commanderId) {
    final taken = player.damageTaken[commanderId] ?? 0;
    return (commanderThreshold - taken).clamp(0, commanderThreshold);
  }

  bool commanderLethal(Player player) {
    if (!trackCommanderDamage) return false;
    return player.damageTaken.values.any(
      (value) => value >= commanderThreshold,
    );
  }

  bool poisonLethal(Player player) => player.poison >= poisonThreshold;

  bool lifeLethal(Player player) => player.life <= 0;

  bool isDefeated(Player player) {
    return player.conceded ||
        commanderLethal(player) ||
        poisonLethal(player) ||
        lifeLethal(player);
  }

  List<Player> get alive =>
      players.where((player) => !isDefeated(player)).toList();

  /// Titre doux à l’écran (style Lotus : « knocked out », pas un cri).
  String defeatTitle(Player player) {
    if (player.conceded) return 'A quitté la table';
    if (commanderLethal(player)) return 'Hors jeu';
    if (poisonLethal(player)) return 'Hors jeu';
    if (lifeLethal(player)) return 'À terre';
    return 'Hors jeu';
  }

  String? lethalBanner(Player player) {
    final reasons = <String>[];
    if (player.conceded) reasons.add('Concession');
    if (lifeLethal(player)) reasons.add('Plus de points de vie');
    if (poisonLethal(player)) {
      reasons.add('$poisonThreshold marqueurs poison');
    }
    if (trackCommanderDamage) {
      for (final entry in player.damageTaken.entries) {
        if (entry.value >= commanderThreshold) {
          reasons.add(
            'Dégâts de ${_commanderLabel(entry.key)} ($commanderThreshold)',
          );
        }
      }
    }
    if (reasons.isEmpty) return null;
    return reasons.join(' · ');
  }

  /// Joueurs encore en lice qui forment le camp vainqueur (solo ou équipe 2HG).
  List<Player> winningPlayers() {
    final standing = alive;
    if (players.length < 2 || standing.isEmpty) return const [];
    if (sharedLife) {
      final teams = <int>{};
      for (var i = 0; i < players.length; i++) {
        if (!isDefeated(players[i])) teams.add(i ~/ 2);
      }
      if (teams.length != 1) return const [];
      return standing;
    }
    if (standing.length != 1) return const [];
    return standing;
  }

  /// Libellé vainqueur pour archive / récap (« Ana » ou « Ana & Bo »).
  String? winnerLabel() {
    final winners = winningPlayers();
    if (winners.isEmpty) return null;
    return winners.map((player) => player.name).join(' & ');
  }

  /// Bandeau quand un camp a gagné (1 joueur ou équipe Two-Headed).
  String? victoryBanner() {
    final winners = winningPlayers();
    if (winners.isEmpty) return null;
    if (winners.length > 1) {
      return '${winners.map((p) => p.name).join(' & ')} gagnent la partie';
    }
    return '${winners.first.name} gagne la partie';
  }

  String _commanderLabel(String commanderId) {
    for (final player in players) {
      for (final commander in player.commanders) {
        if (commander.id == commanderId) {
          return commanderChipLabel(player, commander);
        }
      }
    }
    return 'commandant';
  }

  String get currentPlane {
    if (planes.isEmpty) return 'Plan';
    final index = planeIndex.clamp(0, planes.length - 1);
    return planes[index];
  }

  String get currentPlaneChaos => chaosForPlane(currentPlane);

  String get currentScheme {
    if (schemes.isEmpty) {
      return schemeNumber > 0 ? 'Stratagème $schemeNumber' : 'Stratagème';
    }
    final index = schemeIndex.clamp(0, schemes.length - 1);
    return schemes[index];
  }

  String get currentSchemeEffect => effectForScheme(currentScheme);

  BountyCard get currentBounty => bountyAtLevel(bountyLevel);

  bool get tracksCommanders => trackCommanderDamage || trackCommanderTax;

  Map<String, dynamic> toJson() => {
    'format': format.name,
    'startingLife': startingLife,
    'commanderThreshold': commanderThreshold,
    'poisonThreshold': poisonThreshold,
    'trackCommanderDamage': trackCommanderDamage,
    'trackCommanderTax': trackCommanderTax,
    'sharedLife': sharedLife,
    'linkDamageToLife': linkDamageToLife,
    'resetManaOnTurn': resetManaOnTurn,
    'resetStormOnTurn': resetStormOnTurn,
    'turnAlertSeconds': turnAlertSeconds,
    'timerMode': timerMode.name,
    'timersEnabled': timersEnabled,
    'chessBankSeconds': chessBankSeconds,
    'players': players.map((player) => player.toJson()).toList(),
    'activeIndex': activeIndex,
    'roundNumber': roundNumber,
    'turnCount': turnCount,
    'monarchId': monarchId,
    'initiativeId': initiativeId,
    'dayState': dayState.name,
    'planechase': planechase,
    'planes': planes,
    'planeIndex': planeIndex,
    'archenemy': archenemy,
    'archenemyId': archenemyId,
    'schemes': schemes,
    'schemeIndex': schemeIndex,
    'schemeNumber': schemeNumber,
    'bounty': bounty,
    'bountyLevel': bountyLevel,
    'seatShift': seatShift,
    'handicapsEnabled': handicapsEnabled,
  };

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      format: MatchFormat.values.firstWhere(
        (format) => format.name == json['format'],
        orElse: () => MatchFormat.commander,
      ),
      startingLife: asInt(json['startingLife'], 40),
      commanderThreshold: asInt(json['commanderThreshold'], 21),
      poisonThreshold: asInt(json['poisonThreshold'], 10),
      trackCommanderDamage: json['trackCommanderDamage'] as bool? ?? true,
      trackCommanderTax: json['trackCommanderTax'] as bool? ?? true,
      sharedLife: json['sharedLife'] as bool? ?? false,
      linkDamageToLife: true,
      resetManaOnTurn: json['resetManaOnTurn'] as bool? ?? true,
      resetStormOnTurn: json['resetStormOnTurn'] as bool? ?? true,
      turnAlertSeconds: asInt(json['turnAlertSeconds'], 90),
      timerMode: TimerMode.values.firstWhere(
        (mode) => mode.name == json['timerMode'],
        orElse: () => TimerMode.alert,
      ),
      timersEnabled: json['timersEnabled'] as bool? ?? false,
      chessBankSeconds: asInt(json['chessBankSeconds'], 1200),
      players: [
        for (final raw in (json['players'] as List? ?? []))
          if (raw is Map<String, dynamic>)
            Player.fromJson(raw)
          else if (raw is Map)
            Player.fromJson(Map<String, dynamic>.from(raw)),
      ],
      activeIndex: asInt(json['activeIndex']),
      roundNumber: asInt(json['roundNumber'], 1),
      turnCount: asInt(json['turnCount'], 1),
      monarchId: json['monarchId'] as String?,
      initiativeId: json['initiativeId'] as String?,
      dayState: DayState.values.firstWhere(
        (state) => state.name == json['dayState'],
        orElse: () => DayState.unset,
      ),
      planechase: json['planechase'] as bool? ?? false,
      planes: [for (final plane in (json['planes'] as List? ?? [])) '$plane'],
      planeIndex: asInt(json['planeIndex']),
      archenemy: json['archenemy'] as bool? ?? false,
      archenemyId: json['archenemyId'] as String?,
      schemes: [
        for (final scheme in (json['schemes'] as List? ?? [])) '$scheme',
      ],
      schemeIndex: asInt(json['schemeIndex']),
      schemeNumber: asInt(json['schemeNumber']),
      bounty: json['bounty'] as bool? ?? false,
      bountyLevel: asInt(json['bountyLevel']),
      seatShift: asInt(json['seatShift']),
      handicapsEnabled: json['handicapsEnabled'] as bool? ?? false,
    );
  }
}

bool isGenericCommanderName(String name) {
  final trimmed = name.trim();
  return RegExp(
    r'^(Commandant|Cdt|Cmd)( \d+)?$',
    caseSensitive: false,
  ).hasMatch(trimmed);
}

/// Libellé court et clair sur la table : « Cdt Alice », « Cdt Bob · 2 », etc.
String commanderChipLabel(Player owner, Commander commander) {
  final multiple = owner.commanders.length > 1;
  final generic = isGenericCommanderName(commander.name);
  if (!multiple) {
    return generic ? 'Cdt ${owner.name}' : 'Cdt ${commander.name}';
  }
  final index =
      owner.commanders.indexWhere((item) => item.id == commander.id) + 1;
  if (generic) return 'Cdt ${owner.name} · $index';
  return 'Cdt ${owner.name} · ${commander.name}';
}

String statLabel(Stat stat) {
  return switch (stat) {
    Stat.poison => 'Poison',
    Stat.energy => 'Énergie',
    Stat.experience => 'Expérience',
    Stat.rad => 'Radiation',
    Stat.speed => 'Vitesse',
    Stat.treasure => 'Trésors',
    Stat.storm => 'Tempête',
    Stat.signature => 'Sort signature',
  };
}

/// Un changement de PV (ou note liée) depuis le début de la partie.
class LifeChange {
  const LifeChange({
    required this.playerId,
    required this.playerName,
    required this.from,
    required this.to,
    required this.delta,
    required this.turnCount,
    required this.roundNumber,
    this.reason,
    this.atMs,
  });

  final String playerId;
  final String playerName;
  final int from;
  final int to;
  final int delta;
  final int turnCount;
  final int roundNumber;
  final String? reason;
  final int? atMs;

  String get deltaLabel => delta > 0
      ? '+$delta'
      : delta < 0
      ? '$delta'
      : '·';

  String get summary {
    if (from == to && reason != null) {
      return '$playerName · $reason';
    }
    return '$playerName $from → $to';
  }

  String get line {
    if (from == to && reason != null) {
      return '$playerName · $reason';
    }
    final d = deltaLabel == '·' ? '' : ' ($deltaLabel)';
    final why = reason == null ? '' : ' · $reason';
    return '$playerName $from → $to$d$why';
  }

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'playerName': playerName,
    'from': from,
    'to': to,
    'delta': delta,
    'turnCount': turnCount,
    'roundNumber': roundNumber,
    if (reason != null) 'reason': reason,
    if (atMs != null) 'atMs': atMs,
  };

  factory LifeChange.fromJson(Map<String, dynamic> json) {
    final from = asInt(json['from']);
    final to = asInt(json['to']);
    return LifeChange(
      playerId: '${json['playerId'] ?? ''}',
      playerName: '${json['playerName'] ?? '?'}',
      from: from,
      to: to,
      delta: json['delta'] is int ? json['delta'] as int : to - from,
      turnCount: asInt(json['turnCount'], 1),
      roundNumber: asInt(json['roundNumber'], 1),
      reason: json['reason'] as String?,
      atMs: json['atMs'] is int ? json['atMs'] as int : null,
    );
  }
}

/// Fenêtre de fusion des taps rapides (style Lifetap / Portal Counters).
const lifeDeltaMergeMs = 1400;

/// Un changement de dégâts de commandant (total infligé).
class CmdDamageChange {
  const CmdDamageChange({
    required this.defenderId,
    required this.defenderName,
    required this.commanderId,
    required this.commanderLabel,
    required this.fromTaken,
    required this.toTaken,
    required this.delta,
    required this.turnCount,
    required this.roundNumber,
    this.lifeFrom,
    this.lifeTo,
    this.atMs,
  });

  final String defenderId;
  final String defenderName;
  final String commanderId;
  final String commanderLabel;
  final int fromTaken;
  final int toTaken;
  final int delta;
  final int turnCount;
  final int roundNumber;
  final int? lifeFrom;
  final int? lifeTo;
  final int? atMs;

  String get deltaLabel => delta > 0
      ? '+$delta'
      : delta < 0
      ? '$delta'
      : '·';

  String get summary => '$commanderLabel → $defenderName · $fromTaken → $toTaken';

  String get line {
    final life = (lifeFrom != null && lifeTo != null && lifeFrom != lifeTo)
        ? ' · PV $lifeFrom→$lifeTo'
        : '';
    return '$summary ($deltaLabel)$life';
  }

  Map<String, dynamic> toJson() => {
    'defenderId': defenderId,
    'defenderName': defenderName,
    'commanderId': commanderId,
    'commanderLabel': commanderLabel,
    'fromTaken': fromTaken,
    'toTaken': toTaken,
    'delta': delta,
    'turnCount': turnCount,
    'roundNumber': roundNumber,
    if (lifeFrom != null) 'lifeFrom': lifeFrom,
    if (lifeTo != null) 'lifeTo': lifeTo,
    if (atMs != null) 'atMs': atMs,
  };

  factory CmdDamageChange.fromJson(Map<String, dynamic> json) {
    final from = asInt(json['fromTaken']);
    final to = asInt(json['toTaken']);
    return CmdDamageChange(
      defenderId: '${json['defenderId'] ?? ''}',
      defenderName: '${json['defenderName'] ?? '?'}',
      commanderId: '${json['commanderId'] ?? ''}',
      commanderLabel: '${json['commanderLabel'] ?? 'Cdt'}',
      fromTaken: from,
      toTaken: to,
      delta: json['delta'] is int ? json['delta'] as int : to - from,
      turnCount: asInt(json['turnCount'], 1),
      roundNumber: asInt(json['roundNumber'], 1),
      lifeFrom: json['lifeFrom'] is int ? json['lifeFrom'] as int : null,
      lifeTo: json['lifeTo'] is int ? json['lifeTo'] as int : null,
      atMs: json['atMs'] is int ? json['atMs'] as int : null,
    );
  }
}

Map<String, ScorePane> _namedPanes(Object? raw) {
  if (raw is! Map) return const {};
  final panes = <String, ScorePane>{};
  for (final entry in raw.entries) {
    final name = '${entry.key}'.trim();
    if (name.isEmpty) continue;
    for (final pane in ScorePane.values) {
      if (pane.name == entry.value) {
        panes[name] = pane;
        break;
      }
    }
  }
  return panes;
}

class AppSettings {
  const AppSettings({
    required this.haptic,
    required this.resetManaOnTurn,
    required this.resetStormOnTurn,
    required this.viewMode,
    required this.commanderThreshold,
    required this.poisonThreshold,
    required this.turnAlertSeconds,
    required this.timerMode,
    required this.timersEnabled,
    required this.chessBankSeconds,
    required this.coachSeen,
    required this.showLifeFeed,
    required this.rememberCommanderLog,
    required this.cardJournalAssist,
    required this.handicapsEnabled,
    required this.beginnerTips,
    required this.scorePane,
    required this.namedPanes,
  });

  static const defaults = AppSettings(
    haptic: true,
    resetManaOnTurn: true,
    resetStormOnTurn: true,
    viewMode: ViewMode.auto,
    commanderThreshold: 21,
    poisonThreshold: 10,
    turnAlertSeconds: 90,
    timerMode: TimerMode.alert,
    timersEnabled: false,
    chessBankSeconds: 1200,
    coachSeen: false,
    showLifeFeed: true,
    rememberCommanderLog: true,
    cardJournalAssist: true,
    handicapsEnabled: false,
    beginnerTips: false,
    scorePane: ScorePane.foes,
    namedPanes: {},
  );

  final bool haptic;
  final bool resetManaOnTurn;
  final bool resetStormOnTurn;
  final ViewMode viewMode;
  final int commanderThreshold;
  final int poisonThreshold;
  final int turnAlertSeconds;
  final TimerMode timerMode;
  /// Chronomètre affiché et alertes. Désactivé par défaut.
  final bool timersEnabled;
  /// Banque initiale chess clock (secondes par joueur).
  final int chessBankSeconds;
  final bool coachSeen;
  final bool showLifeFeed;
  /// Historique local des coups de commandant (pris / reste avant la défaite).
  final bool rememberCommanderLog;
  /// Journal Scryfall + suggestions d’effets (option, confirmation joueur).
  final bool cardJournalAssist;
  /// Handicaps de niveau de deck (PV de départ).
  final bool handicapsEnabled;
  /// Bulles d’aide (appui long / survol) sur Monarque, poison, etc.
  final bool beginnerTips;
  /// Affichage quand le pseudo n’a pas de préférence enregistrée.
  final ScorePane scorePane;

  /// Affichage retenu par pseudo, d’une partie à l’autre.
  final Map<String, ScorePane> namedPanes;

  ScorePane paneNamed(String name) {
    final key = playerNameKey(name);
    if (key.isEmpty) return scorePane;
    for (final entry in namedPanes.entries) {
      if (playerNameKey(entry.key) == key) return entry.value;
    }
    return scorePane;
  }

  AppSettings savingPane(String name, ScorePane pane) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return this;
    final next = <String, ScorePane>{};
    for (final entry in namedPanes.entries) {
      if (playerNameKey(entry.key) != playerNameKey(trimmed)) {
        next[entry.key] = entry.value;
      }
    }
    next[trimmed] = pane;
    return copyWith(namedPanes: next);
  }

  AppSettings forgettingPane(String name) {
    final next = <String, ScorePane>{};
    for (final entry in namedPanes.entries) {
      if (playerNameKey(entry.key) != playerNameKey(name)) {
        next[entry.key] = entry.value;
      }
    }
    return copyWith(namedPanes: next);
  }

  AppSettings copyWith({
    bool? haptic,
    bool? resetManaOnTurn,
    bool? resetStormOnTurn,
    ViewMode? viewMode,
    int? commanderThreshold,
    int? poisonThreshold,
    int? turnAlertSeconds,
    TimerMode? timerMode,
    bool? timersEnabled,
    int? chessBankSeconds,
    bool? coachSeen,
    bool? showLifeFeed,
    bool? rememberCommanderLog,
    bool? cardJournalAssist,
    bool? handicapsEnabled,
    bool? beginnerTips,
    ScorePane? scorePane,
    Map<String, ScorePane>? namedPanes,
  }) {
    return AppSettings(
      haptic: haptic ?? this.haptic,
      resetManaOnTurn: resetManaOnTurn ?? this.resetManaOnTurn,
      resetStormOnTurn: resetStormOnTurn ?? this.resetStormOnTurn,
      viewMode: viewMode ?? this.viewMode,
      commanderThreshold: commanderThreshold ?? this.commanderThreshold,
      poisonThreshold: poisonThreshold ?? this.poisonThreshold,
      turnAlertSeconds: turnAlertSeconds ?? this.turnAlertSeconds,
      timerMode: timerMode ?? this.timerMode,
      timersEnabled: timersEnabled ?? this.timersEnabled,
      chessBankSeconds: chessBankSeconds ?? this.chessBankSeconds,
      coachSeen: coachSeen ?? this.coachSeen,
      showLifeFeed: showLifeFeed ?? this.showLifeFeed,
      rememberCommanderLog:
          rememberCommanderLog ?? this.rememberCommanderLog,
      cardJournalAssist: cardJournalAssist ?? this.cardJournalAssist,
      handicapsEnabled: handicapsEnabled ?? this.handicapsEnabled,
      beginnerTips: beginnerTips ?? this.beginnerTips,
      scorePane: scorePane ?? this.scorePane,
      namedPanes: namedPanes ?? this.namedPanes,
    );
  }

  Map<String, dynamic> toJson() => {
    'haptic': haptic,
    'resetManaOnTurn': resetManaOnTurn,
    'resetStormOnTurn': resetStormOnTurn,
    'viewMode': viewMode.name,
    'commanderThreshold': commanderThreshold,
    'poisonThreshold': poisonThreshold,
    'turnAlertSeconds': turnAlertSeconds,
    'timerMode': timerMode.name,
    'timersEnabled': timersEnabled,
    'chessBankSeconds': chessBankSeconds,
    'coachSeen': coachSeen,
    'showLifeFeed': showLifeFeed,
    'rememberCommanderLog': rememberCommanderLog,
    'cardJournalAssist': cardJournalAssist,
    'handicapsEnabled': handicapsEnabled,
    'beginnerTips': beginnerTips,
    'scorePane': scorePane.name,
    'namedPanes': {
      for (final entry in namedPanes.entries) entry.key: entry.value.name,
    },
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      haptic: json['haptic'] as bool? ?? true,
      resetManaOnTurn: json['resetManaOnTurn'] as bool? ?? true,
      resetStormOnTurn: json['resetStormOnTurn'] as bool? ?? true,
      viewMode: ViewMode.values.firstWhere(
        (mode) => mode.name == json['viewMode'],
        orElse: () => ViewMode.auto,
      ),
      commanderThreshold: asInt(json['commanderThreshold'], 21),
      poisonThreshold: asInt(json['poisonThreshold'], 10),
      turnAlertSeconds: asInt(json['turnAlertSeconds'], 90),
      timerMode: TimerMode.values.firstWhere(
        (mode) => mode.name == json['timerMode'],
        orElse: () => TimerMode.alert,
      ),
      timersEnabled: json['timersEnabled'] as bool? ?? false,
      chessBankSeconds: asInt(json['chessBankSeconds'], 1200),
      coachSeen: json['coachSeen'] as bool? ?? false,
      showLifeFeed: json['showLifeFeed'] as bool? ?? true,
      rememberCommanderLog: json['rememberCommanderLog'] as bool? ?? true,
      cardJournalAssist: json['cardJournalAssist'] as bool? ?? true,
      handicapsEnabled: json['handicapsEnabled'] as bool? ?? false,
      beginnerTips: json['beginnerTips'] as bool? ?? false,
      scorePane: ScorePane.values.firstWhere(
        (pane) => pane.name == json['scorePane'],
        orElse: () =>
            json['selfScoring'] == true ? ScorePane.own : ScorePane.foes,
      ),
      namedPanes: _namedPanes(json['namedPanes']),
    );
  }
}

class PlaygroupPlayer {
  const PlaygroupPlayer({
    required this.name,
    required this.color,
    required this.commanders,
    this.commanderArts = const [],
    this.deckBracket = DeckBracket.fair,
    this.handicapLifeDelta = 0,
  });

  final String name;
  final int color;
  final List<String> commanders;
  final List<String?> commanderArts;
  final DeckBracket deckBracket;
  final int handicapLifeDelta;

  Map<String, dynamic> toJson() => {
    'name': name,
    'color': color,
    'commanders': commanders,
    'commanderArts': commanderArts,
    'deckBracket': deckBracket.name,
    'handicapLifeDelta': handicapLifeDelta,
  };

  factory PlaygroupPlayer.fromJson(Map<String, dynamic> json) {
    final commanders = [
      for (final name in (json['commanders'] as List? ?? [])) '$name',
    ];
    final artsRaw = json['commanderArts'] as List? ?? const [];
    final bracket = deckBracketFromName(json['deckBracket'] as String?);
    final legacyFine = asInt(json['handicapFineTune']);
    final stored = json['handicapLifeDelta'];
    final delta = stored != null
        ? clampHandicapLife(asInt(stored))
        : clampHandicapLife(bracket.suggestedLifeDelta + legacyFine);
    return PlaygroupPlayer(
      name: json['name'] as String? ?? '',
      color: asInt(json['color']),
      commanders: commanders,
      commanderArts: [
        for (var i = 0; i < commanders.length; i++)
          i < artsRaw.length ? artsRaw[i] as String? : null,
      ],
      deckBracket: stored != null ? bracketMatchingLifeDelta(delta) : bracket,
      handicapLifeDelta: delta,
    );
  }
}

class Playgroup {
  const Playgroup({
    required this.format,
    required this.startingLife,
    required this.trackCommanderDamage,
    required this.trackCommanderTax,
    required this.sharedLife,
    required this.linkDamageToLife,
    required this.planechase,
    required this.archenemy,
    required this.players,
    this.bounty = false,
    this.handicapsEnabled = false,
  });

  final MatchFormat format;
  final int startingLife;
  final bool trackCommanderDamage;
  final bool trackCommanderTax;
  final bool sharedLife;
  /// Legacy JSON — toujours `true`.
  final bool linkDamageToLife;
  final bool planechase;
  final bool archenemy;
  final bool bounty;
  final bool handicapsEnabled;
  final List<PlaygroupPlayer> players;

  factory Playgroup.fromGame(Game game) {
    return Playgroup(
      format: game.format,
      startingLife: game.startingLife,
      trackCommanderDamage: game.trackCommanderDamage,
      trackCommanderTax: game.trackCommanderTax,
      sharedLife: game.sharedLife,
      linkDamageToLife: true,
      planechase: game.planechase,
      archenemy: game.archenemy,
      bounty: game.bounty,
      handicapsEnabled: game.handicapsEnabled,
      players: [
        for (final player in game.players)
          PlaygroupPlayer(
            name: player.name,
            color: player.color,
            commanders: [
              for (final commander in player.commanders) commander.name,
            ],
            commanderArts: [
              for (final commander in player.commanders) commander.artUrl,
            ],
            deckBracket: player.deckBracket,
            handicapLifeDelta: player.handicapLifeDelta,
          ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'format': format.name,
    'startingLife': startingLife,
    'trackCommanderDamage': trackCommanderDamage,
    'trackCommanderTax': trackCommanderTax,
    'sharedLife': sharedLife,
    'linkDamageToLife': linkDamageToLife,
    'planechase': planechase,
    'archenemy': archenemy,
    'bounty': bounty,
    'handicapsEnabled': handicapsEnabled,
    'players': players.map((player) => player.toJson()).toList(),
  };

  factory Playgroup.fromJson(Map<String, dynamic> json) {
    return Playgroup(
      format: MatchFormat.values.firstWhere(
        (format) => format.name == json['format'],
        orElse: () => MatchFormat.commander,
      ),
      startingLife: asInt(json['startingLife'], 40),
      trackCommanderDamage: json['trackCommanderDamage'] as bool? ?? true,
      trackCommanderTax: json['trackCommanderTax'] as bool? ?? true,
      sharedLife: json['sharedLife'] as bool? ?? false,
      linkDamageToLife: true,
      planechase: json['planechase'] as bool? ?? false,
      archenemy: json['archenemy'] as bool? ?? false,
      bounty: json['bounty'] as bool? ?? false,
      handicapsEnabled: json['handicapsEnabled'] as bool? ?? false,
      players: [
        for (final raw in (json['players'] as List? ?? []))
          if (raw is Map<String, dynamic>)
            PlaygroupPlayer.fromJson(raw)
          else if (raw is Map)
            PlaygroupPlayer.fromJson(Map<String, dynamic>.from(raw)),
      ],
    );
  }
}
