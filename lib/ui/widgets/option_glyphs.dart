import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/widgets/repeat_tap.dart';

/// Symbole d’une option. Sombre quand elle ne compte pas, allumé quand elle est en jeu.
enum OptionMarkKind {
  sun,
  moon,
  poison,
  crown,
  initiative,
  tax,
  blessing,
  energy,
  experience,
  treasure,
  storm,
  clue,
  food,
  blood,
  trail,
  gold,
  powerstone,
  rad,
  speed,
  ring,
  signature,
  letter,
}

OptionMarkKind kindForStat(Stat stat) => switch (stat) {
  Stat.poison => OptionMarkKind.poison,
  Stat.energy => OptionMarkKind.energy,
  Stat.experience => OptionMarkKind.experience,
  Stat.treasure => OptionMarkKind.treasure,
  Stat.storm => OptionMarkKind.storm,
  Stat.clue => OptionMarkKind.clue,
  Stat.food => OptionMarkKind.food,
  Stat.blood => OptionMarkKind.blood,
  Stat.trail => OptionMarkKind.trail,
  Stat.gold => OptionMarkKind.gold,
  Stat.powerstone => OptionMarkKind.powerstone,
  Stat.rad => OptionMarkKind.rad,
  Stat.speed => OptionMarkKind.speed,
  Stat.signature => OptionMarkKind.signature,
};

Color markColor(OptionMarkKind kind) => switch (kind) {
  OptionMarkKind.sun => const Color(0xFFFFC56B),
  OptionMarkKind.moon => const Color(0xFFD7E6FF),
  OptionMarkKind.poison => const Color(0xFF8FDB6A),
  OptionMarkKind.crown => const Color(0xFFE2B657),
  OptionMarkKind.tax => const Color(0xFFD4894A),
  OptionMarkKind.treasure => const Color(0xFFF2D24A),
  OptionMarkKind.ring => const Color(0xFFD5D8E0),
  OptionMarkKind.initiative => const Color(0xFFB59BFF),
  OptionMarkKind.blessing => const Color(0xFF3DDCB4),
  OptionMarkKind.energy => const Color(0xFFFF7D9C),
  OptionMarkKind.experience => const Color(0xFF6AA8FF),
  OptionMarkKind.storm => const Color(0xFF8B7CFF),
  OptionMarkKind.rad => const Color(0xFFE4F06A),
  OptionMarkKind.speed => const Color(0xFFFF9A62),
  OptionMarkKind.signature => const Color(0xFFC86BFF),
  OptionMarkKind.clue => const Color(0xFF7ED0C8),
  OptionMarkKind.food => const Color(0xFFE0A15A),
  OptionMarkKind.blood => const Color(0xFFE25B6A),
  OptionMarkKind.trail => const Color(0xFF8FBF6A),
  OptionMarkKind.gold => const Color(0xFFFFC14A),
  OptionMarkKind.powerstone => const Color(0xFF9AA4FF),
  OptionMarkKind.letter => Colors.white,
};

/// Noms sous les logos. Absent : symboles seuls, comme au centre de la table.
class OptionCaption extends InheritedWidget {
  const OptionCaption({required this.names, required super.child});

  final bool names;

  static bool of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<OptionCaption>()?.names ??
        false;
  }

  @override
  bool updateShouldNotify(OptionCaption oldWidget) => names != oldWidget.names;
}

/// Trou laissé au centre, identique quel que soit le nombre de joueurs.
const skyLane = 52.0;

/// Hauteur du bandeau soleil / lune posé entre les joueurs.
double tableSkySlot(bool names) => names ? 68 : skyLane;

