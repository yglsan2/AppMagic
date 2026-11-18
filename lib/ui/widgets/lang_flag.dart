import 'package:flutter/material.dart';
import 'package:mtg_table/l10n/app_lang.dart';

/// Petit drapeau dessiné (pas d’emoji : sous Windows ça sort « FR »).
class LangFlag extends StatelessWidget {
  const LangFlag({
    super.key,
    required this.lang,
    this.width = 28,
    this.height = 20,
  });

  final AppLang lang;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: lang.nativeName,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: CustomPaint(
          size: Size(width, height),
          painter: _FlagPainter(lang),
        ),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  const _FlagPainter(this.lang);

  final AppLang lang;

  @override
  void paint(Canvas canvas, Size size) {
    switch (lang) {
      case AppLang.fr:
        _fr(canvas, size);
      case AppLang.en:
        _gb(canvas, size);
      case AppLang.lv:
        _lv(canvas, size);
    }
    // Liseré discret pour se détacher du fond sombre.
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x66000000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(3),
      ),
      border,
    );
  }

  void _fr(Canvas canvas, Size size) {
    final w = size.width / 3;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, size.height), Paint()..color = const Color(0xFF0055A4));
    canvas.drawRect(Rect.fromLTWH(w, 0, w, size.height), Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawRect(Rect.fromLTWH(w * 2, 0, w, size.height), Paint()..color = const Color(0xFFEF4135));
  }

  void _lv(Canvas canvas, Size size) {
    final h = size.height;
    final band = h * 0.2;
    final red = Paint()..color = const Color(0xFF9E1B32);
    final white = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, h), red);
    canvas.drawRect(Rect.fromLTWH(0, (h - band) / 2, size.width, band), white);
  }

  void _gb(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Fond bleu.
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF012169));

    final white = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = h * 0.28
      ..strokeCap = StrokeCap.butt;
    final red = Paint()
      ..color = const Color(0xFFC8102E)
      ..strokeWidth = h * 0.14
      ..strokeCap = StrokeCap.butt;

    // Croix de saint André (diagonales).
    canvas.drawLine(Offset.zero, Offset(w, h), white);
    canvas.drawLine(Offset(w, 0), Offset(0, h), white);
    canvas.drawLine(Offset.zero, Offset(w, h), red);
    canvas.drawLine(Offset(w, 0), Offset(0, h), red);

    // Croix de saint Georges.
    final whiteCross = Paint()..color = const Color(0xFFFFFFFF);
    final redCross = Paint()..color = const Color(0xFFC8102E);
    canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.22, height: h), whiteCross);
    canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, h / 2), width: w, height: h * 0.34), whiteCross);
    canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.12, height: h), redCross);
    canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, h / 2), width: w, height: h * 0.18), redCross);
  }

  @override
  bool shouldRepaint(covariant _FlagPainter oldDelegate) => oldDelegate.lang != lang;
}
