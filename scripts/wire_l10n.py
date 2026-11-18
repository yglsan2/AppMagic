# -*- coding: utf-8 -*-
from pathlib import Path

ROOT = Path(r"C:\Users\Super\mtg_table")


def patch_models() -> None:
    path = ROOT / "lib" / "domain" / "models.dart"
    text = path.read_text(encoding="utf-8")
    if "app_lang.dart" not in text:
        text = text.replace(
            "import 'package:mtg_table/domain/handicap.dart';\n",
            "import 'package:mtg_table/domain/handicap.dart';\n"
            "import 'package:mtg_table/l10n/app_lang.dart';\n",
            1,
        )
        if "app_lang.dart" not in text:
            # insert after first import line
            first = text.index("\n") + 1
            text = (
                text[:first]
                + "import 'package:mtg_table/l10n/app_lang.dart';\n"
                + text[first:]
            )

    if "this.lang" not in text:
        text = text.replace(
            "    this.touchSounds = true,\n  });",
            "    this.touchSounds = true,\n"
            "    this.lang = AppLang.fr,\n  });",
            1,
        )
        text = text.replace(
            "    touchSounds: true,\n  );",
            "    touchSounds: true,\n"
            "    lang: AppLang.fr,\n  );",
            1,
        )
        text = text.replace(
            "  final bool touchSounds;\n  final String epitaphPoison;",
            "  final bool touchSounds;\n"
            "  final AppLang lang;\n"
            "  final String epitaphPoison;",
            1,
        )
        # copyWith param
        text = text.replace(
            "    bool? touchSounds,\n  }) {",
            "    bool? touchSounds,\n"
            "    AppLang? lang,\n  }) {",
            1,
        )
        text = text.replace(
            "      touchSounds: touchSounds ?? this.touchSounds,\n    );",
            "      touchSounds: touchSounds ?? this.touchSounds,\n"
            "      lang: lang ?? this.lang,\n    );",
            1,
        )
        text = text.replace(
            "    'touchSounds': touchSounds,\n    'namedPanes': {",
            "    'touchSounds': touchSounds,\n"
            "    'lang': lang.code,\n"
            "    'namedPanes': {",
            1,
        )
        text = text.replace(
            "      touchSounds: json['touchSounds'] as bool? ?? (json['sounds'] as bool? ?? true),\n    );",
            "      touchSounds: json['touchSounds'] as bool? ?? (json['sounds'] as bool? ?? true),\n"
            "      lang: AppLang.fromCode(json['lang'] as String?),\n    );",
            1,
        )

    path.write_text(text, encoding="utf-8")
    print("models patched", "lang" in text)


