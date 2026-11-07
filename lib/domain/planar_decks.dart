import 'dart:math';

/// Plan Planechase : nom + effet chaos (résumé FR pour la table).
class PlaneCard {
  const PlaneCard({required this.name, required this.chaos});

  final String name;
  final String chaos;
}

/// Schéma Archenemy.
class SchemeCard {
  const SchemeCard({required this.name, required this.effect});

  final String name;
  final String effect;
}

/// Carte Bounty (OTJ).
class BountyCard {
  const BountyCard({required this.name, required this.reward});

  final String name;
  final String reward;
}

const officialPlanes = <PlaneCard>[
  PlaneCard(
    name: 'Aretopolis',
    chaos: 'Chaos : chaque joueur crée un jeton Trésor.',
  ),
  PlaneCard(
    name: 'Astral Arena',
    chaos: 'Chaos : chaque créature gagne « menace » jusqu’à la fin du tour.',
  ),
  PlaneCard(
    name: 'Cliffside Market',
    chaos: 'Chaos : chaque joueur peut échanger le contrôle de permanents.',
  ),
  PlaneCard(
    name: 'Edge of Malacol',
    chaos: 'Chaos : chaque joueur sacrifie un permanent non-terrain.',
  ),
  PlaneCard(
    name: 'Eloren Wilds',
    chaos: 'Chaos : chaque joueur cherche une carte créature dans sa bibliothèque.',
  ),
  PlaneCard(
    name: 'Feeding Grounds',
    chaos: 'Chaos : chaque joueur gagne 1d20 points de vie.',
  ),
  PlaneCard(
    name: 'Fields of Summer',
    chaos: 'Chaos : chaque joueur gagne 10 points de vie.',
  ),
  PlaneCard(
    name: 'Glimmervoid Basin',
    chaos: 'Chaos : chaque joueur crée un jeton artefact 0/0.',
  ),
  PlaneCard(
    name: 'Grixis',
    chaos: 'Chaos : chaque joueur se défausse d’une carte puis pioche une carte.',
  ),
  PlaneCard(
    name: 'Horizon Boughs',
    chaos: 'Chaos : chaque joueur peut mettre un terrain de sa main sur le champ.',
  ),
  PlaneCard(
    name: 'Immersturm',
    chaos: 'Chaos : chaque joueur crée un jeton Dragon 4/4 rouge.',
  ),
  PlaneCard(
    name: 'Iquatana',
    chaos: 'Chaos : chaque joueur pioche une carte.',
  ),
  PlaneCard(
    name: 'Isle of Vesuva',
    chaos: 'Chaos : chaque joueur crée un jeton qui est une copie d’une créature.',
  ),
  PlaneCard(
    name: 'Jund',
    chaos: 'Chaos : chaque joueur sacrifie une créature.',
  ),
  PlaneCard(
    name: 'Kharasha Foothills',
    chaos: 'Chaos : chaque joueur créé deux jetons Guerrier 1/1.',
  ),
  PlaneCard(
    name: 'Krosa',
    chaos: 'Chaos : les créatures gagnent +2/+2 jusqu’à la fin du tour.',
  ),
  PlaneCard(
    name: 'Llanowar',
    chaos: 'Chaos : chaque joueur cherche une carte forêt.',
  ),
  PlaneCard(
    name: 'Minamo',
    chaos: 'Chaos : chaque joueur pioche deux cartes puis se défausse d’une.',
  ),
  PlaneCard(
    name: 'Mirrored Depths',
    chaos: 'Chaos : chaque joueur lance un dé à 20 faces pour un effet aléatoire.',
  ),
  PlaneCard(
    name: 'Mount Keralia',
    chaos: 'Chaos : Mount Keralia inflige 3 blessures à chaque créature.',
  ),
  PlaneCard(
    name: 'Murasa',
    chaos: 'Chaos : chaque joueur peut mettre un terrain de sa bibliothèque.',
  ),
  PlaneCard(
    name: 'Naar Isle',
    chaos: 'Chaos : chaque joueur sacrifie un artefact ou une créature.',
  ),
  PlaneCard(
    name: 'Naya',
    chaos: 'Chaos : chaque joueur crée un jeton Bête 3/3.',
  ),
  PlaneCard(
    name: 'Otaria',
    chaos: 'Chaos : chaque joueur peut renvoyer une créature de son cimetière.',
  ),
  PlaneCard(
    name: 'Panopticon',
    chaos: 'Chaos : chaque joueur devient monarque jusqu’à son prochain tour.',
  ),
  PlaneCard(
    name: 'Pools of Becoming',
    chaos: 'Chaos : mélangez les cartes exilées dans les bibliothèques.',
  ),
  PlaneCard(
    name: 'Quicksilver Sea',
    chaos: 'Chaos : chaque joueur peut lancer un sort sans payer son coût de mana.',
  ),
  PlaneCard(
    name: 'Raven’s Run',
    chaos: 'Chaos : chaque joueur crée un jeton Faerie 1/1 avec le vol.',
  ),
  PlaneCard(
    name: 'Sanctum of Serra',
    chaos: 'Chaos : chaque joueur gagne 7 points de vie.',
  ),
  PlaneCard(
    name: 'Sea of Sand',
    chaos: 'Chaos : détruisez tous les terrains non-basiques.',
  ),
  PlaneCard(
    name: 'Shiv',
    chaos: 'Chaos : chaque joueur crée un jeton Dragon 5/5.',
  ),
  PlaneCard(
    name: 'Skybreen',
    chaos: 'Chaos : chaque joueur crée un jeton Géant 4/4.',
  ),
  PlaneCard(
    name: 'Sokenzan',
    chaos: 'Chaos : chaque joueur crée trois jetons Gobelin 1/1.',
  ),
  PlaneCard(
    name: 'Stronghold Furnace',
    chaos: 'Chaos : Stronghold Furnace inflige 5 blessures à chaque joueur.',
  ),
  PlaneCard(
    name: 'Takenuma',
    chaos: 'Chaos : chaque joueur crée un jeton Spirit 2/2.',
  ),
  PlaneCard(
    name: 'The Dark Barony',
    chaos: 'Chaos : chaque joueur perd 1 point de vie pour chaque carte en main.',
  ),
  PlaneCard(
    name: 'The Eon Fog',
    chaos: 'Chaos : sautez la prochaine étape de combat.',
  ),
  PlaneCard(
    name: 'The Fourth Sphere',
    chaos: 'Chaos : chaque joueur sacrifice deux permanents.',
  ),
  PlaneCard(
    name: 'The Great Forest',
    chaos: 'Chaos : chaque joueur cherche deux cartes terrain.',
  ),
  PlaneCard(
    name: 'The Hippodrome',
    chaos: 'Chaos : chaque joueur crée un jeton Cheval 2/2.',
  ),
  PlaneCard(
    name: 'The Maelstrom',
    chaos: 'Chaos : chaque joueur révèle le dessus de sa bibliothèque et le joue.',
  ),
  PlaneCard(
    name: 'The Swath',
    chaos: 'Chaos : détruisez toutes les créatures.',
  ),
  PlaneCard(
    name: 'Turri Island',
    chaos: 'Chaos : chaque joueur crée un jeton Ape 3/3.',
  ),
  PlaneCard(
    name: 'Undercity Reaches',
    chaos: 'Chaos : chaque joueur crée un jeton Assassin 1/1.',
  ),
  PlaneCard(
    name: 'Velis Vel',
    chaos: 'Chaos : chaque créature devient un Shapeshifter jusqu’à la fin du tour.',
  ),
];

