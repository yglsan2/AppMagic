# LifeStack

Compteur de partie pour Magic. On pose le téléphone au milieu de la table, chacun lit son côté, et on joue.

Créateur : YGLSAN  
Licence : [GNU GPL v3](LICENSE)

L’application est prévue pour Android. Le web sert surtout à jeter un œil pendant le développement.

## Autour de la table

Deux joueurs se font face. À quatre ou plus, chacun a son quart de l’écran, tourné vers lui. Les textes d’aide suivent le même sens : le joueur d’en face ne lit pas à l’envers.

Le gros chiffre sur ton siège, c’est la vie de l’adversaire en face. Le petit total à côté de ton nom, c’est la tienne.

− enlève un point. + le rend. Ça vaut pour une erreur de comptage comme pour un vrai dégât. −5 et +5 sont là quand le siège a la place. Un appui long enchaîne.

Le commandant marche pareil. Le chiffre, c’est ce qu’il reste avant 21. − enlève 1 à ce compteur et 1 point de vie en même temps. + rend les deux. À 0, le commandant sort le joueur.

Les derniers changements restent écrits sur le siège : `Vie −1 · 40 → 39`, ou l’équivalent pour le commandant. L’historique complet est dans le menu.

Quand tu as fini, tu touches **Fin de tour** sur ton siège. Le bouton passe chez le joueur suivant, dans son sens. Plus rien à aller chercher en bas de l’écran.

Au début de la partie, on peut tirer au sort qui commence, ou passer.

## Formats

Les préréglages mettent la vie de départ et les options au bon endroit. On peut ensuite les retoucher.

| Format | Joueurs | Vie |
| --- | --- | --- |
| Commander (EDH) | 2 à 8 | 40, 21 dégâts de commandant, taxe |
| Duel Commander | 2 | 20, taxe, sans les 21 dégâts |
| Traîtrise | 3 à 8 | règles Commander, rôles secrets |
| Bagarre | 2 à 4 | 25 |
| Construit, Limité | 2 | 20, sans commandant |
| Géant à deux têtes | 4 | 30 partagés par équipe |
| Briseur de serment | 2 à 4 | 20 |
| Personnalisé | au choix | seuils réglables |

Commander à deux garde les règles habituelles : 40 points de vie, et 21 points de dégâts de combat du même commandant. Le Duel Commander est l’autre partie à deux, à 20 points de vie.

Planechase, Archennemi et les primes se cochent dans les options. Le chronomètre (alerte de tour ou pendule) est éteint tant qu’on ne l’active pas.

Poison, énergie, expérience, mana flottant, taxe, partenaires : tout ça reste accessible, sans prendre la place des points de vie. Les handicaps de départ servent si les decks ne sont pas du même niveau.

## Soirée, transfert, cartes

Une soirée enchaîne plusieurs tables sur le même téléphone, avec un code pour s’y retrouver. Les profils évitent de retaper les noms.

Une partie en cours peut passer d’un appareil à l’autre par QR. La recherche de cartes et le journal passent par Scryfall, avec un cache sur l’appareil. Rien de tout ça n’est obligatoire.

Les données restent sur le téléphone. On peut vider le cache ou tout effacer depuis les réglages.

## Lancer

Il faut Flutter et le SDK Android.

```bash
flutter pub get
flutter run -d android
```

APK :

```bash
flutter build apk --release
```

Le fichier se trouve dans `build/app/outputs/flutter-apk/app-release.apk`.

Pour le Play Store : `flutter build appbundle --release`.

Sur cette machine, des scripts dans `scripts/` aident au build Android.

## Magic

Magic: The Gathering est une marque de Wizards of the Coast. LifeStack est un projet fan, sans lien avec Wizards of the Coast.

Les images de cartes viennent de Scryfall. Leurs conditions d’usage s’appliquent.

## Licence

Copyright (C) YGLSAN

Logiciel libre : redistribution et modification selon la [GNU General Public License version 3](LICENSE).

Le programme est fourni sans garantie.