/// Nom court sous le symbole. Le dessin porte l’idée, le mot lève le doute.
String? markCaption(OptionMarkKind kind) => switch (kind) {
  OptionMarkKind.sun => 'Jour',
  OptionMarkKind.moon => 'Nuit',
  OptionMarkKind.poison => 'Poison',
  OptionMarkKind.crown => 'Monarque',
  OptionMarkKind.initiative => 'Initiative',
  OptionMarkKind.tax => 'Taxe',
  OptionMarkKind.blessing => 'Cité',
  OptionMarkKind.energy => 'Énergie',
  OptionMarkKind.experience => 'XP',
  OptionMarkKind.treasure => 'Trésor',
  OptionMarkKind.storm => 'Tempête',
  OptionMarkKind.clue => 'Indice',
  OptionMarkKind.food => 'Nourriture',
  OptionMarkKind.blood => 'Sang',
  OptionMarkKind.trail => 'Carte',
  OptionMarkKind.gold => 'Or',
  OptionMarkKind.powerstone => 'Pierre',
  OptionMarkKind.rad => 'Radiation',
  OptionMarkKind.speed => 'Vitesse',
  OptionMarkKind.ring => 'Anneau',
  OptionMarkKind.signature => 'Sort',
  OptionMarkKind.letter => null,
};

String manaSpoken(String key) => switch (key) {
  'W' => 'Mana blanc',
  'U' => 'Mana bleu',
  'B' => 'Mana noir',
  'R' => 'Mana rouge',
  'G' => 'Mana vert',
  'C' => 'Mana incolore',
  _ => 'Mana',
};

/// Disque : le dessin est toujours lisible, la lueur dit qu’il est en jeu.
class OptionMark extends StatelessWidget {
  const OptionMark({
    super.key,
    required this.kind,
    required this.lit,
    this.size = 36,
    this.level,
    this.letter,
    this.glow,
    this.danger = false,
    this.steady = false,
    this.litColor,
    this.idleColor,
    this.dayLight = false,
    this.nightLight = false,
  });

  final OptionMarkKind kind;
  final bool lit;
  final double size;
  final int? level;
  final String? letter;
  final Color? glow;
  final bool danger;

  /// Reste lisible même éteint. Le soleil et la lune sont des boutons, pas un état caché.
  final bool steady;

  /// Couleur quand le symbole est en jeu. Le gris d’attente est [idleColor].
  final Color? litColor;
  final Color? idleColor;

  /// Soleil : champ ambre, rayon clair, halo bas. Même construction que la lune.
  final bool dayLight;

  /// Lune : champ bleu nuit lisible, croissant clair, halo bas.
  final bool nightLight;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? dangerCrit
        : (litColor ?? glow ?? markColor(kind));
    final idle = idleColor ??
        Colors.white.withValues(alpha: steady ? 0.92 : 0.55);
    final ink = lit ? color : idle;
    final sky = dayLight || nightLight;
    final field = dayLight ? const Color(0xFF3A2612) : const Color(0xFF22345C);
    final rim = dayLight ? const Color(0xFFFFD08A) : const Color(0xFF9AAFD6);
    final halo = dayLight ? const Color(0xFF8A5520) : const Color(0xFF31497A);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lit
            ? (sky ? field : color.withValues(alpha: 0.22))
            : const Color(0xFF2A3038),
        border: Border.all(
          color: lit ? color : idle.withValues(alpha: 0.85),
          width: lit ? (sky ? 2.0 : 1.6) : 1.2,
        ),
        boxShadow: !lit
            ? null
            : sky
                ? [
                    BoxShadow(
                      color: rim.withValues(alpha: 0.55),
                      blurRadius: size * 0.2,
                    ),
                    BoxShadow(
                      color: halo.withValues(alpha: 0.9),
                      blurRadius: size * 0.72,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.55),
                      blurRadius: size * 0.34,
                    ),
                  ],
      ),
      child: CustomPaint(
        painter: _GlyphPainter(
          kind: kind,
          color: ink,
          level: level,
          letter: letter,
        ),
      ),
    );
  }
}

/// Compteur ou interrupteur. Le libellé est lu par l’accessibilité, l’écran montre le symbole.
class LitMark extends StatelessWidget {
  const LitMark({
    super.key,
    required this.kind,
    required this.lit,
    required this.label,
    this.danger = false,
    this.value,
    this.level,
    this.letter,
    this.glow,
    this.disc = 36,
    this.steady = false,
    this.showCaption = true,
    this.litColor,
    this.idleColor,
    this.dayLight = false,
    this.nightLight = false,
    this.onTap,
    this.onMinus,
    this.onPlus,
  });

