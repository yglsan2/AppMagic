# -*- coding: utf-8 -*-
"""Build LifeStack FR/EN/LV catalogs."""
from __future__ import annotations

from pathlib import Path

# key: (fr, en, lv)
DATA: dict[str, tuple[str, str, str]] = {}


def add(key: str, fr: str, en: str, lv: str) -> None:
    DATA[key] = (fr, en, lv)


# --- common ---
add("app_name", "LifeStack", "LifeStack", "LifeStack")
add("app_title", "LifeStack", "LifeStack", "LifeStack")
add("language_title", "Langue", "Language", "Valoda")
add("common_cancel", "Annuler", "Cancel", "Atcelt")
add("common_close", "Fermer", "Close", "Aizvērt")
add("common_yes", "Oui", "Yes", "Jā")
add("common_no", "Non", "No", "Nē")
add("common_ok", "OK", "OK", "Labi")

# --- setup ---
add("setup_tools_night_title", "Outils & soirée", "Tools & game night", "Rīki un vakars")
add(
    "setup_tools_night_subtitle",
    "Soirée multi-tables, import, stats, cartes…",
    "Multi-table night, import, stats, cards…",
    "Vairāku galdu vakars, imports, statistika, kārtis…",
)
add("setup_night_multi_tables", "Soirée multi-tables", "Multi-table night", "Vairāku galdu vakars")
add("setup_import", "Importer", "Import", "Importēt")
add(
    "setup_import_failed",
    "Import impossible : partie invalide ou corrompue.",
    "Import failed: invalid or corrupted game.",
    "Imports neizdevās: nederīga vai bojāta spēle.",
)
add("setup_history", "Historique", "History", "Vēsture")
add("setup_cards", "Cartes", "Cards", "Kārtis")
add("setup_privacy", "Vie privée", "Privacy", "Privātums")
add("setup_formats_tip_title", "Formats", "Formats", "Formāti")
add(
    "setup_formats_tip_message",
    "Maintenez un format, ou touchez le i, pour lire l’explication. Le nom anglais reste entre parenthèses.",
    "Long-press a format, or tap the i, to read the explanation. The English name stays in parentheses.",
    "Ilgi turiet formātu vai pieskarieties i, lai lasītu skaidrojumu. Angļu nosaukums paliek iekavās.",
)
add("setup_format_heading", "Format", "Format", "Formāts")
add("setup_players_fixed", "Joueurs ({n})", "Players ({n})", "Spēlētāji ({n})")
add("setup_players_range", "Joueurs ({min}–{max})", "Players ({min}–{max})", "Spēlētāji ({min}–{max})")
add("setup_default_player_name", "Joueur {n}", "Player {n}", "Spēlētājs {n}")
add("setup_default_commander", "Commandant", "Commander", "Komandieris")
add("setup_commander_n", "Commandant {n}", "Commander {n}", "Komandieris {n}")
add("setup_seat_color_tooltip", "Couleur du joueur", "Player color", "Spēlētāja krāsa")
add("setup_name_label", "Nom", "Name", "Vārds")
add("setup_life_pv", "{n} PV", "{n} life", "{n} DP")
add("setup_load_profile_tooltip", "Charger un profil", "Load a profile", "Ielādēt profilu")
add("setup_save_profile_tooltip", "Sauver le profil", "Save profile", "Saglabāt profilu")
add("setup_profile_saved", "Profil enregistré.", "Profile saved.", "Profils saglabāts.")
add(
    "setup_profile_save_failed",
    "Enregistrement du profil impossible.",
    "Could not save the profile.",
    "Neizdevās saglabāt profilu.",
)
add("setup_scryfall_art_tooltip", "Illustration Scryfall", "Scryfall art", "Scryfall ilustrācija")
add(
    "setup_commander_name_required",
    "Indiquez un nom de commandant.",
    "Enter a commander name.",
    "Norādiet komandiera vārdu.",
)
add(
    "setup_card_found_no_art",
    "Carte trouvée sans illustration, ou nom inconnu.",
    "Card found with no art, or unknown name.",
    "Kārts atrasta bez ilustrācijas, vai vārds nav zināms.",
)
add(
    "setup_partner_commander",
    "Partenaire / 2e commandant",
    "Partner / 2nd commander",
    "Partneris / 2. komandieris",
)
add(
    "setup_balance_decks_title",
    "Équilibrer les decks (optionnel)",
    "Balance the decks (optional)",
    "Līdzsvarot klājus (pēc izvēles)",
)
add(
    "setup_balance_unavailable_2hg",
    "Indisponible en Géant à deux têtes",
    "Unavailable in Two-Headed Giant",
    "Nav pieejams Divgalvainajā milzī",
)
add(
    "setup_balance_active",
    "Handicaps actifs · PV −30…+30",
    "Handicaps on · life −30…+30",
    "Handikapi ieslēgti · DP −30…+30",
)
add(
    "setup_balance_hint",
    "Préconstruit ou deck compétitif, points de vie en plus ou en moins",
    "Precon or competitive deck, life up or down",
    "Gatavais vai konkurējošais klājs, vairāk vai mazāk dzīvības",
)
add("setup_handicaps_title", "Handicaps de deck", "Deck handicaps", "Klāja handikapi")
add(
    "setup_handicaps_subtitle",
    "Un préconstruit peut commencer à 50 points de vie, un deck compétitif à 30.",
    "A precon can start at 50 life, a competitive deck at 30.",
    "Gatavais klājs var sākt ar 50 dzīvību, konkurējošais ar 30.",
)
add("setup_more_options", "Plus d’options", "More options", "Vairāk opciju")
add("setup_fewer_options", "Moins d’options", "Fewer options", "Mazāk opciju")
add("setup_commander_damage", "Dégâts de commandant", "Commander damage", "Komandiera bojājumi")
add("setup_commander_tax", "Taxe de commandant", "Commander tax", "Komandiera nodoklis")
add(
    "setup_planechase",
    "Course planaire (Planechase)",
    "Planechase",
    "Plānu medības (Planechase)",
)
add(
    "setup_planechase_subtitle",
    "Cartes de plan, et un dé : quatre faces blanches, une planeswalk, une chaos.",
    "Plane cards and a die: four blank faces, one planeswalk, one chaos.",
    "Plānu kārtis un kauliņš: četras tukšas, viena planeswalk, viena chaos.",
)
add("setup_archenemy", "Archennemi (Archenemy)", "Archenemy", "Arhiienaidnieks (Archenemy)")
add(
    "setup_archenemy_subtitle",
    "Un joueur contre le reste de la table, avec des stratagèmes.",
    "One player against the rest of the table, with schemes.",
    "Viens spēlētājs pret pārējiem, ar shēmām.",
)
add("setup_bounty", "Primes (Bounty · OTJ)", "Bounties (OTJ)", "Prēmijas (Bounty · OTJ)")
add(
    "setup_bounty_subtitle",
    "Cartes Prime de Hors-la-loi de Croisetonnerre, du niveau 1 au 12.",
    "Outlaws of Thunder Junction bounty cards, levels 1 to 12.",
    "Outlaws of Thunder Junction prēmiju kārtis, 1.–12. līmenis.",
)
add("setup_starting_life", "Points de vie de départ", "Starting life", "Sākuma dzīvība")
add("setup_start_game_semantics", "Lancer la partie", "Start the game", "Sākt spēli")
add(
    "setup_start_draw_first",
    "Lancer · tirage du premier",
    "Start · draw who goes first",
    "Sākt · izloze, kurš sāk",
)
add(
    "setup_start_treachery",
    "Lancer · tirage + rôles Traîtrise",
    "Start · draw + Treachery roles",
    "Sākt · izloze + Treachery lomas",
)
add(
    "setup_join_table",
    "Rejoindre une table LifeStack",
    "Join a LifeStack table",
    "Pievienoties LifeStack galdam",
)
add(
    "setup_footer_hint",
    "Un seul écran suffit. Pour brancher d’autres téléphones avec LifeStack : lancez la partie, puis les deux mains qui se serrent, en haut. Ou rejoignez une table déjà ouverte.",
    "One screen is enough. To link other phones running LifeStack: start the game, then tap the handshake icon at the top. Or join a table that is already open.",
    "Pietiek ar vienu ekrānu. Lai savienotu citus tālruņus ar LifeStack: sāciet spēli un pieskarieties roku ikonai augšā. Vai pievienojieties jau atvērtam galdam.",
)
add(
    "setup_duel_note_title",
    "Duel Commander · 2 joueurs",
    "Duel Commander · 2 players",
    "Duel Commander · 2 spēlētāji",
)
add(
    "setup_duel_note_body",
    "Face à face, avec les règles du Duel Commander. Chacun commence à 20 points de vie. On compte la taxe de commandant, pas les 21 points de dégâts.",
    "Head-to-head under Duel Commander rules. Each player starts at 20 life. Commander tax is tracked; the 21-damage rule is not.",
    "Viens pret vienu pēc Duel Commander noteikumiem. Katrs sāk ar 20 dzīvību. Skaita komandiera nodokli, nevis 21 bojājuma noteikumu.",
)
add("setup_commander_2p_title", "Commander à deux", "Two-player Commander", "Komandieris divatā")
add(
    "setup_commander_2p_body",
    "Vous n’êtes que deux, mais les règles restent celles du Commander. Chacun commence à 40 points de vie. Un joueur perd aussi s’il a reçu 21 points de dégâts de combat du même commandant. Pour la partie à deux à 20 points de vie, choisissez Duel Commander.",
    "Only two of you, but full Commander rules. Each starts at 40 life. A player also loses after 21 combat damage from the same commander. For a 20-life duel, pick Duel Commander.",
    "Jūs esat tikai divi, bet spēkā ir pilnie Komandiera noteikumi. Katrs sāk ar 40 dzīvību. Spēlētājs zaudē arī pēc 21 kaujas bojājuma no tā paša komandiera. Divu spēlētāju 20 dzīvības duelī izvēlieties Duel Commander.",
)
add(
    "setup_resume",
    "Reprendre · manche {round} · {names}",
    "Resume · round {round} · {names}",
    "Turpināt · raunds {round} · {names}",
)
add("profile_pick_title", "Charger un profil", "Load a profile", "Ielādēt profilu")
add(
    "profile_empty",
    "Aucun profil enregistré.\nÀ côté d’un nom, touchez l’icône Sauver le profil.",
    "No saved profiles yet.\nNext to a name, tap Save profile.",
    "Nav saglabātu profilu.\nBlakus vārdam pieskarieties ikonai Saglabāt profilu.",
)
add("profile_no_commander", "Sans commandant", "No commander", "Bez komandiera")
add("profile_save_confirm_title", "Sauver le profil ?", "Save this profile?", "Saglabāt profilu?")
add(
    "profile_save_confirm_body",
    "Enregistre « {name} » (couleur, commandants, art) pour le recharger plus tard.",
    'Saves "{name}" (color, commanders, art) so you can reload it later.',
    'Saglabā "{name}" (krāsu, komandierus, mākslu), lai vēlāk ielādētu.',
)
add("profile_save", "Sauver", "Save", "Saglabāt")