const officialSchemes = <SchemeCard>[
  SchemeCard(
    name: 'All Shall Smolder in My Wake',
    effect: 'Détruisez tous les artefacts et enchantements non-jeton.',
  ),
  SchemeCard(
    name: 'Behold the Power of Destruction',
    effect: 'Détruisez tous les non-terrains.',
  ),
  SchemeCard(
    name: 'Choose Your Champion',
    effect: 'Un adversaire devient votre champion jusqu’à votre prochain tour.',
  ),
  SchemeCard(
    name: 'Dance, Pathetic Marionette',
    effect: 'Chaque adversaire sacrifie une créature.',
  ),
  SchemeCard(
    name: 'Every Hope Shall Wither',
    effect: 'Chaque adversaire se défausse de deux cartes.',
  ),
  SchemeCard(
    name: 'I Call on the Ancient Magics',
    effect: 'Cherchez deux cartes dans votre bibliothèque et mettez-les en main.',
  ),
  SchemeCard(
    name: 'I Delight in Your Convulsions',
    effect: 'Chaque adversaire perd 3 PV ; vous gagnez autant.',
  ),
  SchemeCard(
    name: 'Know Naught but Fire',
    effect: 'Chaque adversaire reçoit X blessures, X = cartes en main.',
  ),
  SchemeCard(
    name: 'Look Skyward and Despair',
    effect: 'Créez un jeton Dragon 5/5 rouge avec le vol.',
  ),
  SchemeCard(
    name: 'May Civilization Collapse',
    effect: 'Détruisez tous les terrains.',
  ),
  SchemeCard(
    name: 'My Crushing Masterstroke',
    effect: 'Gagnez le contrôle de tous les permanents jusqu’à la fin du tour.',
  ),
  SchemeCard(
    name: 'No One Has Opposed Me and Lived',
    effect: 'Chaque adversaire sacrifie une créature et un artefact.',
  ),
  SchemeCard(
    name: 'Only Blood Ends Your Nightmares',
    effect: 'Chaque adversaire sacrifie une créature ou perd 5 PV.',
  ),
  SchemeCard(
    name: 'Realms Befitting My Majesty',
    effect: 'Cherchez deux terrains basiques et mettez-les sur le champ.',
  ),
  SchemeCard(
    name: 'Root Out the Evil Doers',
    effect: 'Détruisez jusqu’à trois créatures ciblées.',
  ),
  SchemeCard(
    name: 'The Dead Shall Serve',
    effect: 'Chaque adversaire crée un jeton Zombie 2/2 noir.',
  ),
  SchemeCard(
    name: 'The Fate of the Flammable',
    effect: 'Chaque adversaire reçoit 5 blessures.',
  ),
  SchemeCard(
    name: 'The Flesh Is Weak',
    effect: 'Les créatures reçoivent -2/-2 jusqu’à la fin du tour.',
  ),
  SchemeCard(
    name: 'Your Puny Minds Cannot Fathom',
    effect: 'Piochez quatre cartes.',
  ),
  SchemeCard(
    name: 'Your Will Is Not Your Own',
    effect: 'Gagnez le contrôle d’une créature ciblée.',
  ),
];

