import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/widgets/vfx_film.dart';

enum FinaleCause { life, poison, commander, leave }

FinaleCause finaleCause({
  required bool conceded,
  required bool commander,
  required bool poison,
}) {
  if (conceded) return FinaleCause.leave;
  if (commander) return FinaleCause.commander;
  if (poison) return FinaleCause.poison;
  return FinaleCause.life;
}

String fillEpitaph(
  String template, {
  required String name,
  required String winner,
  required String loss,
  required String cause,
}) {
  return template
      .replaceAll('{nom}', name)
      .replaceAll('{vainqueur}', winner)
      .replaceAll('{perte}', loss)
      .replaceAll('{cause}', cause);
}

class FinaleScope extends InheritedWidget {
  const FinaleScope({
    super.key,
    required this.style,
    required this.saltLines,
    this.epitaphLife = '',
    this.epitaphPoison = '',
    this.epitaphCommander = '',
    this.epitaphLeave = '',
    this.epitaphWin = '',
    this.onArchiveWin,
    required super.child,
  });

  final FinaleStyle style;
  final List<String> saltLines;
  final String epitaphLife;
  final String epitaphPoison;
  final String epitaphCommander;
  final String epitaphLeave;
  final String epitaphWin;
  final Future<void> Function()? onArchiveWin;

  static Future<void> Function()? archiveOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FinaleScope>()
        ?.onArchiveWin;
  }

  static FinaleStyle styleOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FinaleScope>()?.style ??
        FinaleStyle.mythic;
  }

  static String? epitaphFor(
    BuildContext context, {
    required FinaleCause cause,
    required String playerId,
    required String name,
    required String winner,
    required String loss,
    required String reason,
  }) {
    final scope = context.dependOnInheritedWidgetOfExactType<FinaleScope>();
    if (scope == null || scope.style != FinaleStyle.lotus) return null;
    var template = switch (cause) {
      FinaleCause.life => scope.epitaphLife,
      FinaleCause.poison => scope.epitaphPoison,
      FinaleCause.commander => scope.epitaphCommander,
      FinaleCause.leave => scope.epitaphLeave,
    }.trim();
    if (template.isEmpty && cause == FinaleCause.life) {
      final lines = [
        for (final line in scope.saltLines)
          if (line.trim().isNotEmpty) line.trim(),
      ];
      if (lines.isEmpty) return null;
      var sum = 0;
      for (final unit in playerId.codeUnits) {
        sum += unit;
      }
      template = lines[sum % lines.length];
    }
    if (template.isEmpty) return null;
    return fillEpitaph(
      template,
      name: name,
      winner: winner,
      loss: loss,
      cause: reason,
    );
  }

  static String? epitaphVictory(
    BuildContext context, {
    required String name,
    required String winner,
  }) {
    final scope = context.dependOnInheritedWidgetOfExactType<FinaleScope>();
    if (scope == null || scope.style != FinaleStyle.lotus) return null;
    final template = scope.epitaphWin.trim();
    if (template.isEmpty) return null;
    return fillEpitaph(
      template,
      name: name,
      winner: winner,
      loss: '',
      cause: 'victoire',
    );
  }

  @override
  bool updateShouldNotify(FinaleScope oldWidget) {
    return oldWidget.style != style ||
        oldWidget.saltLines != saltLines ||
        oldWidget.epitaphLife != epitaphLife ||
        oldWidget.epitaphPoison != epitaphPoison ||
        oldWidget.epitaphCommander != epitaphCommander ||
        oldWidget.epitaphLeave != epitaphLeave ||
        oldWidget.epitaphWin != epitaphWin;
  }
}

const sacreIvory = Color(0xFFFFF6EA);
const sacreEmber = Color(0xFFFF6A3C);
const sacreCrimson = Color(0xFFC8102E);
const sacreWine = Color(0xFF3A0A12);
const sacreGoldLight = Color(0xFFFFF8E8);
const sacreGoldDeep = Color(0xFF6E4A16);

const epitaphPaper = Color(0xFFF6EFE6);
const epitaphInk = Color(0xFF100E0C);
const epitaphWarm = Color(0xFFE7D7C3);

const chiselSteel = Color(0xFFE7ECF2);
const chiselGraphite = Color(0xFF16181C);
const chiselEdge = Color(0xFF9AA3B0);
const chiselGroove = Color(0xFF050608);

String castToneLabel(CastTone tone) => switch (tone) {
  CastTone.aucune => 'Sans animation',
  CastTone.standard => 'Standard',
  CastTone.faille => 'Faille',
  CastTone.sceau => 'Sceau',
  CastTone.pilier => 'Pilier',
  CastTone.nova => 'Nova',
  CastTone.blanc => 'Blanc',
  CastTone.bleu => 'Bleu',
  CastTone.noir => 'Noir',
  CastTone.rouge => 'Rouge',
  CastTone.vert => 'Vert',
  CastTone.teinte => 'Mes couleurs',
};

String castToneHint(CastTone tone) => switch (tone) {
  CastTone.aucune => 'Le rectangle seul. Aucun effet.',
  CastTone.standard => 'Cendre grise, et les cinq couleurs en pentagone.',
  CastTone.faille => 'Sombre, avec des éclairs.',
  CastTone.sceau => 'Un cercle gravé, gris.',
  CastTone.nova => 'Cercles jaunes, une marque dangereuse.',
  CastTone.pilier => 'Des colonnes qui montent.',
  CastTone.blanc => 'Lumière, soleil, coup saint.',
  CastTone.bleu =>
    'Un cercle bleu aux bords blancs, une brume, des gouttes qui grossissent.',
  CastTone.noir => 'Brume noire, éclairs violets, crânes sombres.',
  CastTone.rouge => 'Flammes et braises.',
  CastTone.vert => 'Une arche de lianes, des ronces hautes, du pollen vert.',
  CastTone.teinte => 'Les couleurs du jeu de ce joueur.',
};