# --- settings (core) ---
add("settings_title", "Réglages", "Settings", "Iestatījumi")
add(
    "settings_cmd_life_title",
    "Dégâts de commandant et vie",
    "Commander damage and life",
    "Komandiera bojājumi un dzīvība",
)
add(
    "settings_cmd_life_body",
    "Un point de dégâts de combat d’un commandant retire aussi 1 point de vie. Si vous corrigez, seuls les points vraiment retirés reviennent.",
    "One point of combat damage from a commander also removes 1 life. If you correct a mistake, only the life that was actually removed comes back.",
    "Viens komandiera kaujas bojājuma punkts noņem arī 1 dzīvību. Labojot kļūdu, atgriežas tikai patiešām noņemtā dzīvība.",
)
add("settings_no_end_turn", "Sans fin de tour", "No end turn", "Bez gājiena beigām")
add(
    "settings_no_end_turn_subtitle",
    "Le bouton disparaît. Un retrait de points met en évidence le compte de celui qui les perd.",
    "The button is hidden. Losing life highlights that player’s panel.",
    "Poga pazūd. Dzīvības zaudēšana izceļ tā spēlētāja paneli.",
)
add("settings_all_sounds", "Tous les sons", "All sounds", "Visas skaņas")
add("settings_effect_sounds", "Bruitages", "Sound effects", "Efekti")
add(
    "settings_effect_sounds_subtitle",
    "Coups, sorts, défaite et victoire",
    "Hits, spells, defeat and victory",
    "Triecieni, burvestības, zaudējums un uzvara",
)
add("settings_touch_sounds", "Touches et glissements", "Taps and swipes", "Pieskārieni un vilkšana")
add("settings_animations", "Animations", "Animations", "Animācijas")
add("settings_haptic", "Vibrations", "Haptics", "Vibrācija")
add("settings_beginner_tips", "Bulles d’aide", "Help tips", "Palīdzības burbuļi")
add(
    "settings_beginner_tips_subtitle",
    "Éteintes, la table reste nette. Allumées, un maintien ou le i explique chaque option.",
    "Off keeps the table clean. On, a long-press or the i explains each option.",
    "Izslēgti galds paliek tīrs. Ieslēgti, ilgs pieskāriens vai i izskaidro katru opciju.",
)
add("settings_display", "Affichage", "Display", "Attēlojums")
add("settings_view_auto", "Auto", "Auto", "Auto")
add("settings_view_table", "Table", "Table", "Galds")
add("settings_view_list", "Liste", "List", "Saraksts")
add("settings_view_focus", "Gros plan", "Focus", "Tuvplāns")
add("settings_tournament", "Mode tournoi", "Tournament mode", "Turnīra režīms")
add("settings_timer", "Chronomètre", "Timer", "Taimeris")
add("settings_reset_mana", "Vider le mana en fin de tour", "Clear mana at end of turn", "Notīrīt manu gājiena beigās")
add(
    "settings_reset_storm",
    "Remettre la tempête à zéro en fin de tour",
    "Reset storm at end of turn",
    "Nullēt vētru gājiena beigās",
)