def patch_main() -> None:
    path = ROOT / "lib" / "main.dart"
    text = path.read_text(encoding="utf-8")
    if "l10n/l10n.dart" not in text:
        text = text.replace(
            "import 'package:mtg_table/domain/models.dart';\n",
            "import 'package:mtg_table/domain/models.dart';\n"
            "import 'package:mtg_table/l10n/app_lang.dart';\n"
            "import 'package:mtg_table/l10n/l10n.dart';\n"
            "import 'package:mtg_table/ui/widgets/language_button.dart';\n",
            1,
        )
    # Replace MaterialApp locale wiring
    old = """    return MaterialApp(
      title: 'LifeStack',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // RGAA : respecter l’agrandissement système, sans casser la table.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = media.textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.6,
        );
        return MediaQuery(
          data: media.copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: ListenableBuilder(
        listenable: _app,
        builder: (context, _) {
"""
    new = """    return ListenableBuilder(
      listenable: _app,
      builder: (context, _) {
        final lang = _app.settings.lang;
        return L10nProvider(
          lang: lang,
          child: MaterialApp(
      title: 'LifeStack',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: lang.locale,
      supportedLocales: [
        for (final item in AppLang.supported) item.locale,
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // RGAA : respecter l’agrandissement système, sans casser la table.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = media.textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.6,
        );
        return MediaQuery(
          data: media.copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Builder(
        builder: (context) {
"""
    if old in text:
        text = text.replace(old, new, 1)
        # close extra braces at end of home ListenableBuilder
        # Find the closing of the old ListenableBuilder home
        # The structure ends with:        },\n      ),\n    );\n  }\n}
        # After change we need:        },\n      ),\n          ),\n        );\n      },\n    );\n  }\n}
        closing = """        },
      ),
    );
  }
}
"""
        new_closing = """        },
      ),
          ),
        );
      },
    );
  }
}
"""
        if text.endswith(closing) or closing in text:
            text = text.replace(closing, new_closing, 1)
        else:
            print("WARN: closing pattern not exact")
            print(repr(text[-200:]))

    # SetupScreen needs onSettings for language - pass updateSettings via wrapping
    # Also add language to SetupScreen - change call site
    if "onLang:" not in text and "onSettingsLang" not in text:
        text = text.replace(
            """            return SetupScreen(
              settings: _app.settings,
              group: _app.group,
              resumeLabel: _app.resumeLabel,
              nightLabel: _app.night == null
                  ? null
                  : 'Soirée · ${_app.night!.code}',
              profiles: _app.profiles,
              onSaveProfile: _app.upsertProfile,
              onStart: _app.start,
              onResume: _app.resume,""",
            """            return SetupScreen(
              settings: _app.settings,
              group: _app.group,
              resumeLabel: _app.resumeLabel,
              nightLabel: _app.night == null
                  ? null
                  : context.t('setup_night_with_code', {'code': _app.night!.code}),
              profiles: _app.profiles,
              onSaveProfile: _app.upsertProfile,
              onLang: (lang) => _app.updateSettings(
                _app.settings.copyWith(lang: lang),
              ),
              onStart: _app.start,
              onResume: _app.resume,""",
            1,
        )
        # add missing key setup_night_with_code if needed - use simple string for now
        text = text.replace(
            "context.t('setup_night_with_code', {'code': _app.night!.code})",
            "switch (lang) { AppLang.fr => 'Soirée · ${_app.night!.code}', AppLang.en => 'Night · ${_app.night!.code}', AppLang.lv => 'Vakars · ${_app.night!.code}' }",
            1,
        )

    # table open failed snack
    text = text.replace(
        "content: Text('Cette table n’a pas pu s’ouvrir.'),",
        "content: Text(context.t('main_table_open_failed')),",
        1,
    )
    text = text.replace(
        "body: Center(child: Text('Soirée fermée')),",
        "body: Center(child: Text(context.t('main_night_closed'))),",
        1,
    )

    path.write_text(text, encoding="utf-8")
    print("main patched")


def patch_setup() -> None:
    path = ROOT / "lib" / "ui" / "setup" / "setup_screen.dart"
    text = path.read_text(encoding="utf-8")
    if "language_button.dart" not in text:
        text = text.replace(
            "import 'package:mtg_table/ui/widgets/help_tip.dart';\n",
            "import 'package:mtg_table/ui/widgets/help_tip.dart';\n"
            "import 'package:mtg_table/ui/widgets/language_button.dart';\n"
            "import 'package:mtg_table/l10n/app_lang.dart';\n"
            "import 'package:mtg_table/l10n/l10n.dart';\n",
            1,
        )
    if "onLang" not in text:
        text = text.replace(
            "    this.onSaveProfile,\n  });",
            "    this.onSaveProfile,\n    this.onLang,\n  });",
            1,
        )
        text = text.replace(
            "  final Future<void> Function(PlayerProfile profile)? onSaveProfile;\n",
            "  final Future<void> Function(PlayerProfile profile)? onSaveProfile;\n"
            "  final ValueChanged<AppLang>? onLang;\n",
            1,
        )
    # Insert language button near brand title
    if "LanguageButton" not in text:
        old = """              Text(
                'LifeStack',
"""
        # Find a good insertion - after the brand image / title row
        marker = "              Text(\n                'LifeStack',"
        if marker in text:
            # wrap title area with a Row including flag
            text = text.replace(
                marker,
                """              Row(
                children: [
                  const Expanded(
                    child: Text(
                'LifeStack',""",
                1,
            )
            # After the LifeStack TextStyle closing of that Text, add LanguageButton
            # Look for the Text that contains LifeStack - fragile. Simpler: add Align at top of column
            pass
        # Simpler approach: add LanguageButton as first child in the scroll column after brand
        brand = "              Image.asset(\n                  'assets/brand/lifestack.png',"
        if brand in text and "LanguageButton(" not in text:
            text = text.replace(
                brand,
                """              Align(
                alignment: Alignment.centerRight,
                child: LanguageButton(
                  lang: widget.settings.lang,
                  onChanged: (lang) => widget.onLang?.call(lang),
                  compact: true,
                ),
              ),
              Image.asset(
                  'assets/brand/lifestack.png',""",
                1,
            )

    # Use context.t for a few high-visibility strings
    replacements = [
        ("'Vie privée'", "context.t('setup_privacy')"),
        ("'Historique'", "context.t('setup_history')"),
        ("'Cartes'", "context.t('setup_cards')"),
        ("'Importer'", "context.t('setup_import')"),
        ("'Format'", "context.t('setup_format_heading')"),
        ("'Outils & soirée'", "context.t('setup_tools_night_title')"),
        (
            "'Soirée multi-tables, import, stats, cartes…'",
            "context.t('setup_tools_night_subtitle')",
        ),
        ("'Partenaire / 2e commandant'", "context.t('setup_partner_commander')"),
        ("'Plus d’options'", "context.t('setup_more_options')"),
        ("'Moins d’options'", "context.t('setup_fewer_options')"),
        ("'Dégâts de commandant'", "context.t('setup_commander_damage')"),
        ("'Taxe de commandant'", "context.t('setup_commander_tax')"),
        ("'Points de vie de départ'", "context.t('setup_starting_life')"),
        ("'Rejoindre une table LifeStack'", "context.t('setup_join_table')"),
        ("'Indiquez un nom de commandant.'", "context.t('setup_commander_name_required')"),
        ("'Profil enregistré.'", "context.t('setup_profile_saved')"),
        (
            "'Enregistrement du profil impossible.'",
            "context.t('setup_profile_save_failed')",
        ),
        (
            "'Import impossible : partie invalide ou corrompue.'",
            "context.t('setup_import_failed')",
        ),
        ("labelText: 'Nom'", "labelText: context.t('setup_name_label')"),
    ]
    for a, b in replacements:
        if a in text:
            text = text.replace(a, b)

    path.write_text(text, encoding="utf-8")
    print("setup patched")