/// Style de fin qui accompagne l’animation choisie.
FinaleStyle finaleForCast(CastTone cast) => switch (cast) {
  CastTone.aucune => FinaleStyle.still,
  CastTone.blanc => FinaleStyle.blanc,
  CastTone.bleu => FinaleStyle.bleu,
  CastTone.noir => FinaleStyle.noir,
  CastTone.rouge => FinaleStyle.rouge,
  CastTone.vert => FinaleStyle.vert,
  CastTone.teinte => FinaleStyle.teinte,
  CastTone.standard ||
  CastTone.faille ||
  CastTone.sceau ||
  CastTone.nova ||
  CastTone.pilier => FinaleStyle.mythic,
};

/// L’animation commune, ou null si les joueurs n’ont pas la même.
CastTone? sharedCast(Iterable<Player> players) {
  CastTone? tone;
  for (final player in players) {
    if (tone == null) {
      tone = player.cast;
    } else if (player.cast != tone) {
      return null;
    }
  }
  return tone;
}

String finaleStyleLabel(FinaleStyle style) => switch (style) {
  FinaleStyle.mythic => 'Sacre',
  FinaleStyle.lotus => 'Épitaphe',
  FinaleStyle.carbon => 'Ciselure',
  FinaleStyle.arena => 'Arène',
  FinaleStyle.seal => 'Sceau',
  FinaleStyle.lean => 'Sobre',
  FinaleStyle.still => 'Aucune',
  FinaleStyle.blanc => 'Blanc',
  FinaleStyle.noir => 'Noir',
  FinaleStyle.bleu => 'Bleu',
  FinaleStyle.vert => 'Vert',
  FinaleStyle.rouge => 'Rouge',
  FinaleStyle.teinte => 'Teintes',
};

String finaleStyleHint(FinaleStyle style) => switch (style) {
  FinaleStyle.mythic =>
    'Le danger couve, le coup traverse, la chute s’inscrit, l’or couronne.',
  FinaleStyle.lotus =>
    'Une phrase par cause. {nom}, {vainqueur}, {perte}, {cause}.',
  FinaleStyle.carbon =>
    'Trois traits gravés sur le cadran, nets, puis ils restent.',
  FinaleStyle.arena =>
    'Un impact court sur le chiffre, sec et lisible.',
  FinaleStyle.seal => 'Un cercle se ferme sur le siège, puis reste.',
  FinaleStyle.lean => 'Gestes très courts. Peu de mouvement, peu d’énergie.',
  FinaleStyle.still => 'Aucun mouvement. Seulement les messages.',
  FinaleStyle.blanc => 'Lumière claire. Un cercle doré, puis un soleil.',
  FinaleStyle.noir => 'Brume noire, éclairs violets, crânes sombres.',
  FinaleStyle.bleu => 'Un cercle bleu, une brume, des gouttes.',
  FinaleStyle.vert => 'Lianes, ronces et pollen.',
  FinaleStyle.rouge => 'Flammes. Elles grandissent avec les blessures.',
  FinaleStyle.teinte =>
    'Les couleurs du joueur. Jamais deux fois le même effet d’affilée.',
};

TextStyle defeatHeadlineStyle(FinaleStyle style) => switch (style) {
  FinaleStyle.mythic => const TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.6,
    color: sacreIvory,
    shadows: [
      Shadow(color: sacreWine, offset: Offset(0, 3)),
      Shadow(color: Color(0xFF8E1020), offset: Offset(0, 1)),
      Shadow(color: sacreEmber, blurRadius: 16),
    ],
  ),
  FinaleStyle.lotus => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.15,
    color: epitaphPaper,
    shadows: [
      Shadow(color: Color(0xE6000000), offset: Offset(0, 2), blurRadius: 8),
    ],
  ),
  FinaleStyle.carbon => const TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.2,
    color: chiselSteel,
    shadows: [
      Shadow(color: Color(0xFF000000), offset: Offset(0, 1)),
      Shadow(color: Color(0x66000000), offset: Offset(1, 2)),
    ],
  ),
  FinaleStyle.arena => const TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.8,
    color: Color(0xFFFFF7F4),
    shadows: [
      Shadow(color: Color(0xFF5A1020), offset: Offset(0, 2)),
      Shadow(color: Color(0xFFFF4D3A), blurRadius: 10),
    ],
  ),
  FinaleStyle.seal => const TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.8,
    color: Color(0xFFFFF6E8),
    shadows: [
      Shadow(color: Color(0xFF3A2410), offset: Offset(0, 2), blurRadius: 6),
    ],
  ),
  FinaleStyle.lean => const TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
    color: Color(0xFFF2F4F7),
    shadows: [
      Shadow(color: Color(0xCC000000), offset: Offset(0, 1), blurRadius: 4),
    ],
  ),
  FinaleStyle.still => const TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
    color: Color(0xFFF4F1EA),
  ),
  FinaleStyle.noir => const TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
    color: Color(0xFFE4D4F2),
    shadows: [
      Shadow(color: Color(0xFF120810), offset: Offset(0, 2), blurRadius: 8),
    ],
  ),
  FinaleStyle.blanc ||
  FinaleStyle.bleu ||
  FinaleStyle.vert ||
  FinaleStyle.rouge ||
  FinaleStyle.teinte => const TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.6,
    color: Color(0xFFFFF6EA),
    shadows: [
      Shadow(color: Color(0xCC1A1208), offset: Offset(0, 2), blurRadius: 8),
    ],
  ),
};