# --- player panel ---
add("end_turn", "Fin de tour", "End turn", "Gājiena beigas")
add("options_tooltip", "Options", "Options", "Opcijas")
add("got_it", "Compris", "Got it", "Sapratu")
add("victory", "Victoire", "Victory", "Uzvara")
add("defeat", "Défaite", "Defeat", "Zaudējums")
add("out_of_game", "Hors jeu", "Eliminated", "Ārā no spēles")
add("left_table", "A quitté la table", "Left the table", "Pameta galdu")
add("return_to_table", "Revenir à la table", "Back to the table", "Atpakaļ pie galda")
add("rematch_ask", "Une revanche ?", "Rematch?", "Revanšs?")
add("my_life", "Mes PV", "My life", "Mana dzīvība")
add("my_life_help", "− enlève un point, + le rend.", "− removes one, + restores one.", "− noņem vienu, + atdod vienu.")
add("foe_life", "Vie de {name}", "{name}’s life", "{name} dzīvība")
add("cmd_abbrev", "Cdt", "Cmd", "Kom")
add("cmd_pick", "Choisir", "Choose", "Izvēlēties")
add("cmd_remaining_short", "reste {n}", "{n} left", "atlicis {n}")
add("cmd_ko", "KO", "KO", "KO")
add("label_poison", "Poison", "Poison", "Inde")
add("label_monarch", "Monarque", "Monarch", "Monarhs")
add("label_initiative", "Initiative", "Initiative", "Iniciatīva")
add("label_tax", "Taxe {n}", "Tax {n}", "Nodoklis {n}")
add("label_citys_blessing", "Bénédiction de la Cité", "City’s Blessing", "Pilsētas svētība")
add("label_ring", "Anneau {n}", "Ring {n}", "Gredzens {n}")
add("score_pane_own", "Mes pertes", "My losses", "Mani zaudējumi")
add("score_pane_both", "Les deux", "Both", "Abi")
add("score_pane_foes", "Adversaires", "Opponents", "Pretinieki")

