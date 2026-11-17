import 'package:flutter/widgets.dart';
import 'package:mtg_table/l10n/app_lang.dart';
import 'package:mtg_table/l10n/catalog_en.dart';
import 'package:mtg_table/l10n/catalog_fr.dart';
import 'package:mtg_table/l10n/catalog_lv.dart';

/// Accès aux chaînes : `L10n.of(context).t('key')` ou `context.t('key')`.
class L10n {
  const L10n(this.lang);

  final AppLang lang;

  static L10n of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_L10nScope>();
    return scope?.l10n ?? const L10n(AppLang.fr);
  }

  static AppLang langOf(BuildContext context) => of(context).lang;

  Map<String, String> get _map => switch (lang) {
    AppLang.fr => catalogFr,
    AppLang.en => catalogEn,
    AppLang.lv => catalogLv,
  };

  /// Traduit [key]. Les `{name}` du [vars] remplacent les espaces réservés.
  String t(String key, [Map<String, String>? vars]) {
    var text = _map[key] ?? catalogFr[key] ?? key;
    if (vars != null) {
      for (final entry in vars.entries) {
        text = text.replaceAll('{${entry.key}}', entry.value);
      }
    }
    return text;
  }
}

class _L10nScope extends InheritedWidget {
  const _L10nScope({required this.l10n, required super.child});

  final L10n l10n;

  @override
  bool updateShouldNotify(_L10nScope oldWidget) =>
      oldWidget.l10n.lang != l10n.lang;
}

/// Enveloppe l’arbre avec la langue courante.
class L10nProvider extends StatelessWidget {
  const L10nProvider({
    super.key,
    required this.lang,
    required this.child,
  });

  final AppLang lang;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _L10nScope(l10n: L10n(lang), child: child);
  }
}

extension L10nContext on BuildContext {
  L10n get l10n => L10n.of(this);

  String t(String key, [Map<String, String>? vars]) => l10n.t(key, vars);
}
