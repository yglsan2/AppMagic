import 'package:flutter/material.dart';

const playerPalette = <Color>[
  Color(0xFFE4B15C),
  Color(0xFF6AA8FF),
  Color(0xFFFF7D9C),
  Color(0xFF3DDCB4),
  Color(0xFFB59BFF),
  Color(0xFFFF9A62),
  Color(0xFF45D0D6),
  Color(0xFFFF8EC8),
];

const manaPalette = <String, Color>{
  'W': Color(0xFFF3E6C4),
  'U': Color(0xFF7EB6FF),
  'B': Color(0xFFB79BC8),
  'R': Color(0xFFFF7A6E),
  'G': Color(0xFF7DCE86),
  'C': Color(0xFFD5D5D5),
};

const ink = Color(0xFF090B10);
const panelInk = Color(0xFF141820);
const surface = Color(0xFF1A2030);
const line = Color(0xFF2C3548);
const accent = Color(0xFF3DDC97);
const onAccent = Color(0xFF062018);
const accentGold = Color(0xFFE7C27A);
const dangerWarn = Color(0xFFF0B429);
const dangerCrit = Color(0xFFFF4D6A);
const gain = Color(0xFF5EE0A8);
const loss = Color(0xFFFF7A8A);

const pageGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF151B28),
    Color(0xFF090B10),
    Color(0xFF0C1016),
  ],
);

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
  LifeBand.warning => const Color(0xFFFF7A55),
  LifeBand.critical => const Color(0xFFFF2438),
};

Color playerColor(int index) =>
    playerPalette[index.abs() % playerPalette.length];

String playerInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.substring(0, 1).toUpperCase();
}

/// « Joueur 3 » → « 3 », sinon la première lettre. Évite que tout le monde soit « J ».
String playerTag(String name) {
  final match = RegExp(
    r'^joueur\s+(\d+)$',
    caseSensitive: false,
  ).firstMatch(name.trim());
  if (match != null) return match.group(1)!;
  return playerInitial(name);
}

ThemeData buildTheme() {
  const paper = Color(0xFFF3F6FA);
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
    surface: panelInk,
  ).copyWith(
    primary: accent,
    onPrimary: onAccent,
    secondary: accentGold,
    tertiary: const Color(0xFF6AA8FF),
    error: dangerCrit,
    surface: panelInk,
    onSurface: paper,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: ink,
    splashFactory: InkRipple.splashFactory,
    dividerColor: line,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(height: 1.35, color: paper),
      bodySmall: TextStyle(height: 1.3, color: Color(0xFFA7B0C0)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: paper,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: paper,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: paper,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 0,
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        foregroundColor: paper,
        side: const BorderSide(color: line),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: accent.withValues(alpha: 0.2),
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: paper,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface,
      contentTextStyle: const TextStyle(color: paper),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return onAccent;
        return paper.withValues(alpha: 0.8);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accent;
        return const Color(0xFF2A3142);
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF10141C),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: const TextStyle(color: Color(0xFFA7B0C0)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
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
        color: Colors.black.withValues(alpha: 0.45),
        blurRadius: size > 60 ? 12 : 6,
      ),
    ],
  );
}
