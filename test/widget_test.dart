import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/setup/setup_screen.dart';
import 'package:mtg_table/ui/table/table_screen.dart';

void main() {
  GameController sample() {
    return GameController(
      game: Game.start(
        playerCount: 4,
        names: const ['Ana', 'Bo', 'Célia', 'Dan'],
        commanderNames: const [
          ['Atraxa'],
          ['Kraum', 'Tymna'],
          ['Meren'],
          ['Arahbo'],
        ],
      ),
    );
  }

  Future<void> pumpTable(
    WidgetTester tester,
    Size size,
    GameController controller, {
    ViewMode mode = ViewMode.auto,
    bool coach = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: TableScreen(
          controller: controller,
          settings: AppSettings.defaults.copyWith(
            haptic: false,
            viewMode: mode,
            coachSeen: !coach,
          ),
          onSettings: (_) {},
          onLeave: () {},
          onCoachDismissed: () {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('les tailles téléphone et tablette ne débordent pas', (
    tester,
  ) async {
    const sizes = <Size>[
      Size(360, 800),
      Size(800, 360),
      Size(600, 960),
      Size(1280, 800),
    ];
    for (final size in sizes) {
      final controller = sample();
      await pumpTable(tester, size, controller, coach: true);
      final error = tester.takeException();
      // Tolère les micro-overflows sub-pixel (arrondis layout).
      if (error != null) {
        final msg = '$error';
        final tiny = RegExp(r'overflowed by 0\.\d+ pixels').hasMatch(msg);
        expect(tiny, isTrue, reason: msg);
      }
      controller.dispose();
    }
  });

  testWidgets('un toucher sur le commandant inflige 1 et retire 1 vie', (
    tester,
  ) async {
    final controller = sample();
    addTearDown(controller.dispose);
    await pumpTable(
      tester,
      const Size(400, 900),
      controller,
      mode: ViewMode.list,
    );
    final ana = controller.game.players[0];
    final kraum = controller.game.players[1].commanders[0];
    final before = controller.playerById(ana.id).life;
    // + rouge inflige ; pastille = Cdt adverse (mode liste).
    await tester.tap(
      find.byKey(ValueKey('chip-plus-${ana.id}-${kraum.id}')),
    );
    await tester.pump();
    expect(controller.playerById(ana.id).life, before - 1);
    expect(controller.playerById(ana.id).damageTaken[kraum.id], 1);
  });

  testWidgets(
    'table 1v1 : + sur mon Cdt retire les PV adversaire',
    (tester) async {
      final controller = GameController(
        game: Game.start(
          playerCount: 2,
          names: const ['Joueur 1', 'Joueur 2'],
          commanderNames: const [
            ['Cdt1'],
            ['Cdt2'],
          ],
        ),
      );
      addTearDown(controller.dispose);
      await pumpTable(
        tester,
        const Size(800, 1200),
        controller,
        mode: ViewMode.table,
      );
      final j1 = controller.game.players[0];
      final j2 = controller.game.players[1];
      final cdt2 = j2.commanders[0];
      final beforeJ1 = j1.life;
      final beforeJ2 = j2.life;
      // Siège J2 → pastille Cdt Joueur 2 ; + inflige à J1 (pad en face).
      await tester.tap(
        find.byKey(ValueKey('chip-plus-${j1.id}-${cdt2.id}')),
      );
      await tester.pump();
      expect(controller.playerById(j1.id).life, beforeJ1 - 1);
      expect(controller.playerById(j2.id).life, beforeJ2);
      expect(controller.playerById(j1.id).damageTaken[cdt2.id], 1);
    },
  );

  testWidgets('zone dangereuse colore les PV bas', (tester) async {
    final controller = sample();
    addTearDown(controller.dispose);
    final ana = controller.game.players[0];
    controller.setLife(ana.id, 4);
    await pumpTable(
      tester,
      const Size(400, 900),
      controller,
      mode: ViewMode.list,
    );
    final lifeText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey('life-pad-${ana.id}-${ana.id}')),
        matching: find.byType(Text),
      ).first,
    );
    expect(lifeText.style?.color, dangerCrit);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ajouter / retirer un commandant depuis la fiche joueur', (
    tester,
  ) async {
    final controller = sample();
    addTearDown(controller.dispose);
    await pumpTable(
      tester,
      const Size(400, 900),
      controller,
      mode: ViewMode.list,
    );
    final ana = controller.game.players[0];
    await tester.tap(find.text('Ana').first);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('cmd-remove-${ana.id}')), findsNothing);
    expect(find.byKey(ValueKey('cmd-add-${ana.id}')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('cmd-add-${ana.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Partenaire');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(controller.playerById(ana.id).commanders, hasLength(2));
    expect(find.byKey(ValueKey('cmd-remove-${ana.id}')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('cmd-remove-${ana.id}')));
    await tester.pumpAndSettle();
    expect(controller.playerById(ana.id).commanders, hasLength(1));
  });

  testWidgets('le salon tient sur téléphone et tablette', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in const [Size(360, 640), Size(1280, 800)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: SetupScreen(
            settings: AppSettings.defaults,
            group: null,
            resumeLabel: 'Reprendre manche 2',
            onStart: (_) {},
            onResume: () {},
            onOpenSearch: () {},
            onOpenStats: () {},
            onImportSession: (_) async => true,
            onOpenNight: () {},
            onOpenPrivacy: () {},
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(SetupScreen), findsOneWidget);
      expect(find.textContaining('Lancer'), findsOneWidget);
    }
  });

  testWidgets('activer les handicaps affiche les réglages', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(
          settings: AppSettings.defaults,
          group: null,
          resumeLabel: null,
          onStart: (_) {},
          onResume: () {},
          onOpenSearch: () {},
          onOpenStats: () {},
          onImportSession: (_) async => true,
          onOpenNight: () {},
          onOpenPrivacy: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Équilibrer les decks'), findsOneWidget);
    await tester.ensureVisible(find.textContaining('Équilibrer les decks'));
    await tester.tap(find.textContaining('Équilibrer les decks'));
    await tester.pumpAndSettle();
    expect(find.text('Handicaps de deck'), findsOneWidget);
    expect(find.textContaining('Personnaliser les PV'), findsNothing);
    final handicapSwitch = find.descendant(
      of: find.widgetWithText(SwitchListTile, 'Handicaps de deck'),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(handicapSwitch);
    await tester.tap(handicapSwitch);
    await tester.pumpAndSettle();
    expect(find.textContaining('Personnaliser les PV'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('handicaps accessibles aussi en largeur desktop', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(
          settings: AppSettings.defaults,
          group: null,
          resumeLabel: null,
          onStart: (_) {},
          onResume: () {},
          onOpenSearch: () {},
          onOpenStats: () {},
          onImportSession: (_) async => true,
          onOpenNight: () {},
          onOpenPrivacy: () {},
        ),
      ),
    );
    await tester.pump();
    final tile = find.textContaining('Équilibrer les decks');
    expect(tile, findsOneWidget);
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('Handicaps de deck'), findsOneWidget);
    expect(find.byType(Switch), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