# --- formats ---
add("format_commander_label", "Commander (EDH)", "Commander (EDH)", "Komandieris (EDH)")
add(
    "format_commander_detail",
    "40 points de vie · 2 à 12 joueurs · 21 dégâts du même commandant",
    "40 life · 2 to 12 players · 21 damage from the same commander",
    "40 dzīvība · 2–12 spēlētāji · 21 bojājums no tā paša komandiera",
)
add(
    "format_commander_help",
    "Un commandant et un deck de 100 cartes. Chacun commence à 40. Vingt-et-un dégâts de combat du même commandant éliminent. À deux à 20 points de vie, choisissez Duel Commander.",
    "A commander and a 100-card deck. Everyone starts at 40. Twenty-one combat damage from the same commander is lethal. For a 20-life duel, pick Duel Commander.",
    "Komandieris un 100 kāršu klājs. Katrs sāk ar 40. Divdesmit viens kaujas bojājums no tā paša komandiera ir letāls. 20 dzīvības duelī izvēlieties Duel Commander.",
)
add("format_treachery_label", "Traîtrise (Treachery)", "Treachery", "Nodevība (Treachery)")
add(
    "format_treachery_detail",
    "Commander + rôles secrets (Chef, Traître…)",
    "Commander + secret roles (Leader, Traitor…)",
    "Komandieris + slepenās lomas (Līderis, Nodevējs…)",
)
add(
    "format_treachery_help",
    "Commander, avec des rôles secrets : Chef, Gardien, Assassin, Traître.",
    "Commander with secret roles: Leader, Guardian, Assassin, Traitor.",
    "Komandieris ar slepenām lomām: Līderis, Sargs, Slepkava, Nodevējs.",
)
add("format_duel_label", "Duel Commander", "Duel Commander", "Duel Commander")
add(
    "format_duel_detail",
    "2 joueurs · 20 PV · taxe · sans les 21 dégâts",
    "2 players · 20 life · tax · no 21-damage rule",
    "2 spēlētāji · 20 dzīvība · nodoklis · bez 21 bojājuma",
)
add(
    "format_duel_help",
    "Le face-à-face : toujours deux joueurs, 20 points de vie, taxe de commandant, sans la règle des 21.",
    "Head-to-head: always two players, 20 life, commander tax, no 21-damage rule.",
    "Viens pret vienu: vienmēr divi spēlētāji, 20 dzīvība, komandiera nodoklis, bez 21 bojājuma noteikuma.",
)
add("format_brawl_label", "Bagarre (Brawl)", "Brawl", "Kautiņš (Brawl)")
add(
    "format_brawl_detail",
    "25 PV · dégâts de commandant · taxe",
    "25 life · commander damage · tax",
    "25 dzīvība · komandiera bojājumi · nodoklis",
)
add(
    "format_brawl_help",
    "Un commandant et un deck plus petit, souvent en standard étendu.",
    "A commander and a smaller deck, often in a Standard-legal pool.",
    "Komandieris un mazāks klājs, bieži Standard ietvaros.",
)
add("format_constructed_label", "Construit (60 cartes)", "Constructed (60 cards)", "Sastādītais (60 kārtis)")
add(
    "format_constructed_detail",
    "20 PV · deck préparé · sans commandant",
    "20 life · built deck · no commander",
    "20 dzīvība · sagatavots klājs · bez komandiera",
)
add(
    "format_constructed_help",
    "Standard, Moderne, Pioneer, Legacy… un deck de 60 cartes sans commandant.",
    "Standard, Modern, Pioneer, Legacy… a 60-card deck with no commander.",
    "Standard, Modern, Pioneer, Legacy… 60 kāršu klājs bez komandiera.",
)
add("format_limited_label", "Limité (draft / scellé)", "Limited (draft / sealed)", "Ierobežotais (draft / sealed)")
add(
    "format_limited_detail",
    "20 PV · deck du draft · sans commandant",
    "20 life · draft deck · no commander",
    "20 dzīvība · drafta klājs · bez komandiera",
)
add(
    "format_limited_help",
    "Draft ou scellé : le deck se monte sur place, sans commandant.",
    "Draft or sealed: you build on site, with no commander.",
    "Draft vai sealed: klāju saliek uz vietas, bez komandiera.",
)
add("format_2hg_label", "Géant à deux têtes (2HG)", "Two-Headed Giant (2HG)", "Divgalvainais milzis (2HG)")
add(
    "format_2hg_detail",
    "30 PV partagés · équipes de 2",
    "30 shared life · teams of 2",
    "30 kopīga dzīvība · komandas pa 2",
)
add(
    "format_2hg_help",
    "Deux équipes de deux. La vie est partagée. Le poison officiel est à 15.",
    "Two teams of two. Life is shared. Official poison is 15.",
    "Divas komandas pa divi. Dzīvība ir kopīga. Oficiālā inde ir 15.",
)
add(
    "format_oathbreaker_label",
    "Briseur de serment (Oathbreaker)",
    "Oathbreaker",
    "Zvēresta lauzējs (Oathbreaker)",
)
add(
    "format_oathbreaker_detail",
    "20 PV · commandant + sort signature",
    "20 life · commander + signature spell",
    "20 dzīvība · komandieris + paraksta burvestība",
)
add(
    "format_oathbreaker_help",
    "Chaque joueur a un planeswalker commandant et un sort signature.",
    "Each player has a planeswalker commander and a signature spell.",
    "Katram spēlētājam ir planeswalker komandieris un paraksta burvestība.",
)
add("format_custom_label", "Personnalisé", "Custom", "Pielāgots")
add(
    "format_custom_detail",
    "Points de vie, seuils et options au choix",
    "Life, thresholds, and options as you like",
    "Dzīvība, sliekšņi un opcijas pēc izvēles",
)
add(
    "format_custom_help",
    "Tout se règle à la main : vie de départ, seuils, options de table.",
    "Everything is set by hand: starting life, thresholds, table options.",
    "Viss tiek iestatīts manuāli: sākuma dzīvība, sliekšņi, galda opcijas.",
)
add("victory_solo", "{name} gagne la partie", "{name} wins the game", "{name} uzvar spēli")
add("victory_team", "{names} gagnent la partie", "{names} win the game", "{names} uzvar spēli")
add("defeat_reason_concede", "Concession", "Concession", "Padzīšanās")
add("defeat_reason_no_life", "Plus de points de vie", "Out of life", "Nav vairs dzīvības")
add("defeat_reason_poison", "{n} marqueurs poison", "{n} poison counters", "{n} indes marķieri")
add(
    "defeat_reason_commander",
    "Dégâts de {commander} ({threshold})",
    "Damage from {commander} ({threshold})",
    "Bojājumi no {commander} ({threshold})",
)