  final OptionMarkKind kind;
  final bool lit;
  final String label;
  final bool danger;
  final int? value;
  final int? level;
  final String? letter;
  final Color? glow;
  final double disc;
  final bool steady;
  final bool showCaption;
  final Color? litColor;
  final Color? idleColor;
  final bool dayLight;
  final bool nightLight;
  final VoidCallback? onTap;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final color = danger ? dangerCrit : (glow ?? markColor(kind));
    final mark = OptionMark(
      kind: kind,
      lit: lit,
      size: disc,
      level: level,
      letter: letter,
      glow: glow,
      danger: danger,
      steady: steady,
      litColor: litColor,
      idleColor: idleColor,
      dayLight: dayLight,
      nightLight: nightLight,
    );
    final caption = showCaption ? markCaption(kind) : null;
    final shown = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        if (caption != null)
          Text(
            caption,
            maxLines: 1,
            style: TextStyle(
              fontSize: 10,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: lit
                  ? (litColor ?? glow ?? markColor(kind))
                  : const Color(0xFF9AA1AB),
            ),
          ),
      ],
    );
    final body = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onMinus != null)
          RepeatTap(
            onTick: onMinus!,
            child: const SizedBox(
              width: 28,
              height: 36,
              child: Icon(Icons.remove, size: 18),
            ),
          ),
        shown,
        if (value != null) ...[
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: lit ? color : Colors.white54,
            ),
          ),
        ],
        if (onPlus != null)
          RepeatTap(
            onTick: onPlus!,
            child: const SizedBox(
              width: 28,
              height: 36,
              child: Icon(Icons.add, size: 18),
            ),
          ),
      ],
    );
    final tappable = onTap == null
        ? body
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: body,
              ),
            ),
          );
    return Semantics(
      button: onTap != null || onPlus != null,
      selected: lit,
      label: label,
      child: ExcludeSemantics(child: tappable),
    );
  }
}

/// Soleil et lune. L’astre allumé est l’état de la partie. Les deux sombres : on ne le suit pas.
class DayNightControl extends StatelessWidget {
  const DayNightControl({
    super.key,
    required this.state,
    required this.onSun,
    required this.onMoon,
    this.wide = false,
    this.showCaption = false,
    this.disc,
  });

  final DayState state;
  final VoidCallback onSun;
  final VoidCallback onMoon;
  final bool wide;
  final bool showCaption;
  final double? disc;

  @override
  Widget build(BuildContext context) {
    final mark = disc ?? (wide ? 34.0 : 30.0);
    const idle = Color(0xFF9AA1AB);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LitMark(
          key: const ValueKey('sky-sun'),
          kind: OptionMarkKind.sun,
          lit: state == DayState.day,
          label: 'Jour',
          disc: mark,
          showCaption: showCaption,
          litColor: const Color(0xFFFFE3B0),
          idleColor: idle,
          dayLight: true,
          onTap: onSun,
        ),
        SizedBox(width: showCaption ? 10 : 8),
        LitMark(
          key: const ValueKey('sky-moon'),
          kind: OptionMarkKind.moon,
          lit: state == DayState.night,
          label: 'Nuit',
          disc: mark,
          showCaption: showCaption,
          litColor: const Color(0xFFD7E4FF),
          idleColor: idle,
          nightLight: true,
          onTap: onMoon,
        ),
      ],
    );
  }
}

/// Soleil et lune incrustés entre les joueurs. Le mot n’apparaît que si on le demande.
class TableSky extends StatelessWidget {
  const TableSky({
    super.key,
    required this.state,
    required this.onSun,
    required this.onMoon,
    this.names = false,
    this.disc = 30,
  });

  final DayState state;
  final VoidCallback onSun;
  final VoidCallback onMoon;
  final bool names;
  final double disc;

  @override
  Widget build(BuildContext context) {
    final tone = switch (state) {
      DayState.day => const Color(0xF02C1E10),
      DayState.night => const Color(0xF0141E38),
      DayState.unset => const Color(0xF0141820),
    };
    final edge = switch (state) {
      DayState.day => const Color(0xCCF0D09A),
      DayState.night => const Color(0xCCB7C9EE),
      DayState.unset => const Color(0x449AA1AB),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: edge, width: state == DayState.unset ? 1 : 1.4),
        boxShadow: [
          if (state == DayState.day)
            const BoxShadow(
              color: Color(0x778A5A28),
              blurRadius: 18,
            ),
          if (state == DayState.night)
            const BoxShadow(
              color: Color(0x773A5688),
              blurRadius: 18,
            ),
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, names ? 2 : 4, 12, names ? 2 : 4),
        child: DayNightControl(
          state: state,
          onSun: onSun,
          onMoon: onMoon,
          showCaption: names,
          disc: disc,
        ),
      ),
    );
  }
}