TextStyle defeatDetailStyle(FinaleStyle style) {
  final color = switch (style) {
    FinaleStyle.mythic => const Color(0xFFFFD0C8),
    FinaleStyle.lotus => const Color(0xFFCBBBA8),
    FinaleStyle.carbon => chiselEdge,
    FinaleStyle.arena => const Color(0xFFFFD5CC),
    FinaleStyle.seal => const Color(0xFFE7D3A4),
    _ => const Color(0xFFD5DAE2),
  };
  return TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 14,
    height: 1.2,
    color: color,
  );
}

double _dpr() => PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1;

double _snap(double value) {
  final dpr = _dpr();
  return (value * dpr).round() / dpr;
}

double _hairline() => 1 / _dpr();

Offset _snapPoint(Offset point) => Offset(_snap(point.dx), _snap(point.dy));

void _blade(
  Canvas canvas,
  Offset a,
  Offset b, {
  required double width,
  required Color color,
  required double alpha,
  double blur = 0,
}) {
  if (alpha <= 0.01) return;
  final paint = Paint()
    ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
    ..strokeWidth = width
    ..strokeCap = StrokeCap.butt
    ..isAntiAlias = true;
  if (blur > 0) {
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
  }
  canvas.drawLine(a, b, paint);
}

/// Voile, onde de choc et trait de coup. Le trait traverse le siège puis s’efface.
class DefeatVeilPainter extends CustomPainter {
  const DefeatVeilPainter({
    required this.veil,
    required this.flash,
    required this.slash,
    this.cause = FinaleCause.life,
  });

  final double veil;
  final double flash;
  final double slash;
  final FinaleCause cause;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final frame = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    canvas.save();
    canvas.clipRRect(frame);
    if (cause == FinaleCause.poison) {
      _poisonFall(canvas, rect, veil);
      canvas.restore();
      return;
    }
    if (cause == FinaleCause.commander) {
      _commanderFall(canvas, rect, veil);
      canvas.restore();
      return;
    }
    if (cause == FinaleCause.leave) {
      _foldFall(canvas, rect, veil);
      canvas.restore();
      return;
    }

    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFF2A0610).withValues(alpha: 0.94 * veil),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.85,
          colors: [
            sacreCrimson.withValues(alpha: 0.55 * veil),
            const Color(0xFF4A0A16).withValues(alpha: 0.2 * veil),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1],
        ).createShader(rect),
    );

    if (flash > 0.04) {
      canvas.drawRect(
        rect,
        Paint()..color = sacreIvory.withValues(alpha: 0.28 * flash),
      );
    }

    final ringT = Curves.easeOut.transform(slash.clamp(0.0, 1.0));
    final ring = frame.deflate(6 + (1 - ringT) * 10);
    canvas.drawRRect(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = sacreGoldLight.withValues(alpha: 0.92 * ringT),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(DefeatVeilPainter oldDelegate) {
    return oldDelegate.veil != veil ||
        oldDelegate.flash != flash ||
        oldDelegate.slash != slash ||
        oldDelegate.cause != cause;
  }
}

void _poisonFall(Canvas canvas, Rect rect, double veil) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1E4A34).withValues(alpha: 0.55 * veil),
          const Color(0xFF07140E).withValues(alpha: 0.94 * veil),
        ],
      ).createShader(rect),
  );
}

void _commanderFall(Canvas canvas, Rect rect, double veil) {
  canvas.drawRect(
    rect,
    Paint()..color = const Color(0xFF1A1208).withValues(alpha: 0.94 * veil),
  );
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        radius: 0.8,
        colors: [
          accentGold.withValues(alpha: 0.42 * veil),
          Colors.transparent,
        ],
      ).createShader(rect),
  );
  final frame = RRect.fromRectAndRadius(rect.deflate(8), const Radius.circular(16));
  canvas.drawRRect(
    frame,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = accentGold.withValues(alpha: 0.9 * veil),
  );
}

void _foldFall(Canvas canvas, Rect rect, double veil) {
  final h = rect.height * 0.36 * Curves.easeInOut.transform(veil.clamp(0.0, 1.0));
  final paint = Paint()..color = const Color(0xFF07080C).withValues(alpha: 0.92);
  canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, h), paint);
  canvas.drawRect(
    Rect.fromLTWH(rect.left, rect.bottom - h, rect.width, h),
    paint,
  );
}