# --- table / menu ---
add("leave_salon_title", "Retour au salon", "Back to lobby", "Atpakaļ uz vestibilu")
add(
    "leave_salon_message",
    "La partie reste enregistrée sur cet appareil.",
    "The game stays saved on this device.",
    "Spēle paliek saglabāta šajā ierīcē.",
)
add("leave_salon_confirm", "Quitter la table", "Leave the table", "Atstāt galdu")
add(
    "tips_enabled_snack",
    "Bulles d’aide activées.",
    "Help tips on.",
    "Palīdzības burbuļi ieslēgti.",
)
add(
    "tips_disabled_snack",
    "Bulles d’aide désactivées.",
    "Help tips off.",
    "Palīdzības burbuļi izslēgti.",
)
add("coach_your_turn", "À vous", "Your turn", "Tavs gājiens")
add("coach_seen", "Vu", "Seen", "Redzēts")
add("bar_salon", "Salon", "Lobby", "Vestibils")
add("bar_undo", "Annuler", "Undo", "Atsaukt")
add("bar_redo", "Rétablir", "Redo", "Atkārtot")
add("bar_history", "Historique", "History", "Vēsture")
add("bar_dice", "Dés", "Dice", "Kauliņi")
add("bar_animations", "Animations", "Animations", "Animācijas")
add("bar_layout", "Disposition de l’écran", "Screen layout", "Ekrāna izkārtojums")
add("bar_whole_table", "La table entière", "Whole table", "Viss galds")
add("bar_link_phones", "Relier les téléphones", "Link phones", "Savienot tālruņus")
add("bar_menu", "Menu", "Menu", "Izvēlne")
add("menu_players", "Joueurs / places", "Players / seats", "Spēlētāji / vietas")
add("menu_first_draw", "Tirage : qui commence", "Draw: who starts", "Izloze: kurš sāk")
add("menu_card_journal", "Noter une carte", "Log a card", "Pierakstīt kārti")
add("menu_day_night", "Jour / nuit", "Day / night", "Diena / nakts")
add("menu_tips_on", "Activer les bulles d’aide", "Turn help tips on", "Ieslēgt palīdzības burbuļus")
add("menu_tips_off", "Désactiver les bulles d’aide", "Turn help tips off", "Izslēgt palīdzības burbuļus")
add("menu_settings", "Réglages", "Settings", "Iestatījumi")
add("menu_rematch", "Revanche", "Rematch", "Revanšs")
add("menu_reset", "Remise à zéro", "Reset", "Atiestatīt")
add("menu_about", "À propos", "About", "Par programmu")
add("banner_recap", "Récap", "Recap", "Kopsavilkums")
add("banner_rematch", "Revanche", "Rematch", "Revanšs")
add("banner_zero", "À zéro", "Reset", "Uz nulli")
add("restart_rematch", "Revanche", "Rematch", "Revanšs")
add("restart_zero", "Remise à zéro", "Full reset", "Pilna atiestatīšana")
add(
    "restart_keep_names",
    "Les noms, couleurs et commandants restent. Vies, dégâts, poison et taxes repartent au départ.",
    "Names, colors, and commanders stay. Life, damage, poison, and taxes reset.",
    "Vārdi, krāsas un komandieri paliek. Dzīvība, bojājumi, inde un nodokļi sākas no jauna.",
)
add("restart_who_starts", "Qui commence ?", "Who starts?", "Kurš sāk?")
add(
    "restart_who_starts_hint",
    "Demandez à la table : perdant d’abord, même ordre, ou nouveau tirage.",
    "Ask the table: loser first, same order, or a new draw.",
    "Jautājiet galdam: zaudētājs pirmais, tā pati kārtība vai jauna izloze.",
)
add("restart_keep_order", "Garder l’ordre actuel", "Keep current order", "Saglabāt pašreizējo kārtību")
add("restart_pick_player", "Choisir un joueur", "Pick a player", "Izvēlēties spēlētāju")
add("restart_draw", "Tirage au sort", "Random draw", "Nejauša izloze")
add("restart_first_player", "Premier joueur", "First player", "Pirmais spēlētājs")
add("combat_ask_generic", "C’est une blessure de combat ?", "Was that combat damage?", "Vai tie bija kaujas bojājumi?")
add("combat_not_combat", "Pas du combat", "Not combat", "Nav kauja")
add(
    "monarch_end_step_toast",
    "Vous êtes monarque. Au début de votre étape de fin, piochez une carte.",
    "You are the monarch. At the beginning of your end step, draw a card.",
    "Tu esi monarhs. Savas beigu soļa sākumā paņem kārti.",
)
add("main_night_closed", "Soirée fermée", "Game night closed", "Vakars aizvērts")
add(
    "main_table_open_failed",
    "Cette table n’a pas pu s’ouvrir.",
    "That table could not be opened.",
    "Šo galdu neizdevās atvērt.",
)

