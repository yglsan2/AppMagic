import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/main.dart';
import 'package:mtg_table/ui/widgets/player_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> boot(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TableMtgApp());
    await _until(tester, find.textContaining('Lancer'));
  }

  testWidgets('parcours salon, table, outils et retour', (tester) async {
    await boot(tester);

    expect(find.text('Table MTG'), findsOneWidget);
    expect(find.text('Commander (EDH)'), findsOneWidget);

    await tester.tap(find.text('Construit (60 cartes)'));
    await tester.pump();
    expect(find.textContaining('20'), findsWidgets);

    await tester.tap(find.text('Commander (EDH)'));
    await tester.pump();
    expect(find.textContaining('40'), findsWidgets);

    await tester.ensureVisible(find.textContaining('Lancer'));
    await tester.tap(find.textContaining('Lancer'));
    await _until(tester, find.text('Qui commence ?'));

    await tester.tap(find.text('Passer'));
    await _until(tester, find.text('Fin de tour'));

    expect(find.text('À toi de jouer'), findsOneWidget);

    expect(find.text('40'), findsWidgets);
    await tester.ensureVisible(find.text('−').first);
    await tester.tap(find.text('−').first);
    await tester.pump();
    expect(find.text('39'), findsWidgets);

    await tester.tap(find.byTooltip('Annuler'));
    await tester.pump();
    expect(find.text('39'), findsNothing);
    expect(find.text('40'), findsWidgets);

    final seat = find.ancestor(
      of: find.text('Fin de tour'),
      matching: find.byType(PlayerPanel),
    );
    expect(
      find.descendant(of: seat, matching: find.text('Joueur 1')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Fin de tour'));
    await tester.tap(find.text('Fin de tour'));
    await tester.pump();
    expect(
      find.descendant(of: seat, matching: find.text('Joueur 2')),
      findsOneWidget,
    );
    expect(find.text('Fin de tour'), findsOneWidget);

    await tester.tap(find.byTooltip('Dés'));
    await _until(tester, find.text('d6'));
    await _settle(tester);
    await tester.ensureVisible(find.text('d6'));
    await tester.tap(find.text('d6'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Lancer'));
    await tester.tap(find.widgetWithText(FilledButton, 'Lancer'));
    await tester.pump();
    expect(find.text('d6'), findsWidgets);
    expect(tester.takeException(), isNull);
    navigatorOf(tester).pop();
    await _settle(tester);

    await tester.tap(find.byTooltip('Historique'));
    await _until(tester, find.text('Historique & journal'));
    await _settle(tester);
    navigatorOf(tester).pop();
    await _settle(tester);

    await tester.tap(find.byTooltip('Menu'));
    await _until(tester, find.text('Transférer (QR)'));
    await _settle(tester);
    await tester.tap(find.text('Transférer (QR)'));
    await _until(tester, find.text('Transférer la partie'));
    await _settle(tester);
    await tester.tap(find.text('Fermer'));
    await _settle(tester);

    await tester.tap(find.byTooltip('Menu'));
    await _until(tester, find.text('Réglages'));
    await _settle(tester);
    await tester.tap(find.text('Réglages'));
    await _until(tester, find.text('Vibrations'));
    await _settle(tester);
    navigatorOf(tester).pop();
    await _settle(tester);

    await tester.tap(find.byTooltip('Menu'));
    await _until(tester, find.text('À propos'));
    await _settle(tester);
    await tester.tap(find.text('À propos'));
    await _until(tester, find.text('Fermer'));
    await _settle(tester);
    await tester.tap(find.text('Fermer'));
    await _settle(tester);

    await tester.tap(find.byTooltip('Salon'));
    await _until(tester, find.text('Quitter la table'));
    await tester.tap(find.text('Quitter la table'));
    await _until(tester, find.textContaining('Reprendre'));

    await tester.tap(find.text('Outils & soirée'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vie privée'));
    await _until(tester, find.textContaining('Vie privée & données'));
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.text('Fermer'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Fermer'));
    await _settle(tester);

    await tester.tap(find.text('Historique'));
    await _until(tester, find.text('Parties & stats'));
    expect(find.textContaining('Aucune partie enregistrée'), findsOneWidget);
    navigatorOf(tester).pop();
    await tester.pump();

    await tester.ensureVisible(find.text('Cartes'));
    await tester.tap(find.text('Cartes'));
    await _until(tester, find.text('Outils'));
    expect(find.text('Hasard'), findsOneWidget);
    expect(find.text('Mémo'), findsOneWidget);
    navigatorOf(tester).pop();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('parcours soirée multi-tables', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Outils & soirée'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soirée multi-tables'));
    await _until(tester, find.text('Mode soirée'));
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.text('Ouvrir la soirée'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Ouvrir la soirée'));
    await _until(tester, find.textContaining('Soirée ouverte'));
    expect(find.text('Table 1'), findsWidgets);
    expect(find.text('Classement'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

NavigatorState navigatorOf(WidgetTester tester) {
  return tester.state<NavigatorState>(find.byType(Navigator));
}