/// Trait clair qui traverse le rectangle, comme un coup reçu.
void _slash(
  Canvas canvas,
  Rect rect,
  double slash,
  Color core,
  Color edge, {
  double span = 1,
}) {
  if (slash <= 0.02 || slash >= 0.98 || rect.longestSide < 8) return;
  final fade = slash < 0.78 ? 1.0 : (1 - slash) / 0.22;
  final travel = Curves.easeOut.transform(slash.clamp(0.0, 1.0));
  final diag = Offset(rect.width, rect.height);
  final len = diag.distance;
  final dir = diag / len;
  final reach = span.clamp(0.2, 1.0);
  final center = Offset(rect.left, rect.top) + diag * (-0.08 + 1.16 * travel);
  final half = len * (0.16 + 0.49 * reach);
  final a = center - dir * half;
  final b = center + dir * half;
  _blade(
    canvas,
    a.translate(2, 3),
    b.translate(2, 3),
    width: 3 + 4 * reach,
    color: sacreWine,
    alpha: 0.34 * fade,
    blur: 2,
  );
  _blade(
    canvas,
    a,
    b,
    width: 2 + 3 * reach,
    color: edge,
    alpha: 0.38 * fade,
    blur: 1.2,
  );
  _blade(
    canvas,
    a,
    b,
    width: 1.05 + 0.7 * reach,
    color: core,
    alpha: 0.96 * fade,
  );
}

/// Halo doré, double anneau et étincelles au moment de la victoire.
class WinnerAuraPainter extends CustomPainter {
  const WinnerAuraPainter({required this.pulse, required this.burst});

  final double pulse;
  final double burst;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final frame = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    canvas.save();
    canvas.clipRRect(frame);

    final glow = pulse.clamp(0.0, 1.0);
    canvas.drawRRect(
      frame.deflate(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = sacreGoldLight.withValues(alpha: 0.9 * glow),
    );
    final corners = <Offset>[
      rect.topLeft + const Offset(16, 16),
      rect.topRight + const Offset(-16, 16),
      rect.bottomLeft + const Offset(16, -16),
      rect.bottomRight + const Offset(-16, -16),
    ];
    for (var i = 0; i < corners.length; i++) {
      final twinkle = 0.45 + 0.55 * ((math.sin(glow * math.pi * 2 + i) + 1) / 2);
      _goldStar(canvas, corners[i], 5, twinkle * glow);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WinnerAuraPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.burst != burst;
  }
}

/// Balayage doré sur le bandeau, sans agrandir sa place.
class VictorySweepPainter extends CustomPainter {
  const VictorySweepPainter({required this.travel});

  final double travel;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final band = Rect.fromLTWH(0, 0, size.width, math.min(32, size.height * 0.45));
    final shaderRect = Rect.fromLTWH(
      -size.width + travel * size.width * 2,
      0,
      size.width,
      band.height,
    );
    canvas.drawRect(
      band,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Colors.transparent,
            Color(0x446E4A16),
            Color(0x22FFF8E8),
            Color(0x336E4A16),
            Colors.transparent,
          ],
          stops: [0.34, 0.46, 0.5, 0.56, 0.7],
        ).createShader(shaderRect),
    );
    final edge = Rect.fromLTWH(
      shaderRect.left + shaderRect.width * 0.49,
      0,
      math.max(1, _hairline() * 2),
      band.height,
    );
    final glint = edge.intersect(band);
    if (glint.width > 0 && glint.height > 0) {
      canvas.drawRect(
        glint,
        Paint()..color = sacreGoldLight.withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(VictorySweepPainter oldDelegate) => oldDelegate.travel != travel;
}

/// Trait de dégâts par-dessus le siège, le temps du coup.
class HitSlashPainter extends CustomPainter {
  const HitSlashPainter({required this.slash, this.strength = 1});

  final double slash;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)));
    _slash(canvas, rect, slash, sacreIvory, sacreEmber, span: strength);
    canvas.restore();
  }

  @override
  bool shouldRepaint(HitSlashPainter oldDelegate) {
    return oldDelegate.slash != slash || oldDelegate.strength != strength;
  }
}

/// Trois traits gravés : un sillon sombre, puis un filet clair.
class ChiselPainter extends CustomPainter {
  const ChiselPainter({required this.progress, this.plain = false});