# --- privacy (short) ---
add("privacy_title", "Vie privée & données (RGPD)", "Privacy & data (GDPR)", "Privātums un dati (VDAR)")
add(
    "privacy_intro",
    "LifeStack fonctionne sans compte. La partie sur un seul téléphone, ou entre téléphones du même lieu, reste sur les appareils.",
    "LifeStack needs no account. A game on one phone, or phones in the same place, stays on those devices.",
    "LifeStack darbojas bez konta. Spēle vienā tālrunī vai tālruņos vienā vietā paliek uz ierīcēm.",
)
add("privacy_clear_cache", "Effacer le cache Scryfall", "Clear Scryfall cache", "Notīrīt Scryfall kešatmiņu")
add("privacy_cache_cleared", "Cache cartes effacé.", "Card cache cleared.", "Kāršu kešatmiņa notīrīta.")
add(
    "privacy_wipe_all",
    "Effacer toutes les données locales",
    "Erase all local data",
    "Dzēst visus lokālos datus",
)
add("privacy_wipe_confirm_title", "Tout effacer ?", "Erase everything?", "Dzēst visu?")
add(
    "privacy_wipe_confirm_body",
    "Supprime parties, profils, soirée, réglages et caches sur cet appareil. Irréversible.",
    "Deletes games, profiles, game night, settings, and caches on this device. This cannot be undone.",
    "Dzēš spēles, profilus, vakaru, iestatījumus un kešatmiņu šajā ierīcē. Neatgriezeniski.",
)
add("privacy_wipe", "Effacer", "Erase", "Dzēst")
add("privacy_wiped", "Données locales effacées.", "Local data erased.", "Lokālie dati izdzēsti.")
add("privacy_wipe_failed", "Effacement impossible.", "Could not erase data.", "Neizdevās dzēst datus.")