/// État jour / nuit lu par chaque joueur, quelle que soit la disposition.
class TableDay extends InheritedWidget {
  const TableDay({super.key, required this.state, required super.child});

  final DayState state;

  static DayState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TableDay>();
    return scope?.state ?? DayState.unset;
  }

  @override
  bool updateShouldNotify(TableDay oldWidget) => state != oldWidget.state;
}

/// Voile d’ambiance dans le rectangle du joueur.
/// Il teinte ce qui est déjà peint. Il ne remplace pas le plateau,
/// et les animations sont dessinées au-dessus, sur leur propre calque.
class SkyVeil extends StatelessWidget {
  const SkyVeil({super.key, required this.state, this.tint = const Color(0xFF000000)});

  final DayState state;
  final Color tint;

  static const dayTint = Color(0x1CFFF6DE);

  /// Part de lumière gardée la nuit, pour toutes les couleurs.
  /// Le violet en multiplication décale le plateau : on assombrit ce qui est déjà peint.
  static const warmNight = 0.28;

  static Color nightFor(Color tint) => const Color(0x00000000);

  static ColorFilter warmNightFilter(double scale) {
    return ColorFilter.matrix(<double>[
      scale, 0, 0, 0, 0,
      0, scale, 0, 0, 0,
      0, 0, scale, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }

  static BlendMode modeFor(DayState state) => switch (state) {
    DayState.night => BlendMode.multiply,
    DayState.day => BlendMode.srcOver,
    DayState.unset => BlendMode.srcOver,
  };

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      DayState.night => nightFor(tint),
      DayState.day => dayTint,
      DayState.unset => const Color(0x00000000),
    };
    final mode = modeFor(state);
    return IgnorePointer(
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        builder: (context, value, _) {
          return CustomPaint(
            key: const ValueKey('sky-veil'),
            painter: SkyWash(color: value ?? color, mode: mode),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class SkyWash extends CustomPainter {
  const SkyWash({required this.color, required this.mode});

  final Color color;
  final BlendMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || color.a == 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = color
        ..blendMode = mode,
    );
  }

  @override
  bool shouldRepaint(SkyWash oldDelegate) {
    return oldDelegate.color != color || oldDelegate.mode != mode;
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({
    required this.kind,
    required this.color,
    this.level,
    this.letter,
  });

  final OptionMarkKind kind;
  final Color color;
  final int? level;
  final String? letter;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case OptionMarkKind.sun:
        _sun(canvas, size);
      case OptionMarkKind.moon:
        _moon(canvas, size);
      case OptionMarkKind.poison:
        _skull(canvas, size);
      case OptionMarkKind.crown:
        _crown(canvas, size);
      case OptionMarkKind.initiative:
        _dungeon(canvas, size);
      case OptionMarkKind.tax:
        _purse(canvas, size);
      case OptionMarkKind.blessing:
        _city(canvas, size);
      case OptionMarkKind.energy:
        _bolt(canvas, size);
      case OptionMarkKind.experience:
        _bars(canvas, size);
      case OptionMarkKind.treasure:
        _coin(canvas, size);
      case OptionMarkKind.clue:
      case OptionMarkKind.food:
      case OptionMarkKind.blood:
      case OptionMarkKind.trail:
      case OptionMarkKind.gold:
      case OptionMarkKind.powerstone:
        _token(canvas, size);
      case OptionMarkKind.storm:
        _cloud(canvas, size);
      case OptionMarkKind.rad:
        _pulse(canvas, size);
      case OptionMarkKind.speed:
        _chevrons(canvas, size);
      case OptionMarkKind.ring:
        _ring(canvas, size);
      case OptionMarkKind.signature:
        _scroll(canvas, size);
      case OptionMarkKind.letter:
        _letter(canvas, size);
    }
  }

  Paint get _fill => Paint()..color = color;

  Paint get _stroke => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _sun(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      size.width * 0.20,
      Paint()..color = color.withValues(alpha: 0.28),
    );
    canvas.drawCircle(c, size.width * 0.12, _fill);
    final ray = _stroke..strokeWidth = math.max(1.8, size.width * 0.075);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        c + dir * size.width * 0.24,
        c + dir * size.width * 0.40,
        ray,
      );
    }
  }

  void _moon(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.46, size.height * 0.50);
    final radius = size.width * 0.27;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withValues(alpha: 0.28),
    );
    final body = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    final cut = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width * 0.66, size.height * 0.36),
          radius: size.width * 0.20,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, body, cut),
      _fill,
    );
  }

  void _skull(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final neck = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.40, h * 0.22, w * 0.20, h * 0.10),
      const Radius.circular(1),
    );
    canvas.drawRRect(neck, _fill);
    canvas.drawCircle(Offset(w * 0.50, h * 0.16), w * 0.10, _fill);
    final eye = Paint()..color = const Color(0xFF140E08);
    canvas.drawCircle(Offset(w * 0.46, h * 0.15), w * 0.018, eye);
    canvas.drawCircle(Offset(w * 0.54, h * 0.15), w * 0.018, eye);
    final bottle = Path()
      ..moveTo(w * 0.38, h * 0.34)
      ..lineTo(w * 0.26, h * 0.50)
      ..quadraticBezierTo(w * 0.18, h * 0.88, w * 0.50, h * 0.90)
      ..quadraticBezierTo(w * 0.82, h * 0.88, w * 0.74, h * 0.50)
      ..lineTo(w * 0.62, h * 0.34)
      ..close();
    canvas.drawPath(
      bottle,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.8, w * 0.08)
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(w * 0.50, h * 0.58), w * 0.11, _fill);
    canvas.drawCircle(Offset(w * 0.46, h * 0.56), w * 0.02, eye);
    canvas.drawCircle(Offset(w * 0.54, h * 0.56), w * 0.02, eye);
  }

  void _crown(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final band = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.2, w * 0.09)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(w * 0.10, h * 0.72)
      ..lineTo(w * 0.10, h * 0.46)
      ..lineTo(w * 0.28, h * 0.58)
      ..lineTo(w * 0.36, h * 0.30)
      ..lineTo(w * 0.50, h * 0.52)
      ..lineTo(w * 0.64, h * 0.24)
      ..lineTo(w * 0.72, h * 0.52)
      ..lineTo(w * 0.86, h * 0.30)
      ..lineTo(w * 0.90, h * 0.58)
      ..lineTo(w * 0.90, h * 0.72);
    canvas.drawPath(path, band);
    canvas.drawLine(
      Offset(w * 0.10, h * 0.78),
      Offset(w * 0.90, h * 0.78),
      band,
    );
    for (final x in [0.36, 0.64, 0.86]) {
      canvas.drawCircle(Offset(w * x, h * (x == 0.64 ? 0.22 : 0.28)), w * 0.055, _fill);
    }
  }

  void _dungeon(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.16, h * 0.10, w * 0.16, h * 0.14), _fill);
    canvas.drawRect(Rect.fromLTWH(w * 0.42, h * 0.06, w * 0.16, h * 0.18), _fill);
    canvas.drawRect(Rect.fromLTWH(w * 0.68, h * 0.10, w * 0.16, h * 0.14), _fill);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.22, w * 0.68, h * 0.26),
        Radius.circular(w * 0.04),
      ),
      _fill,
    );
    final arrow = Path()
      ..moveTo(w * 0.44, h * 0.42)
      ..lineTo(w * 0.56, h * 0.42)
      ..lineTo(w * 0.56, h * 0.58)
      ..lineTo(w * 0.78, h * 0.58)
      ..lineTo(w * 0.50, h * 0.94)
      ..lineTo(w * 0.22, h * 0.58)
      ..lineTo(w * 0.44, h * 0.58)
      ..close();
    canvas.drawPath(arrow, _fill);
  }

  void _purse(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bag = Path()
      ..moveTo(w * 0.38, h * 0.44)
      ..cubicTo(w * 0.16, h * 0.44, w * 0.12, h * 0.70, w * 0.24, h * 0.82)
      ..quadraticBezierTo(w * 0.36, h * 0.94, w * 0.50, h * 0.94)
      ..quadraticBezierTo(w * 0.64, h * 0.94, w * 0.76, h * 0.82)
      ..cubicTo(w * 0.88, h * 0.70, w * 0.84, h * 0.44, w * 0.62, h * 0.44)
      ..close();
    canvas.drawPath(bag, _fill);
    canvas.drawCircle(Offset(w * 0.50, h * 0.42), w * 0.05, _fill);
    final dollar = TextPainter(
      text: TextSpan(
        text: r'$',
        style: TextStyle(
          color: const Color(0xFF140E08),
          fontSize: w * 0.36,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dollar.paint(
      canvas,
      Offset((w - dollar.width) / 2, h * 0.56),
    );
    final trident = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.7, w * 0.075)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(Offset(w * 0.50, h * 0.42), Offset(w * 0.50, h * 0.04), trident);
    canvas.drawLine(Offset(w * 0.32, h * 0.18), Offset(w * 0.68, h * 0.18), trident);
    canvas.drawLine(Offset(w * 0.32, h * 0.18), Offset(w * 0.27, h * 0.08), trident);
    canvas.drawLine(Offset(w * 0.68, h * 0.18), Offset(w * 0.73, h * 0.08), trident);
  }

  void _city(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    void house(double left, double roof, double width, double wallTop) {
      final roofPath = Path()
        ..moveTo(left, wallTop)
        ..lineTo(left + width / 2, roof)
        ..lineTo(left + width, wallTop)
        ..close();
      canvas.drawPath(roofPath, _fill);
      canvas.drawRect(
        Rect.fromLTWH(left + width * 0.08, wallTop, width * 0.84, h * 0.78 - wallTop),
        _fill,
      );
    }

    house(w * 0.08, h * 0.40, w * 0.24, h * 0.52);
    house(w * 0.36, h * 0.28, w * 0.28, h * 0.46);
    house(w * 0.68, h * 0.36, w * 0.24, h * 0.50);
    final rise = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, w * 0.07)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final arrow = Path()
      ..moveTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.38, h * 0.20)
      ..moveTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.62, h * 0.20)
      ..moveTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.50, h * 0.24);
    canvas.drawPath(arrow, rise);
  }

  void _bolt(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.58, h * 0.16)
      ..lineTo(w * 0.28, h * 0.54)
      ..lineTo(w * 0.48, h * 0.54)
      ..lineTo(w * 0.40, h * 0.84)
      ..lineTo(w * 0.74, h * 0.42)
      ..lineTo(w * 0.52, h * 0.42)
      ..close();
    canvas.drawPath(path, _fill);
  }

  void _bars(Canvas canvas, Size size) {
    final paint = _fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.20, size.height * 0.58, size.width * 0.14, size.height * 0.20),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.42, size.height * 0.42, size.width * 0.14, size.height * 0.36),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.64, size.height * 0.26, size.width * 0.14, size.height * 0.52),
        const Radius.circular(1),
      ),
      paint,
    );
  }

  void _coin(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.16, h * 0.18, w * 0.68, h * 0.40),
      math.pi,
      math.pi,
      true,
      _fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.40, w * 0.68, h * 0.40),
        Radius.circular(w * 0.06),
      ),
      _fill,
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.58),
      w * 0.07,
      Paint()..color = const Color(0xFF140E08),
    );
  }

  void _token(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w * 0.5, h * 0.5);
    switch (kind) {
      case OptionMarkKind.clue:
        canvas.drawCircle(Offset(w * 0.42, h * 0.40), w * 0.16, _stroke);
        canvas.drawLine(Offset(w * 0.54, h * 0.52), Offset(w * 0.72, h * 0.72), _stroke);
      case OptionMarkKind.food:
        canvas.drawCircle(c, w * 0.22, _fill);
        canvas.drawCircle(
          Offset(w * 0.66, h * 0.34),
          w * 0.10,
          Paint()..color = const Color(0xFF140E08),
        );
      case OptionMarkKind.blood:
        final drop = Path()
          ..moveTo(w * 0.50, h * 0.18)
          ..quadraticBezierTo(w * 0.82, h * 0.55, w * 0.50, h * 0.82)
          ..quadraticBezierTo(w * 0.18, h * 0.55, w * 0.50, h * 0.18);
        canvas.drawPath(drop, _fill);
      case OptionMarkKind.trail:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.22, h * 0.28, w * 0.56, h * 0.40),
            Radius.circular(w * 0.04),
          ),
          _stroke,
        );
        canvas.drawLine(Offset(w * 0.32, h * 0.42), Offset(w * 0.68, h * 0.42), _stroke);
        canvas.drawLine(Offset(w * 0.32, h * 0.54), Offset(w * 0.58, h * 0.54), _stroke);
      case OptionMarkKind.gold:
        canvas.drawCircle(c, w * 0.22, _stroke);
        canvas.drawCircle(c, w * 0.08, _fill);
      case OptionMarkKind.powerstone:
        final hex = Path();
        for (var i = 0; i < 6; i++) {
          final angle = -math.pi / 2 + i * math.pi / 3;
          final point = Offset(c.dx + math.cos(angle) * w * 0.24, c.dy + math.sin(angle) * h * 0.24);
          if (i == 0) {
            hex.moveTo(point.dx, point.dy);
          } else {
            hex.lineTo(point.dx, point.dy);
          }
        }
        hex.close();
        canvas.drawPath(hex, _stroke);
      default:
        break;
    }
  }

  void _cloud(Canvas canvas, Size size) {
    final paint = _stroke;
    canvas.drawCircle(Offset(size.width * 0.38, size.height * 0.42), size.width * 0.12, paint);
    canvas.drawCircle(Offset(size.width * 0.54, size.height * 0.36), size.width * 0.14, paint);
    canvas.drawCircle(Offset(size.width * 0.66, size.height * 0.46), size.width * 0.10, paint);
    canvas.save();
    canvas.translate(size.width * 0.34, size.height * 0.46);
    _bolt(canvas, Size(size.width * 0.40, size.height * 0.40));
    canvas.restore();
  }

  void _pulse(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.saveLayer(Offset.zero & size, Paint());
    for (var i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / 3;
      final blade = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: size.width * 0.40),
          angle - 0.42,
          0.84,
          false,
        )
        ..close();
      canvas.drawPath(blade, _fill);
    }
    canvas.drawCircle(
      center,
      size.width * 0.11,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
    canvas.drawCircle(center, size.width * 0.045, _fill);
  }

  void _chevrons(Canvas canvas, Size size) {
    final lit = (level ?? 0).clamp(0, 4);
    for (var i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = i < lit ? color : color.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round;
      final x = size.width * (0.18 + i * 0.18);
      final path = Path()
        ..moveTo(x, size.height * 0.32)
        ..lineTo(x + size.width * 0.10, size.height * 0.50)
        ..lineTo(x, size.height * 0.68);
      canvas.drawPath(path, paint);
    }
  }

  void _ring(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.30;
    final lit = (level ?? 0).clamp(0, 4);
    const gap = 0.42;
    final sweep = math.pi / 2 - gap;
    for (var i = 0; i < 4; i++) {
      final filled = i < lit;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2 + i * math.pi / 2 + gap / 2,
        sweep,
        false,
        Paint()
          ..color = filled ? color : Colors.white.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = filled ? size.width * 0.16 : size.width * 0.07
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _scroll(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.26, size.height * 0.22, size.width * 0.40, size.height * 0.52),
      const Radius.circular(2),
    );
    canvas.drawRRect(rect, _stroke);
    canvas.drawLine(
      Offset(size.width * 0.34, size.height * 0.36),
      Offset(size.width * 0.58, size.height * 0.36),
      _stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.34, size.height * 0.48),
      Offset(size.width * 0.54, size.height * 0.48),
      _stroke,
    );
  }

  void _letter(Canvas canvas, Size size) {
    final text = (letter == null || letter!.isEmpty) ? '?' : letter!;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: size.width * 0.42,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        (size.width - painter.width) / 2,
        (size.height - painter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.color != color ||
        oldDelegate.level != level ||
        oldDelegate.letter != letter;
  }
}