const officialBounties = <BountyCard>[
  BountyCard(
    name: 'Wanted: Dead or Alive',
    reward: 'Niveau 1 · 3 PV ou créez un Trésor quand un adversaire meurt.',
  ),
  BountyCard(
    name: 'Collect the Debt',
    reward: 'Niveau 2 · piochez une carte quand vous éliminez quelqu’un.',
  ),
  BountyCard(
    name: 'Make an Example',
    reward: 'Niveau 3 · +2/+2 et menace jusqu’à la fin du tour.',
  ),
  BountyCard(
    name: 'Outlaw Country',
    reward: 'Chaque joueur commence avec une prime personnelle.',
  ),
  BountyCard(
    name: 'Showdown',
    reward: 'Le premier à 21 dégâts de combat gagne un Trésor.',
  ),
  BountyCard(
    name: 'High Noon',
    reward: 'Les sorts coûtent +1 pendant le premier tour de chaque joueur.',
  ),
  BountyCard(
    name: 'Wanted Poster',
    reward: 'Désignez un « most wanted » : 5 PV de prime.',
  ),
  BountyCard(
    name: 'Jailbreak',
    reward: 'Une fois : renvoyez une créature du cimetière en jeu.',
  ),
  BountyCard(
    name: 'Ambush',
    reward: 'Les créatures entrant ont la célérité jusqu’à la fin du tour.',
  ),
  BountyCard(
    name: 'Double Cross',
    reward: 'Échangez la prime avec un adversaire.',
  ),
  BountyCard(
    name: 'Golden Opportunity',
    reward: 'Créez deux jetons Trésor.',
  ),
  BountyCard(
    name: 'Last Call',
    reward: 'Si vous êtes le dernier, gagnez 10 PV.',
  ),
];

List<String> shuffledPlaneNames([Random? random]) {
  final rng = random ?? Random();
  final names = [for (final p in officialPlanes) p.name]..shuffle(rng);
  return names;
}

List<String> shuffledSchemeNames([Random? random]) {
  final rng = random ?? Random();
  final names = [for (final s in officialSchemes) s.name]..shuffle(rng);
  return names;
}

String chaosForPlane(String name) {
  for (final plane in officialPlanes) {
    if (plane.name == name) return plane.chaos;
  }
  return 'Chaos : résolvez l’effet chaos du plan (règles Planechase).';
}

String effectForScheme(String name) {
  for (final scheme in officialSchemes) {
    if (scheme.name == name) return scheme.effect;
  }
  return 'Résolvez le stratagème selon sa carte.';
}

BountyCard bountyAtLevel(int level) {
  final index = level.clamp(0, officialBounties.length - 1);
  return officialBounties[index];
}
