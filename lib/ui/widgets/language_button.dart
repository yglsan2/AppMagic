import 'package:flutter/material.dart';
import 'package:mtg_table/l10n/app_lang.dart';
import 'package:mtg_table/l10n/l10n.dart';

/// Bouton drapeau + liste déroulante des langues.
class LanguageButton extends StatelessWidget {
  const LanguageButton({
    super.key,
    required this.lang,
    required this.onChanged,
    this.compact = false,
  });

  final AppLang lang;
  final ValueChanged<AppLang> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tip = context.t('language_title');
    return PopupMenuButton<AppLang>(
      tooltip: tip,
      initialValue: lang,
      onSelected: onChanged,
      offset: const Offset(0, 40),
      itemBuilder: (context) => [
        for (final item in AppLang.supported)
          PopupMenuItem<AppLang>(
            value: item,
            child: Row(
              children: [
                Text(item.flag, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.nativeName,
                    style: TextStyle(
                      fontWeight:
                          item == lang ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
                if (item == lang)
                  Icon(
                    Icons.check,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
      ],
      child: compact
          ? Text(lang.flag, style: const TextStyle(fontSize: 26))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 6),
                  Text(
                    lang.nativeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
    );
  }
}
