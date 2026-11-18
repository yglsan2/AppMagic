# -*- coding: utf-8 -*-
from pathlib import Path
import re

ROOT = Path(r"C:\Users\Super\mtg_table")


def fix_setup() -> None:
    path = ROOT / "lib/ui/setup/setup_screen.dart"
    text = path.read_text(encoding="utf-8")

    broken = """              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                'LifeStack',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.05,
                  color: const Color(0xFFF4F7FB),
                ),
              ),
              const SizedBox(height: 18),
"""
    fixed = """              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'LifeStack',
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1.05,
                        color: const Color(0xFFF4F7FB),
                      ),
                    ),
                  ),
                  LanguageButton(
                    lang: widget.settings.lang,
                    onChanged: (lang) => widget.onLang?.call(lang),
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 18),
"""
    if broken in text:
        text = text.replace(broken, fixed, 1)
        print("fixed broken Row")
    else:
        print("broken Row pattern not found")

    # Remove const before Text/SnackBar that call context.t
    text = re.sub(
        r"const (Text|SnackBar|FilledButton|OutlinedButton|TextButton|ListTile|ExpansionTile)\(",
        r"\1(",
        text,
    )
    # More targeted: const Text(context.t -> Text(context.t
    text = text.replace("const Text(\n                    context.t(", "Text(\n                    context.t(")
    text = text.replace("const Text(context.t(", "Text(context.t(")
    text = text.replace("const SnackBar(\n                                    content: Text(\n                                      context.t(",
                        "SnackBar(\n                                    content: Text(\n                                      context.t(")
    text = text.replace("title: const Text(\n                    context.t(", "title: Text(\n                    context.t(")
    text = text.replace("label: const Text(context.t(", "label: Text(context.t(")
    text = text.replace("child: const Text(context.t(", "child: Text(context.t(")
    text = text.replace("const Expanded(child: Text(context.t(", "Expanded(child: Text(context.t(")

    # ExpansionTile had const Text for title
    text = text.replace(
        "title: const Text(\n                    context.t('setup_tools_night_title'),",
        "title: Text(\n                    context.t('setup_tools_night_title'),",
    )

    path.write_text(text, encoding="utf-8")
    print("setup fixed")


def fix_main() -> None:
    path = ROOT / "lib/main.dart"
    text = path.read_text(encoding="utf-8")
    text = text.replace(
        """              return const Scaffold(
                body: Center(child: Text(context.t('main_night_closed'))),
              );""",
        """              return Scaffold(
                body: Center(child: Text(context.t('main_night_closed'))),
              );""",
    )
    text = text.replace(
        """                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(context.t('main_table_open_failed')),
                    ),
                  );""",
        """                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.t('main_table_open_failed')),
                    ),
                  );""",
    )
    # remove unused language_button import from main
    text = text.replace(
        "import 'package:mtg_table/ui/widgets/language_button.dart';\n",
        "",
    )
    # Fix closing braces if broken
    path.write_text(text, encoding="utf-8")
    # validate end of file
    print("main end:", repr(path.read_text(encoding="utf-8")[-120:]))


def fix_settings() -> None:
    path = ROOT / "lib/ui/sheets/settings_sheet.dart"
    text = path.read_text(encoding="utf-8")
    text = text.replace(
        """        const Text(
          context.t('settings_title'),
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
""",
        """        Text(
          context.t('settings_title'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('language_title')),
          trailing: LanguageButton(
            lang: _settings.lang,
            onChanged: (lang) {
              final next = _settings.copyWith(lang: lang);
              setState(() => _settings = next);
              widget.onChanged(next);
            },
          ),
        ),
        const Divider(),
""",
    )
    path.write_text(text, encoding="utf-8")
    print("settings fixed")


def fix_player_panel() -> None:
    path = ROOT / "lib/ui/widgets/player_panel.dart"
    text = path.read_text(encoding="utf-8")
    text = text.replace("const Text(context.t(", "Text(context.t(")
    text = text.replace("title: const Text(context.t(", "title: Text(context.t(")
    # Oui/Non in revenge might be const Text('Oui') already replaced
    path.write_text(text, encoding="utf-8")
    print("player_panel const cleaned")


def main() -> None:
    fix_setup()
    fix_main()
    fix_settings()
    fix_player_panel()


if __name__ == "__main__":
    main()
