import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/ui/widgets/vfx_film.dart';

void main() {
  void staysInside(double width, double height, double scale) {
    final fit = vfxFit(width, height, scale);
    expect(fit.side, greaterThan(0));
    expect(fit.side, lessThanOrEqualTo(width));
    expect(fit.top + fit.side + fit.bottom, lessThanOrEqualTo(height + 0.01));
    expect(fit.top, greaterThan(0));
    expect(fit.bottom, greaterThan(0));
  }

  test('l’effet reste dans la case, dans chaque disposition', () {
    const boxes = <(double, double)>[
      (960, 900), // deux joueurs, grand rectangle
      (960, 337), // rangée du haut
      (405, 738), // côté, une fois tourné
      (288, 525), // côté, fenêtre plus basse
      (480, 400), // quart de table
      (700, 280), // bande courte
      (360, 160), // téléphone
      (800, 800), // carré
      (140, 110), // case très petite
    ];
    for (final box in boxes) {
      staysInside(box.$1, box.$2, 0.7);
      staysInside(box.$1, box.$2, 1.08);
      staysInside(box.$1, box.$2, 1.45);
    }
  });

  test('une case plus grande donne un effet plus grand', () {
    final small = vfxFit(405, 738, 1.45);
    final big = vfxFit(960, 900, 1.45);
    expect(big.side, greaterThan(small.side));
  });

  test('un palier plus fort grandit sans couvrir les bouts', () {
    final mild = vfxFit(405, 738, 0.7);
    final strong = vfxFit(405, 738, 1.45);
    expect(strong.side, greaterThan(mild.side));
    expect(strong.top, greaterThanOrEqualTo(48));
    expect(strong.bottom, greaterThanOrEqualTo(68));
  });
}