def patch_settings() -> None:
    path = ROOT / "lib" / "ui" / "sheets" / "settings_sheet.dart"
    text = path.read_text(encoding="utf-8")
    if "language_button.dart" not in text:
        text = text.replace(
            "import 'package:mtg_table/ui/widgets/help_tip.dart';\n",
            "import 'package:mtg_table/ui/widgets/help_tip.dart';\n"
            "import 'package:mtg_table/ui/widgets/language_button.dart';\n"
            "import 'package:mtg_table/l10n/l10n.dart';\n",
            1,
        )
    if "LanguageButton" not in text:
        # Find title Réglages and add language row after it
        marker = "Text(\n            'Réglages',"
        alt = "'Réglages'"
        if "settings_title" not in text:
            text = text.replace("'Réglages'", "context.t('settings_title')", 1)
        insert_after = "context.t('settings_title')"
        # Add a language ListTile early in the column children
        needle = "child: ListView(\n        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),\n        children: ["
        if needle in text and "LanguageButton(" not in text:
            text = text.replace(
                needle,
                needle
                + """
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('language_title')),
            trailing: LanguageButton(
              lang: _settings.lang,
              onChanged: (lang) {
                setState(() => _settings = _settings.copyWith(lang: lang));
                widget.onChanged(_settings.copyWith(lang: lang));
              },
            ),
          ),
          const Divider(),""",
                1,
            )
    path.write_text(text, encoding="utf-8")
    print("settings patched")


def patch_player_panel_labels() -> None:
    path = ROOT / "lib" / "ui" / "widgets" / "player_panel.dart"
    text = path.read_text(encoding="utf-8")
    if "l10n/l10n.dart" not in text:
        text = text.replace(
            "import 'package:flutter/material.dart';\n",
            "import 'package:flutter/material.dart';\n"
            "import 'package:mtg_table/l10n/l10n.dart';\n",
            1,
        )
    reps = [
        ("'Victoire'", "context.t('victory')"),
        ("'Défaite'", "context.t('defeat')"),
        ("'Hors jeu'", "context.t('out_of_game')"),
        ("'A quitté la table'", "context.t('left_table')"),
        ("'Une revanche ?'", "context.t('rematch_ask')"),
        ("'Mes PV'", "context.t('my_life')"),
        ("label: 'Cdt'", "label: context.t('cmd_abbrev')"),
        ("'Choisir'", "context.t('cmd_pick')"),
        ("'Oui'", "context.t('common_yes')"),
        ("'Non'", "context.t('common_no')"),
        ("'Compris'", "context.t('got_it')"),
        ("'Fin de tour'", "context.t('end_turn')"),
        ("'Mes pertes'", "context.t('score_pane_own')"),
    ]
    for a, b in reps:
        text = text.replace(a, b)
    path.write_text(text, encoding="utf-8")
    print("player_panel labels patched")


def main() -> None:
    patch_models()
    patch_main()
    patch_setup()
    patch_settings()
    patch_player_panel_labels()
    print("done")


if __name__ == "__main__":
    main()
