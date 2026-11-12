import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/ui/widgets/option_glyphs.dart';

void main() {
  testWidgets('la lune s’allume pour la nuit, le soleil pour le jour', (
    tester,
  ) async {
    var state = DayState.unset;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return DayNightControl(
                state: state,
                onSun: () => setState(() {
                  state = state == DayState.day ? DayState.unset : DayState.day;
                }),
                onMoon: () => setState(() {
                  state = state == DayState.night
                      ? DayState.unset
                      : DayState.night;
                }),
              );
            },
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byKey(const ValueKey('sky-moon'))).flagsCollection.isSelected,
      Tristate.isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('sky-moon')));
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(const ValueKey('sky-moon'))).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('sky-sun'))).flagsCollection.isSelected,
      Tristate.isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('sky-sun')));
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(const ValueKey('sky-sun'))).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('sky-moon'))).flagsCollection.isSelected,
      Tristate.isFalse,
    );
  });
}
