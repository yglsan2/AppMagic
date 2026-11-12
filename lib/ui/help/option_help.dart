import 'package:mtg_table/domain/models.dart';

/// Textes des bulles d’aide. Affichés seulement si l’aide débutant est allumée.
class OptionTip {
  const OptionTip(this.title, this.message);

  final String title;
  final String message;
}

OptionTip tipPoison(int threshold) => OptionTip(
  'Poison',
  'La fiole à tête de mort, c’est le poison. À $threshold, le joueur perd la partie '
      '(10 en général, 15 en Géant à deux têtes ; le seuil se change '
      'dans Réglages). − et + corrigent le total. Ce n’est pas une perte '
      'de points de vie.',
);

const tipMonarch = OptionTip(
  'Monarque',
  'La couronne, c’est le monarque. Personne ne l’est au début. '
      'Touchez la pastille quand une carte dit '
      'de devenir le monarque. Une blessure de combat d’une créature adverse '
      'lui vole la couronne. Au début de votre étape de fin, piochez une carte : '
      'Fin de tour vous le demande. Personne n’est indétrônable.',
);

const tipTax = OptionTip(
  'Taxe de commandant',
  'La bourse marquée d’un dollar, avec le trident du commandant. '
      'Relancer ce commandant depuis la zone de commandement coûte 2 de mana '
      'de plus à chaque fois. Le nombre affiché est ce coût en plus. '
      '+ après un lancement, − si on s’est trompé.',
);

const tipInitiative = OptionTip(
  'Initiative',
  'Le donjon percé d’une flèche vers le bas, c’est Undercity. '
      'Personne ne l’a au début. '
      'Quand une carte dit « prenez l’initiative », allumez cette option : '
      'vous entrez dans Undercity, vous avancez d’une salle et vous appliquez '
      'son effet. Les salles se suivent dans la feuille du joueur : Mine perdue '
      'ou Ville souterraine. On choisit la porte, l’app ne la choisit pas.\n\n'
      'Tant que vous l’avez, au début de votre entretien, vous avancez encore '
      'd’une salle.\n\n'
      'Pour la perdre : une créature adverse qui vous inflige des dégâts de '
      'combat la vole. L’app pose la même question que pour la couronne. '
      'Un commandant qui vous touche en combat compte : l’app la lui donne '
      'toute seule. Un sort, ou des dégâts hors combat, ne la volent pas.\n\n'
      'Une seule personne l’a à la fois. Si elle quitte la partie, l’initiative '
      'va au joueur dont c’est le tour, ou au suivant si c’était lui.',
);

const tipBlessing = OptionTip(
  'Bénédiction de la Cité',
  'La cité avec la flèche qui monte, c’est la bénédiction. '
      'On l’obtient par l’Ascension : dix permanents, puis on la garde '
      'pour toute la partie. Une fois allumée, elle reste. Pour annuler '
      'une erreur, utilisez l’historique.',
);

const tipTreasure = OptionTip(
  'Trésors',
  'Le coffre, c’est le jeton Trésor. On en sacrifie un pour ajouter un mana de n’importe '
      'quelle couleur. L’app ne les sacrifie pas toute seule : − quand '
      'on en dépense un, + quand on en crée.',
);

const tipEnergy = OptionTip(
  'Énergie',
  'Marqueurs énergie. On les gagne et on les dépense selon les cartes. '
      'L’app ne les dépense pas à votre place : − et + suivent le total.',
);

const tipExperience = OptionTip(
  'Expérience',
  'Marqueurs expérience. Ils restent sur vous, souvent quand une créature '
      'que vous contrôlez meurt. − et + suivent le total.',
);

const tipStorm = OptionTip(
  'Tempête',
  'La tempête copie le sort pour chaque sort déjà lancé avant lui, ce tour-ci. '
      'Ici, chaque joueur compte les siens. Si le réglage est actif, '
      'Fin de tour remet à zéro le compteur de celui qui vient de jouer.',
);

const tipMana = OptionTip(
  'Mana flottant',
  'Mana encore en réserve : W blanc, U bleu, B noir, R rouge, G vert, '
      'C incolore. Il disparaît à l’étape de nettoyage. Si « Vider le mana '
      'en fin de tour » est actif, Fin de tour remet ces cases à zéro.',
);

const tipRing = OptionTip(
  'L’Anneau vous tente',
  'L’anneau est d’abord un filigrane, en quatre quarts. '
      'Chaque tentation en colorie un. Quand les quatre sont pleins, '
      'le dernier palier est atteint. + avance, − corrige.',
);

const tipRad = OptionTip(
  'Radiation',
  'Le trèfle, c’est la radiation. '
      'Au début de votre première phase principale, vous meulez autant de cartes '
      'que de marqueurs, vous perdez 1 point de vie par carte non-terrain, '
      'puis vous retirez un marqueur. Au début de votre tour, l’app le rappelle. '
      'Elle ne meule pas et ne retire pas le marqueur toute seule.',
);

const tipSpeed = OptionTip(
  'Vitesse',
  'De 0 à 4. Elle monte de 1, une seule fois par tour, quand un adversaire '
      'perd des points de vie pendant votre tour. Un seul + par tour, '
      'même s’il monte de plusieurs crans d’un coup. Le compteur s’arrête à 4.',
);

const tipSignature = OptionTip(
  'Sort signature',
  'Format Briseur de serment : le sort choisi avec le planeswalker. '
      'Le nombre compte les lancements. Le surcoût affiché est ce nombre fois 2. '
      'Dans la roue crantée, touchez le nom pour le renommer. '
      'La taxe du planeswalker est le compteur à part.',
);

