import 'package:flutter/material.dart';

const playerPalette = <Color>[
  Color(0xFFE8B84A),
  Color(0xFF5BA8FF),
  Color(0xFFFF7A96),
  Color(0xFF4FD6A0),
  Color(0xFFB794F6),
  Color(0xFFFF8F5C),
  Color(0xFF3DCEC9),
  Color(0xFFFF9AD5),
];

const manaPalette = <String, Color>{
  'W': Color(0xFFF3E6C4),
  'U': Color(0xFF7EB6FF),
  'B': Color(0xFFB79BC8),
  'R': Color(0xFFFF7A6E),
  'G': Color(0xFF7DCE86),
  'C': Color(0xFFD5D5D5),
};

const ink = Color(0xFF07090E);
const panelInk = Color(0xFF151A24);
const line = Color(0xFF333C4F);
const accent = Color(0xFF3FA86A);
const accentGold = Color(0xFFD4A85C);
const dangerWarn = Color(0xFFFFB020);
const dangerCrit = Color(0xFFFF3D5A);

/// Niveau de menace selon les PV restants (vs vie de départ).
enum LifeBand { safe, warning, critical }

/// Seuil d’alerte / critique proportionnel au format (20 / 40 PV…).
LifeBand lifeBand({required int life, required int startingLife}) {
  if (life <= 0) return LifeBand.critical;
  final start = startingLife.clamp(1, 200);
  final warningAt = (start * 0.25).ceil().clamp(6, 12);
  final criticalAt = (start * 0.125).ceil().clamp(3, 6);
  if (life <= criticalAt) return LifeBand.critical;
  if (life <= warningAt) return LifeBand.warning;
  return LifeBand.safe;
}

Color lifeBandColor(LifeBand band) => switch (band) {
  LifeBand.safe => Colors.white,
  LifeBand.warning => dangerWarn,
  LifeBand.critical => dangerCrit,
};

Color playerColor(int index) =>
    playerPalette[index.abs() % playerPalette.length];

String playerInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.substring(0, 1).toUpperCase();
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
    surface: panelInk,
  ).copyWith(
    primary: accent,
    secondary: accentGold,
    tertiary: const Color(0xFF5BA8FF),
    error: dangerCrit,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: ink,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(52, 52),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: Colors.white,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      selectedColor: accent.withValues(alpha: 0.35),
      checkmarkColor: Colors.white,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF1A2130),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF1A2130),
      showDragHandle: true,
    ),
    popupMenuTheme: const PopupMenuThemeData(color: Color(0xFF1A2130)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return Colors.white70;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accent;
        return const Color(0xFF3A4254);
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0E121A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: accent, width: 1.4),
      ),
    ),
  );
}

TextStyle lifeStyle(double size, Color color) {
  return TextStyle(
    fontSize: size,
    height: 1,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.2,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
    shadows: [
      Shadow(
        color: color.withValues(alpha: 0.35),
        blurRadius: size > 60 ? 18 : 10,
      ),
    ],
  );
}