# --- tips ---
add("tip_poison_title", "Poison", "Poison", "Inde")
add(
    "tip_poison_msg",
    "La fiole, c’est le poison. À {threshold}, le joueur perd (10 en général, 15 en Géant à deux têtes).",
    "The vial is poison. At {threshold}, that player loses (usually 10; 15 in Two-Headed Giant).",
    "Flakons ir inde. Pie {threshold} spēlētājs zaudē (parasti 10; 15 Divgalvainajā milzī).",
)
add("tip_monarch_title", "Monarque", "Monarch", "Monarhs")
add(
    "tip_monarch_msg",
    "La couronne, c’est le monarque. À votre étape de fin, vous piochiez. Personne n’est indétrônable.",
    "The crown is the monarch. At your end step, you draw. Nobody is unbeatable.",
    "Kronis ir monarhs. Beigu solī tu paņem kārti. Neviens nav neaizskaramas.",
)
add("tip_end_turn_title", "Fin de tour", "End turn", "Gājiena beigas")
add(
    "tip_end_turn_msg",
    "Passe la main au joueur suivant et applique les remises à zéro choisies (mana, tempête…).",
    "Passes play to the next player and applies chosen resets (mana, storm…). ",
    "Nodod gājienu nākamajam un piemēro izvēlētās nullēšanas (mana, vētra…).",
)
add("tip_day_night_title", "Jour et nuit", "Day and night", "Diena un nakts")
add(
    "tip_day_night_msg",
    "Le soleil et la lune couvrent toute la table. Touchez le centre pour basculer.",
    "Sun and moon cover the whole table. Tap the center to switch.",
    "Saule un mēness pārklāj visu galdu. Pieskarieties centram, lai pārslēgtu.",
)
add("tip_gear_title", "Options", "Options", "Opcijas")
add(
    "tip_gear_msg",
    "Chaque option est un symbole : poison, monarque, taxe, mana… Maintenez pour l’explication.",
    "Each option is a symbol: poison, monarch, tax, mana… Long-press for the tip.",
    "Katra opcija ir simbols: inde, monarhs, nodoklis, mana… Ilgi turiet skaidrojumam.",
)


def dart_escape(s: str) -> str:
    return (
        s.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("\n", "\\n")
        .replace("\r", "")
    )


def write_catalog(path: Path, name: str, index: int, header: str) -> None:
    lines = [
        f"// LifeStack — {header}",
        f"const Map<String, String> {name} = {{",
    ]
    for key in sorted(DATA):
        lines.append(f"  '{key}': '{dart_escape(DATA[key][index])}',")
    lines.append("};")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {path.name} ({len(DATA)} keys)")


def main() -> None:
    root = Path(r"C:\Users\Super\mtg_table\lib\l10n")
    root.mkdir(parents=True, exist_ok=True)
    write_catalog(root / "catalog_fr.dart", "catalogFr", 0, "catalogue français")
    write_catalog(root / "catalog_en.dart", "catalogEn", 1, "English catalog")
    write_catalog(root / "catalog_lv.dart", "catalogLv", 2, "latviešu katalogs")
    # verify same keys
    assert len(DATA) == len(set(DATA))
    print("OK", len(DATA))


if __name__ == "__main__":
    main()