  final double progress;
  final bool plain;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final frame = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    canvas.save();
    canvas.clipRRect(frame);
    canvas.drawRect(
      rect,
      Paint()..color = chiselGraphite.withValues(alpha: 0.9 * progress),
    );
    canvas.drawRRect(
      frame.deflate(1.2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _hairline()
        ..color = chiselEdge.withValues(alpha: 0.45 * progress),
    );
    if (plain) {
      canvas.restore();
      return;
    }
    const cuts = <(double, double, double, double)>[
      (0.1, 0.2, 0.9, 0.8),
      (0.08, 0.74, 0.92, 0.2),
      (0.46, 0.08, 0.56, 0.92),
    ];
    for (var i = 0; i < cuts.length; i++) {
      final raw = ((progress - i * 0.14) / 0.48).clamp(0.0, 1.0);
      if (raw <= 0) continue;
      final open = Curves.easeOut.transform(raw);
      final cut = cuts[i];
      final start = _snapPoint(Offset(
        rect.left + rect.width * cut.$1,
        rect.top + rect.height * cut.$2,
      ));
      final end = _snapPoint(Offset.lerp(
        start,
        Offset(rect.left + rect.width * cut.$3, rect.top + rect.height * cut.$4),
        open,
      )!);
      _engrave(canvas, start, end, open);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ChiselPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.plain != plain;
  }
}

void _engrave(Canvas canvas, Offset start, Offset end, double alpha) {
  final delta = end - start;
  final len = delta.distance;
  if (len < 1 || alpha <= 0) return;
  final dir = delta / len;
  var lit = Offset(-dir.dy, dir.dx);
  if (lit.dx * -0.7 + lit.dy * -0.72 < 0) lit = -lit;
  const groove = 1.7;
  final path = Path()
    ..moveTo(start.dx + lit.dx * groove, start.dy + lit.dy * groove)
    ..lineTo(end.dx + lit.dx * groove, end.dy + lit.dy * groove)
    ..lineTo(end.dx - lit.dx * groove, end.dy - lit.dy * groove)
    ..lineTo(start.dx - lit.dx * groove, start.dy - lit.dy * groove)
    ..close();
  canvas.drawPath(
    path.shift(const Offset(1, 1.4)),
    Paint()..color = chiselGroove.withValues(alpha: 0.85 * alpha),
  );
  canvas.drawPath(
    path,
    Paint()..color = const Color(0xFF0A0C10).withValues(alpha: 0.96 * alpha),
  );
  _blade(
    canvas,
    start + lit * (groove - 0.35),
    end + lit * (groove - 0.35),
    width: _hairline(),
    color: chiselSteel,
    alpha: 0.92 * alpha,
  );
}

/// Assombrissement net, filet clair en haut, le texte vient ensuite.
class EpitaphVeilPainter extends CustomPainter {
  const EpitaphVeilPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final t = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1C1916).withValues(alpha: 0.94 * t),
            epitaphInk.withValues(alpha: 0.97 * t),
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.42 * t),
          ],
          stops: const [0.42, 1],
        ).createShader(rect),
    );
    final top = _snap(rect.top + rect.height * 0.14);
    final bottom = _snap(rect.bottom - rect.height * 0.2);
    final left = _snap(rect.left + 18);
    final right = _snap(rect.right - 18);
    _rule(canvas, left, right, top, t);
    final lower = ((t - 0.46) / 0.54).clamp(0.0, 1.0);
    if (lower > 0) _rule(canvas, left, right, bottom, lower);
    canvas.restore();
  }

  @override
  bool shouldRepaint(EpitaphVeilPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

void _rule(Canvas canvas, double left, double right, double y, double alpha) {
  _blade(
    canvas,
    Offset(left, y + _hairline()),
    Offset(right, y + _hairline()),
    width: 3,
    color: Colors.black,
    alpha: 0.45 * alpha,
  );
  _blade(
    canvas,
    Offset(left, y),
    Offset(right, y),
    width: 1.6,
    color: epitaphWarm,
    alpha: 0.9 * alpha,
  );
}

/// Cercle qui se trace, puis un point au centre.
class SealPainter extends CustomPainter {
  const SealPainter({required this.progress, this.gold = false});

  final double progress;
  final bool gold;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0) return;
    final rect = Offset.zero & size;
    final color = gold ? accentGold : const Color(0xFFB42336);
    final highlight = gold ? sacreGoldLight : const Color(0xFFFFD5DC);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)));
    final radius = size.shortestSide * 0.28;
    final arc = Rect.fromCircle(center: rect.center, radius: radius);
    final sweep = math.pi * 2 * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      arc.shift(const Offset(0, 1.6)),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF1A0A0C).withValues(alpha: 0.55),
    );
    canvas.drawArc(
      arc,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.95),
    );
    canvas.drawArc(
      arc.deflate(1.8),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _hairline()
        ..strokeCap = StrokeCap.round
        ..color = highlight.withValues(alpha: 0.8),
    );
    if (progress > 0.9) {
      final tick = ((progress - 0.9) / 0.1).clamp(0.0, 1.0);
      for (var i = 0; i < 4; i++) {
        final angle = -math.pi / 2 + i * math.pi / 2;
        final dir = Offset(math.cos(angle), math.sin(angle));
        _blade(
          canvas,
          rect.center + dir * (radius + 3.5),
          rect.center + dir * (radius + 7),
          width: _hairline() + 0.4,
          color: color,
          alpha: 0.85 * tick,
        );
      }
    }
    if (progress > 0.72) {
      final dot = 4.5 * ((progress - 0.72) / 0.28).clamp(0.0, 1.0);
      canvas.drawCircle(
        rect.center.translate(0, 1.1),
        dot,
        Paint()..color = const Color(0xFF1A0A0C).withValues(alpha: 0.5),
      );
      canvas.drawCircle(rect.center, dot, Paint()..color = color);
      canvas.drawCircle(
        rect.center.translate(-0.7, -0.8),
        dot * 0.38,
        Paint()..color = highlight.withValues(alpha: 0.85),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SealPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.gold != gold;
  }
}

