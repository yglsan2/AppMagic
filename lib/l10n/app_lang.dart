import 'package:flutter/material.dart';

/// Langues supportées par LifeStack.
enum AppLang {
  fr,
  en,
  lv;

  String get code => name;

  Locale get locale => Locale(code);

  /// Nom de la langue dans cette langue.
  String get nativeName => switch (this) {
    AppLang.fr => 'Français',
    AppLang.en => 'English',
    AppLang.lv => 'Latviešu',
  };

  static AppLang fromCode(String? raw) {
    for (final lang in AppLang.values) {
      if (lang.code == raw) return lang;
    }
    return AppLang.fr;
  }

  static const supported = AppLang.values;
}