const tipCustom = OptionTip(
  'Suivi libre',
  'Pour un marqueur sans case prévue. Les jetons de table ont déjà la leur. '
      '− et + changent le nombre. La croix, dans la roue crantée, retire le suivi.',
);

const tipEndTurn = OptionTip(
  'Fin de tour',
  'Passe la main au joueur suivant. Si vous êtes monarque, l’app demande '
      'd’abord si la carte du début d’étape de fin est piochée. '
      'Le mana flottant et la tempête peuvent se vider, selon les réglages.',
);

const tipGear = OptionTip(
  'Options',
  'Chaque option est un symbole. Il reste sombre tant qu’il ne compte pas, '
      'et s’allume dans sa couleur dès qu’il est en jeu. Le nombre est à côté. '
      'Moins et plus corrigent. Le soleil et la lune, dans la barre, sont '
      'le jour et la nuit de toute la table.',
);

OptionTip tipForStat(Stat stat, Player player) => switch (stat) {
  Stat.poison => tipPoison(10),
  Stat.energy => tipEnergy,
  Stat.experience => tipExperience,
  Stat.rad => tipRad,
  Stat.speed => tipSpeed,
  Stat.treasure => tipTreasure,
  Stat.storm => tipStorm,
  Stat.clue => tipClue,
  Stat.food => tipFood,
  Stat.blood => tipBlood,
  Stat.trail => tipTrail,
  Stat.gold => tipGold,
  Stat.powerstone => tipPowerstone,
  Stat.signature => OptionTip(player.signatureName, tipSignature.message),
};

const tipClue = OptionTip('Indice', 'Jeton Indice. On le sacrifie en général pour piocher.');
const tipFood = OptionTip('Nourriture', 'Jeton Nourriture. On le sacrifie en général pour gagner des points de vie.');
const tipBlood = OptionTip('Sang', 'Jeton Sang. On le sacrifie en général pour piocher puis se défausser.');
const tipTrail = OptionTip('Carte', 'Jeton Carte, celui de l’exploration. On le sacrifie pour chercher un terrain.');
const tipGold = OptionTip('Or', 'Jeton Or. Il se sacrifie pour un mana de n’importe quelle couleur.');
const tipPowerstone = OptionTip(
  'Pierre de puissance',
  'Jeton Pierre de puissance. Il se tape pour un mana incolore, pas pour un sort.',
);

const tipDayNight = OptionTip(
  'Jour et nuit',
  'Le soleil allumé, c’est le jour. La lune allumée, c’est la nuit. '
      'Les deux sombres : la partie ne suit pas encore le cycle. '
      'Touchez l’astre voulu. Un second toucher sur l’astre allumé l’éteint, '
      'si c’était une erreur. La partie passe en nuit si le joueur dont c’est '
      'le tour n’a lancé aucun sort, et revient au jour s’il en a lancé au moins deux. '
      'L’app ne compte pas les sorts toute seule.',
);

const tipPlane = OptionTip(
  'Course planaire',
  'Le dé a quatre faces vides, une planeswalk et une chaos. '
      'Le premier lancer du tour est gratuit, puis chaque suivant coûte 1 de plus. '
      'Une face planeswalk ne change pas le plan toute seule : Marcher le fait. '
      'Chaos rappelle le rappel du plan affiché.',
);

const tipScheme = OptionTip(
  'Archennemi',
  'Un joueur est l’archennemi et joue des stratagèmes. Suivant passe au '
      'prochain. Touchez le nom pour lire l’effet. Le rôle se désigne '
      'dans la fiche du joueur.',
);

const tipBounty = OptionTip(
  'Chasse à la prime',
  'Chaque joueur a son contrat. Réclamer passe au contrat suivant '
      'pour le joueur dont c’est le tour. Les autres gardent le leur.',
);

const tipUndo = OptionTip(
  'Annuler',
  'Revient d’un cran : points de vie, commandant, poison, monarque, mana. '
      'Utile juste après une fausse touche.',
);

const tipRedo = OptionTip(
  'Rétablir',
  'Refait l’action que vous venez d’annuler.',
);

const tipHistory = OptionTip(
  'Historique',
  'La liste de ce qui a été compté dans cette partie : vies, commandants, journal.',
);

const tipDice = OptionTip(
  'Dés',
  'Dés classiques, dé planaire (course planaire) et pile ou face.',
);

const tipSalon = OptionTip(
  'Salon',
  'Quitte la table et revient à l’écran de départ. La partie en cours peut être reprise.',
);

const tipShare = OptionTip(
  'Partage entre téléphones',
  'Les deux mains qui se serrent, c’est le partage. '
      'Ce bouton relie cet écran aux autres téléphones qui ont LifeStack : '
      'Wi-Fi du lieu avec un QR, groupe isolé de quatre, '
      'ou salon en ligne si le réseau ne tient pas. '
      'On choisit ensuite son siège, ou on garde la table entière.',
);

const tipMenu = OptionTip(
  'Menu',
  'Joueurs, tirage du premier, soleil et lune, recherche de carte, '
      'réglages, disposition, revanche et remise à zéro. '
      'Le partage entre téléphones est le bouton des deux mains, à côté.',
);

const tipLayout = OptionTip(
  'Disposition',
  'Le soleil et la lune sont au centre, entre les joueurs. '
      'Logos seuls : le symbole, sans le mot. Logos et noms : le mot sous chaque symbole. '
      'Façon téléphone : les places autour de cet écran. '
      'Comptes empilés : tous dans le même sens. '
      'À trois, sur un grand écran : Table ronde, les trois places à égale distance, '
      'ou Liste droite, en colonne ou côte à côte selon l’écran. '
      'À quatre, le partage en quatre écrans est aussi proposé.',
);
