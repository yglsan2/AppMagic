import 'package:mtg_table/domain/models.dart';

/// Textes des bulles d’aide. Affichés seulement si l’aide débutant est allumée.
class OptionTip {
  const OptionTip(this.title, this.message);

  final String title;
  final String message;
}

OptionTip tipPoison(int threshold) => OptionTip(
  'Poison',
  'Marqueurs poison. À $threshold, le joueur perd la partie '
      '(10 en général, 15 en Géant à deux têtes ; le seuil se change '
      'dans Réglages). − et + corrigent le total. Ce n’est pas une perte '
      'de points de vie.',
);

const tipMonarch = OptionTip(
  'Monarque',
  'Personne ne l’est au début. Touchez la pastille quand une carte dit '
      'de devenir le monarque. Une blessure de combat d’une créature adverse '
      'lui vole la couronne. Au début de votre étape de fin, piochez une carte : '
      'Fin de tour vous le demande. Personne n’est indétrônable.',
);

const tipTax = OptionTip(
  'Taxe de commandant',
  'Relancer ce commandant depuis la zone de commandement coûte 2 de mana '
      'de plus à chaque fois. Le nombre affiché est ce coût en plus. '
      '+ après un lancement, − si on s’est trompé.',
);

const tipInitiative = OptionTip(
  'Initiative',
  'C’est le donjon Undercity, pas une autre carte. Personne ne l’a au début. '
      'Quand une carte dit « prenez l’initiative », allumez cette option : '
      'vous entrez dans Undercity, vous avancez d’une salle et vous appliquez '
      'son effet. Les salles se suivent sur la carte du donjon. Ici, on note '
      'seulement qui a l’initiative.\n\n'
      'Tant que vous l’avez, au début de votre entretien, vous avancez encore '
      'd’une salle.\n\n'
      'Pour la perdre : une créature adverse qui vous inflige des dégâts de '
      'combat la vole. Son contrôleur la prend, et il avance tout de suite '
      'dans le donjon. Un commandant qui vous touche en combat compte, parce '
      'que c’est une blessure de combat : l’app la lui donne toute seule. '
      'Pour une autre créature, touchez la pastille pour la lui passer. '
      'Un sort, ou des dégâts hors combat, ne la volent pas.\n\n'
      'Une seule personne l’a à la fois. Si elle quitte la partie, l’initiative '
      'va au joueur dont c’est le tour, ou au suivant si c’était lui.',
);

const tipBlessing = OptionTip(
  'Bénédiction de la Cité',
  'On l’obtient en contrôlant dix permanents (Ascension), puis on la garde '
      'pour toute la partie. Touchez pour l’indiquer. Un second toucher '
      'sert seulement à corriger une erreur.',
);

const tipTreasure = OptionTip(
  'Trésors',
  'Jetons Trésor. On en sacrifie un pour ajouter un mana de n’importe '
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
  'Quatre paliers. + à chaque tentation, − pour corriger. '
      'Le compteur s’arrête à 4 : c’est le dernier palier.',
);

const tipRad = OptionTip(
  'Radiation',
  'Au début de votre première phase principale, vous meulez autant de cartes '
      'que de marqueurs, vous perdez 1 point de vie par carte non-terrain, '
      'puis vous retirez un marqueur. L’app ne meule pas le deck : '
      'ajustez le nombre et les points de vie à la main.',
);

const tipSpeed = OptionTip(
  'Vitesse',
  'De 0 à 4. Elle monte de 1, une seule fois par tour, quand un adversaire '
      'perd des points de vie pendant votre tour. + le note. '
      'Le compteur ne dépasse pas 4.',
);

const tipSignature = OptionTip(
  'Sort signature',
  'Format Briseur de serment : le sort choisi avec le planeswalker. '
      'Le nombre compte les lancements. Dans la roue crantée, touchez le nom '
      'pour le renommer. La taxe du planeswalker est le compteur à part.',
);

const tipCustom = OptionTip(
  'Suivi libre',
  'Pour un marqueur sans case prévue : indices, nourriture, sang, et le reste. '
      '− et + changent le nombre. La croix, dans la roue crantée, retire le suivi.',
);

const tipPane = OptionTip(
  'Affichage des points',
  'Mes pertes : vous retirez vos propres points. Adversaires : vous retirez '
      'ceux des autres. Les deux : les deux à la fois. '
      '« Enregistrer pour ce pseudo » le proposera aux prochaines parties.',
);

const tipEndTurn = OptionTip(
  'Fin de tour',
  'Passe la main au joueur suivant. Si vous êtes monarque, l’app demande '
      'd’abord si la carte du début d’étape de fin est piochée. '
      'Le mana flottant et la tempête peuvent se vider, selon les réglages.',
);

const tipGear = OptionTip(
  'Options',
  'Poison, monarque, taxe de commandant, trésors, énergie, expérience, '
      'tempête, mana, puis les plus rares : initiative, anneau, bénédiction '
      'de la Cité, radiation, vitesse. Chaque − et + modifie bien ce compteur.',
);

OptionTip tipForStat(Stat stat, Player player) => switch (stat) {
  Stat.poison => tipPoison(10),
  Stat.energy => tipEnergy,
  Stat.experience => tipExperience,
  Stat.rad => tipRad,
  Stat.speed => tipSpeed,
  Stat.treasure => tipTreasure,
  Stat.storm => tipStorm,
  Stat.signature => OptionTip(player.signatureName, tipSignature.message),
};

const tipDayNight = OptionTip(
  'Jour / nuit',
  'La partie passe en nuit si le joueur dont c’est le tour n’a lancé aucun sort, '
      'et revient au jour s’il en a lancé au moins deux. Le menu bascule l’état. '
      'L’app ne compte pas les sorts toute seule.',
);

const tipPlane = OptionTip(
  'Course planaire',
  'Le dé planaire a quatre faces blanches, une face planeswalk et une face chaos. '
      'Marcher passe au plan suivant. Chaos rappelle l’effet de chaos du plan affiché.',
);

const tipScheme = OptionTip(
  'Archennemi',
  'Un joueur est l’archennemi et joue des stratagèmes. Suivant passe au '
      'prochain. Touchez le nom pour lire l’effet. Le rôle se désigne '
      'dans la fiche du joueur.',
);

const tipBounty = OptionTip(
  'Chasse à la prime',
  'La prime monte de niveau, puis quelqu’un la réclame et elle repart au début. '
      'Réclamer l’attribue au joueur dont c’est le tour.',
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

const tipMenu = OptionTip(
  'Menu',
  'Joueurs, tirage du premier, jour et nuit, recherche de carte, réglages, '
      'disposition de l’écran, revanche et remise à zéro.',
);

const tipLayout = OptionTip(
  'Disposition',
  'Téléphone : chacun de son côté. Liste : tous dans le même sens. '
      'À quatre, le partage en quatre écrans est aussi proposé.',
);