/// Un impact horizontal, court, au milieu du cadran.
class ArenaStrikePainter extends CustomPainter {
  const ArenaStrikePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0.02 || progress >= 0.98) return;
    final rect = Offset.zero & size;
    final open = progress < 0.45 ? progress / 0.45 : 1 - (progress - 0.45) / 0.55;
    final span = open.clamp(0.0, 1.0);
    final half = rect.width * 0.32 * span;
    final y = _snap(rect.center.dy);
    final left = _snapPoint(Offset(rect.center.dx - half, y));
    final right = _snapPoint(Offset(rect.center.dx + half, y));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rect.center.dx, y),
        width: 16 * span,
        height: 5 * span,
      ),
      Paint()
        ..color = const Color(0xFFFF4D3A).withValues(alpha: 0.28 * span)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    _blade(
      canvas,
      left.translate(0, _hairline()),
      right.translate(0, _hairline()),
      width: 2.2,
      color: const Color(0xFF4A1020),
      alpha: 0.55 * span,
    );
    _blade(
      canvas,
      left,
      right,
      width: _hairline() + 0.5,
      color: const Color(0xFFFFF7F4),
      alpha: 0.96 * span,
    );
    if (span > 0.45) {
      final tick = ((span - 0.45) / 0.55).clamp(0.0, 1.0);
      for (final end in [left, right]) {
        _blade(
          canvas,
          end.translate(0, -3.5),
          end.translate(0, 3.5),
          width: _hairline(),
          color: const Color(0xFFFFD0C8),
          alpha: 0.85 * tick,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ArenaStrikePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Le chiffre coupé : une diagonale, une croix, ou trois coches.
class CutNumberPainter extends CustomPainter {
  const CutNumberPainter({
    required this.life,
    required this.cause,
    required this.open,
  });

  final int life;
  final FinaleCause cause;
  final double open;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || cause == FinaleCause.leave) return;
    final tp = TextPainter(
      text: TextSpan(
        text: '$life',
        style: TextStyle(
          fontSize: math.min(56, size.shortestSide * 0.42),
          fontWeight: FontWeight.w900,
          color: chiselSteel,
          letterSpacing: -1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    final origin = Offset(
      (size.width - tp.width) / 2,
      (size.height - tp.height) / 2,
    );
    final box = origin & tp.size;
    final gap = 3 * open.clamp(0.0, 1.0);
    if (cause == FinaleCause.poison) {
      tp.paint(canvas, origin);
      for (var i = 0; i < 3; i++) {
        final grow = ((open - i * 0.16) / 0.45).clamp(0.0, 1.0);
        if (grow <= 0) continue;
        final y = _snap(box.top + box.height * (0.28 + i * 0.22));
        final left = box.left + box.width * 0.06;
        _blade(
          canvas,
          Offset(left, y),
          Offset(left + box.width * 0.88 * grow, y),
          width: 1.2,
          color: chiselSteel,
          alpha: 0.92,
        );
      }
      return;
    }
    if (cause == FinaleCause.commander) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(box.left - 4, box.top - 4, box.right + 4, box.center.dy));
      tp.paint(canvas, origin.translate(0, -gap / 2));
      canvas.restore();
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(box.left - 4, box.center.dy, box.right + 4, box.bottom + 4));
      tp.paint(canvas, origin.translate(0, gap / 2));
      canvas.restore();
      _blade(canvas, box.topLeft, box.bottomRight, width: 1.15, color: chiselSteel, alpha: open);
      _blade(canvas, box.topRight, box.bottomLeft, width: 1.15, color: chiselSteel, alpha: open);
      return;
    }
    final shift = gap / 2;
    canvas.save();
    canvas.clipPath(_dialHalf(box, upper: true));
    tp.paint(canvas, origin.translate(-shift, -shift));
    canvas.restore();
    canvas.save();
    canvas.clipPath(_dialHalf(box, upper: false));
    tp.paint(canvas, origin.translate(shift, shift));
    canvas.restore();
    _blade(canvas, box.topLeft, box.bottomRight, width: 1.2, color: chiselSteel, alpha: open);
  }

  @override
  bool shouldRepaint(CutNumberPainter oldDelegate) {
    return oldDelegate.life != life ||
        oldDelegate.cause != cause ||
        oldDelegate.open != open;
  }
}

Path _dialHalf(Rect box, {required bool upper}) {
  return Path()
    ..moveTo(box.left, box.top)
    ..lineTo(upper ? box.right : box.left, upper ? box.top : box.bottom)
    ..lineTo(box.right, box.bottom)
    ..close();
}

/// Citation du domaine public, avec le nom de l’auteur.
class CitedVerse {
  const CitedVerse(this.line, this.author);

  final String line;
  final String author;
}

const _victories = <CitedVerse>[
  CitedVerse(
    'À vaincre sans péril, on triomphe sans gloire.',
    'Pierre Corneille',
  ),
  CitedVerse(
    'La valeur n’attend point le nombre des années.',
    'Pierre Corneille',
  ),
  CitedVerse(
    'Je suis maître de moi comme de l’univers.',
    'Pierre Corneille',
  ),
  CitedVerse(
    'Ceux qui vivent, ce sont ceux qui luttent.',
    'Victor Hugo',
  ),
  CitedVerse(
    'Heureux qui, comme Ulysse, a fait un beau voyage.',
    'Joachim du Bellay',
  ),
  CitedVerse(
    'Le vent se lève !… Il faut tenter de vivre !',
    'Paul Valéry',
  ),
  CitedVerse('Veni, vidi, vici.', 'Jules César'),
];

const _defeats = <CitedVerse>[
  CitedVerse(
    'Seul, le silence est grand ; tout le reste est faiblesse.',
    'Alfred de Vigny',
  ),
  CitedVerse(
    'Gémir, pleurer, prier, est également lâche.',
    'Alfred de Vigny',
  ),
  CitedVerse(
    'Ô Mort, vieux capitaine, il est temps ! levons l’ancre !',
    'Charles Baudelaire',
  ),
  CitedVerse(
    'Un seul être vous manque, et tout est dépeuplé !',
    'Alphonse de Lamartine',
  ),
  CitedVerse(
    'Et rose elle a vécu ce que vivent les roses,\nL’espace d’un matin.',
    'François de Malherbe',
  ),
  CitedVerse(
    'Tout m’afflige et me nuit, et conspire à me nuire.',
    'Jean Racine',
  ),
];

int _verseSalt(String playerId) {
  var sum = 0;
  for (final unit in playerId.codeUnits) {
    sum += unit;
  }
  return sum;
}

/// Citation de défaite, stable pour un même joueur et une même cause.
CitedVerse defeatVerse(FinaleCause cause, String playerId) {
  final index = (_verseSalt(playerId) + cause.index) % _defeats.length;
  return _defeats[index];
}

/// Citation de victoire, stable pour un même joueur.
CitedVerse victoryVerse(String playerId) {
  return _victories[_verseSalt(playerId) % _victories.length];
}

class CitedLineView extends StatelessWidget {
  const CitedLineView({super.key, required this.verse, required this.color});

  final CitedVerse verse;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '« ${verse.line} »',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 16,
            height: 1.3,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          verse.author,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

String _inkLabel(String key) => switch (key) {
  'W' => 'Blanc',
  'U' => 'Bleu',
  'B' => 'Noir',
  'R' => 'Rouge',
  'G' => 'Vert',
  _ => '',
};

void _goldStar(Canvas canvas, Offset center, double radius, double alpha) {
  if (alpha <= 0.02) return;
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final reach = i.isEven ? radius : radius * 0.38;
    final angle = -math.pi / 2 + i * math.pi / 4;
    final point = center + Offset(math.cos(angle), math.sin(angle)) * reach;
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  path.close();
  canvas.drawPath(
    path,
    Paint()..color = sacreGoldLight.withValues(alpha: alpha.clamp(0.0, 1.0)),
  );
}

enum BlasonMood { shatter, glory }

/// Couleurs choisies par le joueur : brisées à la défaite, redorées à la victoire.
class BlasonPainter extends CustomPainter {
  const BlasonPainter({
    required this.inks,
    required this.fallback,
    required this.progress,
    required this.mood,
  });

  final List<String> inks;
  final Color fallback;
  final double progress;
  final BlasonMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final keys = inks.isEmpty ? const <String>[] : inks;
    final count = keys.isEmpty ? 1 : keys.length;
    final gap = 8.0;
    final maxW = (size.width - 28 - (count - 1) * gap) / count;
    final badgeW = maxW.clamp(34.0, 96.0);
    final badgeH = (badgeW * 0.56).clamp(26.0, 44.0);
    final total = count * badgeW + (count - 1) * gap;
    final left = (size.width - total) / 2;
    final top = 18.0;
    if (mood == BlasonMood.glory) {
      _crown(
        canvas,
        Offset(size.width / 2, top - 2),
        (total * 0.42).clamp(36.0, 88.0),
      );
    }
    for (var i = 0; i < count; i++) {
      final key = keys.isEmpty ? '' : keys[i];
      final color = key.isEmpty ? fallback : (manaPalette[key] ?? fallback);
      final label = _inkLabel(key);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left + i * (badgeW + gap), top + 16, badgeW, badgeH),
        const Radius.circular(10),
      );
      if (mood == BlasonMood.glory) {
        _gloryBadge(canvas, rect, color, label, progress, i);
      } else {
        _shatterBadge(canvas, rect, color, label, progress);
      }
    }
  }

  void _gloryBadge(
    Canvas canvas,
    RRect rect,
    Color color,
    String label,
    double t,
    int index,
  ) {
    canvas.drawRRect(
      rect.inflate(3),
      Paint()..color = sacreGoldLight.withValues(alpha: 0.95),
    );
    canvas.drawRRect(rect, Paint()..color = color);
    _inkText(canvas, rect.outerRect, label);
    final twinkle = 0.35 + 0.65 * ((math.sin(t * math.pi * 2 + index) + 1) / 2);
    _goldStar(canvas, rect.outerRect.topRight + const Offset(2, -2), 6, twinkle);
    _goldStar(canvas, rect.outerRect.topLeft + const Offset(-2, 4), 4, 1 - twinkle * 0.3);
  }

  void _shatterBadge(
    Canvas canvas,
    RRect rect,
    Color color,
    String label,
    double t,
  ) {
    final open = Curves.easeIn.transform(((t - 0.15) / 0.85).clamp(0.0, 1.0));
    final shift = open * rect.width * 0.42;
    final drop = open * rect.height * 1.15;
    _halfBadge(
      canvas,
      rect,
      color,
      label,
      left: true,
      shift: shift,
      drop: drop * 0.85,
      turn: -open * 0.35,
      alpha: 1 - open * 0.25,
    );
    _halfBadge(
      canvas,
      rect,
      color,
      label,
      left: false,
      shift: shift,
      drop: drop,
      turn: open * 0.28,
      alpha: 1 - open * 0.25,
    );
    if (t > 0.08 && open < 0.92) {
      final crack = rect.outerRect.center;
      canvas.drawLine(
        Offset(crack.dx, rect.top + 2),
        Offset(crack.dx, rect.bottom - 2),
        Paint()
          ..color = const Color(0xFFFFF6EA).withValues(alpha: 0.95)
          ..strokeWidth = 2.5,
      );
    }
  }

  void _halfBadge(
    Canvas canvas,
    RRect rect,
    Color color,
    String label, {
    required bool left,
    required double shift,
    required double drop,
    required double turn,
    required double alpha,
  }) {
    final box = rect.outerRect;
    canvas.save();
    canvas.translate(left ? -shift : shift, drop);
    canvas.translate(box.center.dx, box.center.dy);
    canvas.rotate(turn);
    canvas.translate(-box.center.dx, -box.center.dy);
    canvas.clipRect(
      Rect.fromLTRB(
        left ? box.left - 6 : box.center.dx,
        box.top - 8,
        left ? box.center.dx : box.right + 6,
        box.bottom + 8,
      ),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = color.withValues(alpha: alpha),
    );
    _inkText(canvas, box, label, alpha: alpha);
    canvas.restore();
  }

  void _crown(Canvas canvas, Offset tip, double width) {
    final path = Path()
      ..moveTo(tip.dx - width / 2, tip.dy + 12)
      ..lineTo(tip.dx - width * 0.32, tip.dy)
      ..lineTo(tip.dx - width * 0.16, tip.dy + 8)
      ..lineTo(tip.dx, tip.dy - 2)
      ..lineTo(tip.dx + width * 0.16, tip.dy + 8)
      ..lineTo(tip.dx + width * 0.32, tip.dy)
      ..lineTo(tip.dx + width / 2, tip.dy + 12)
      ..close();
    canvas.drawPath(path, Paint()..color = sacreGoldLight);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF6E4A16),
    );
  }

  void _inkText(Canvas canvas, Rect box, String label, {double alpha = 1}) {
    if (label.isEmpty || box.width < 32) return;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFF140E08).withValues(alpha: alpha),
          fontSize: (box.width * 0.24).clamp(10.0, 15.0),
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: box.width - 6);
    painter.paint(
      canvas,
      box.center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(BlasonPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.mood != mood ||
        oldDelegate.fallback != fallback ||
        oldDelegate.inks.length != inks.length;
  }
}

