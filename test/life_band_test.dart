import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/theme/app_theme.dart';

void main() {
  test('commander 40 PV : alerte vers 10, critique vers 5', () {
    expect(lifeBand(life: 40, startingLife: 40), LifeBand.safe);
    expect(lifeBand(life: 11, startingLife: 40), LifeBand.safe);
    expect(lifeBand(life: 10, startingLife: 40), LifeBand.warning);
    expect(lifeBand(life: 6, startingLife: 40), LifeBand.warning);
    expect(lifeBand(life: 5, startingLife: 40), LifeBand.critical);
    expect(lifeBand(life: 1, startingLife: 40), LifeBand.critical);
    expect(lifeBand(life: 0, startingLife: 40), LifeBand.critical);
  });

  test('construit 20 PV : seuils plus bas', () {
    expect(lifeBand(life: 7, startingLife: 20), LifeBand.safe);
    expect(lifeBand(life: 6, startingLife: 20), LifeBand.warning);
    expect(lifeBand(life: 3, startingLife: 20), LifeBand.critical);
  });
}
