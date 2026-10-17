# Table MTG

Compteur de vie pour Magic: The Gathering, pensé d’abord pour Android (Flutter).  
L’idée : poser le téléphone au milieu de la table et jouer sans se battre avec l’interface.

Créateur : **YGLSAN**  
Licence : [GNU GPL v3](LICENSE)

---

## Ce que l’app fait

### À la table

- Compteurs de vie lisibles, avec boutons ±1 et ±5, appui long pour répéter.
- Indication claire des PV bas (alerte visuelle).
- Petit ± qui reste un instant à côté du total après un changement (les taps rapides se fusionnent).
- Historique des PV et des dégâts de commandant, consultable à tout moment.
- Annulation des dernières actions.
- Sélection du premier joueur, dés, passage de tour avec numéro de tour visible.
- Modes d’affichage adaptés : table partagée, liste, focus sur un siège.

### Formats

Presets prêts à l’emploi, avec vie de départ et options cohérentes :

- Commander (EDH)
- Traîtrise (Treachery)
- Duel Commander
- Bagarre (Brawl)
- Construit (60 cartes)
- Limité (draft / scellé)
- Géant à deux têtes (2HG, vie partagée)
- Briseur de serment (Oathbreaker)
- Personnalisé (seuils et options au choix)

Options maison : Planechase, Archennemi, primes, etc. selon le réglage de partie.

### Commandant & compteurs

- Suivi des dégâts de commandant (seuil 21 par défaut), avec restants affichés.
- Taxe de commandant, partners / plusieurs commandants.
- Poison, énergie, expérience, rad, vitesse, trésors, storm, sort signature…
- Mana flottant (WUBRG + incolore).
- Handicaps de départ (brackets / ajustements de vie) si tu veux équilibrer une table mixte.

### Soirée & stats

- Mode soirée multi-tables : enchaîner les parties, classement, partage entre téléphones (code MTGN1).
- Stats et récap en fin de partie.
- Profils joueurs pour ne pas tout retaper à chaque fois.

### Transfert & outils

- Transfert de partie en cours (QR / code MTGS1) d’un téléphone à un autre.
- Recherche de cartes et journal optionnel via Scryfall (cache local).
- Chrono de tour ou chess clock (banque de temps par joueur).
- Astuces pour débutants (désactivables).
- Vie privée : données locales, effacement cache / tout effacer (RGPD).

---

## Lancer le projet

Prérequis : [Flutter](https://docs.flutter.dev/get-started/install) + SDK Android.

```bash
flutter pub get
flutter devices
flutter run -d android
```

### Build

```bash
# APK installable
flutter build apk --release

# Bundle Play Store
flutter build appbundle --release
```

APK : `build/app/outputs/flutter-apk/app-release.apk`

La cible web existe surtout pour un aperçu rapide pendant le développement ; Android reste la plateforme principale.

Scripts utilitaires (machine Windows avec SDK sur D:) : dossier `scripts/`.

---

## Contenu fan

Magic: The Gathering est une marque de Wizards of the Coast.  
Cette app est un projet fan, non officiel, et n’est pas affiliée à Wizards of the Coast.

Les images de cartes éventuelles passent par Scryfall ; respecte leurs conditions d’usage.

---

## Licence

Copyright (C) YGLSAN  

Ce programme est un logiciel libre : vous pouvez le redistribuer et/ou le modifier selon les termes de la [GNU General Public License version 3](LICENSE) telle que publiée par la Free Software Foundation.

Ce programme est distribué dans l’espoir qu’il sera utile, mais SANS AUCUNE GARANTIE.