/// Étincelles qui restent tant que la victoire est affichée.
class GloryBlason extends StatefulWidget {
  const GloryBlason({
    super.key,
    required this.inks,
    required this.fallback,
    required this.animate,
  });

  final List<String> inks;
  final Color fallback;
  final bool animate;

  @override
  State<GloryBlason> createState() => _GloryBlasonState();
}

class _GloryBlasonState extends State<GloryBlason>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _drop;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    );
    _drop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.animate) {
      _spin.repeat();
      _drop.forward();
    } else {
      _drop.value = 1;
    }
  }

  @override
  void didUpdateWidget(GloryBlason oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_spin.isAnimating) {
      _spin.repeat();
      if (_drop.value == 0) _drop.forward();
    } else if (!widget.animate) {
      _spin.stop();
      _drop.value = 1;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _drop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_spin, _drop]),
      builder: (context, _) {
        final fall = Curves.easeOutBack.transform(_drop.value.clamp(0.0, 1.0));
        return Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: const Alignment(0, -0.42),
              child: FractionallySizedBox(
                widthFactor: 0.62,
                child: Transform.rotate(
                  angle: _spin.value * math.pi * 2,
                  child: Image.asset(
                    'assets/vfx/finale-sun.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, -0.42),
              child: FractionallySizedBox(
                widthFactor: 0.42,
                child: Transform.translate(
                  offset: Offset(0, (1 - fall) * -90),
                  child: Image.asset(
                    'assets/vfx/finale-crown.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            if (widget.animate)
              const IgnorePointer(
                child: VfxFilm(clipId: 'finale-confetti', scale: 1.05),
              ),
          ],
        );
      },
    );
  }
}

/// Les six lames descendent, se plantent, fendent le sol, puis tombent.
class SwordFall extends StatefulWidget {
  const SwordFall({super.key, required this.animate});

  final bool animate;

  @override
  State<SwordFall> createState() => _SwordFallState();
}

class _SwordFallState extends State<SwordFall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _strike;

  static const _blades = <(int, double, double, double, double)>[
    (0, -0.62, 0.50, -72, 0.00),
    (1, -0.28, 0.54, 58, 0.06),
    (2, 0.02, 0.46, -48, 0.03),
    (3, 0.28, 0.38, 76, 0.09),
    (4, 0.50, 0.44, -34, 0.05),
    (5, 0.72, 0.30, 62, 0.11),
  ];

  @override
  void initState() {
    super.initState();
    _strike = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.animate) {
      _strike.forward();
    } else {
      _strike.value = 1;
    }
  }

  @override
  void dispose() {
    _strike.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _strike,
      builder: (context, _) {
        final t = _strike.value;
        final hit = (1 - ((t - 0.46).abs() / 0.1)).clamp(0.0, 1.0);
        final shake = hit * math.sin(t * 90) * 7;
        return ClipRect(
          child: Transform.translate(
            offset: Offset(shake, 0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (final blade in _blades)
                  _fallingBlade(blade, t),
                if (t > 0.42)
                  Align(
                    alignment: const Alignment(0, 0.55),
                    child: FractionallySizedBox(
                      widthFactor: 0.9,
                      heightFactor: 0.28,
                      child: VfxFilm(
                        clipId: 'finale-slam',
                        scale: 1.05,
                        frame: widget.animate ? null : 8,
                      ),
                    ),
                  ),
                if (hit > 0)
                  ColoredBox(
                    color: const Color(0xFFFFF6EA).withValues(alpha: 0.28 * hit),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fallingBlade(
    (int, double, double, double, double) blade,
    double t,
  ) {
    final (index, x, height, lean, delay) = blade;
    final drop = Curves.easeIn.transform(((t - delay) / 0.42).clamp(0.0, 1.0));
    final topple = Curves.easeOut.transform(
      ((t - 0.48 - delay) / 0.42).clamp(0.0, 1.0),
    );
    return Align(
      alignment: Alignment(x, 0.22),
      child: FractionallySizedBox(
        heightFactor: height,
        child: Transform.translate(
          offset: Offset(0, (1 - drop) * -240),
          child: Transform.rotate(
            alignment: Alignment.bottomCenter,
            angle: topple * lean * math.pi / 180,
            child: Image.asset(
              'assets/vfx/finale-blade-$index.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
