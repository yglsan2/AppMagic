import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/ui/table/table_screen.dart';

void main() {
  testWidgets('la défaite et la victoire restent jouables pendant l’animation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = GameController(
      game: Game.start(playerCount: 2, names: const ['Ana', 'Bo']),
    );
    addTearDown(controller.dispose);
    final fallen = controller.game.players.last;

    await tester.pumpWidget(
      MaterialApp(
        home: TableScreen(
          controller: controller,
          settings: AppSettings.defaults.copyWith(
            haptic: false,
            beginnerTips: false,
            coachSeen: true,
          ),
          onSettings: (_) {},
          onLeave: () {},
          onCoachDismissed: () {},
        ),
      ),
    );
    await tester.pump();

    controller.addLife(fallen.id, -40);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('Défaite'), findsOneWidget);
    expect(find.textContaining('points de vie sont à zéro'), findsNothing);
    expect(find.textContaining('Le blason se redore'), findsNothing);
    expect(_citedAuthor(), findsWidgets);
    expect(find.text('Victoire'), findsOneWidget);
    expect(find.text('Ana gagne la partie'), findsOneWidget);
    expect(find.text('Revenir à la table'), findsOneWidget);
    expect(find.text('Une revanche ?'), findsOneWidget);
    expect(find.text('Revanche'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Revenir à la table'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.game.isDefeated(controller.game.playerById(fallen.id)), isFalse);
    expect(find.text('Défaite'), findsNothing);
    expect(find.text('Ana gagne la partie'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le coup fatal tient sur un téléphone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = GameController(
      game: Game.start(playerCount: 2, names: const ['Ana', 'Bo']),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TableScreen(
          controller: controller,
          settings: AppSettings.defaults.copyWith(
            haptic: false,
            beginnerTips: false,
            coachSeen: true,
          ),
          onSettings: (_) {},
          onLeave: () {},
          onCoachDismissed: () {},
        ),
      ),
    );
    await tester.pump();
    controller.addLife(controller.game.players.last.id, -40);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));
    await tester.pump(const Duration(milliseconds: 500));

    final error = tester.takeException();
    if (error != null) {
      final tiny = RegExp(r'overflowed by 0\.\d+ pixels').hasMatch('$error');
      expect(tiny, isTrue, reason: '$error');
    }
    expect(find.text('Défaite'), findsOneWidget);
    expect(find.text('Revenir à la table'), findsOneWidget);
  });

  testWidgets('sans animation, le message et le bouton sont là tout de suite', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = GameController(
      game: Game.start(playerCount: 2, names: const ['Ana', 'Bo']),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TableScreen(
          controller: controller,
          settings: AppSettings.defaults.copyWith(
            haptic: false,
            beginnerTips: false,
            coachSeen: true,
            finaleStyle: FinaleStyle.still,
          ),
          onSettings: (_) {},
          onLeave: () {},
          onCoachDismissed: () {},
        ),
      ),
    );
    await tester.pump();
    controller.addLife(controller.game.players.last.id, -40);
    await tester.pump();

    expect(find.text('Défaite'), findsOneWidget);
    expect(find.textContaining('points de vie sont à zéro'), findsNothing);
    expect(find.textContaining('Le blason se redore'), findsNothing);
    expect(_citedAuthor(), findsWidgets);
    expect(find.text('Victoire'), findsOneWidget);
    expect(find.text('Ana gagne la partie'), findsOneWidget);
    expect(find.text('Revenir à la table'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Épitaphe affiche la phrase écrite avant la partie', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = GameController(
      game: Game.start(playerCount: 2, names: const ['Ana', 'Bo']),
    );
    addTearDown(controller.dispose);
    final fallen = controller.game.players.last;

    await tester.pumpWidget(
      MaterialApp(
        home: TableScreen(
          controller: controller,
          settings: AppSettings.defaults.copyWith(
            haptic: false,
            beginnerTips: false,
            coachSeen: true,
            finaleStyle: FinaleStyle.lotus,
            saltLines: const ['Tu peux ranger tes cartes.'],
          ),
          onSettings: (_) {},
          onLeave: () {},
          onCoachDismissed: () {},
        ),
      ),
    );
    await tester.pump();
    controller.addLife(fallen.id, -40);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Tu peux ranger tes cartes.'), findsOneWidget);
    expect(find.textContaining('Défaite'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Épitaphe remplit la phrase avec la partie', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = GameController(
      game: Game.start(playerCount: 2, names: const ['Ana', 'Bo']),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TableScreen(
          controller: controller,
          settings: AppSettings.defaults.copyWith(
            haptic: false,
            beginnerTips: false,
            coachSeen: true,
            finaleStyle: FinaleStyle.lotus,
            epitaphLife: '{nom} tombe sous {perte} de {vainqueur}',
          ),
          onSettings: (_) {},
          onLeave: () {},
          onCoachDismissed: () {},
        ),
      ),
    );
    await tester.pump();
    controller.addLife(controller.game.players.last.id, -40);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Bo tombe sous 40 de Ana'), findsOneWidget);
    expect(find.textContaining('Défaite'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le bouton du haut change l’animation', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = GameController(
      game: Game.start(playerCount: 2, names: const ['Ana', 'Bo']),
    );
    addTearDown(controller.dispose);
    var settings = AppSettings.defaults.copyWith(
      haptic: false,
      beginnerTips: false,
      coachSeen: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return TableScreen(
              controller: controller,
              settings: settings,
              onSettings: (next) => setState(() => settings = next),
              onLeave: () {},
              onCoachDismissed: () {},
            );
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Animations'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Standard  · actuel'), findsOneWidget);
    await tester.tap(find.text('Sans animation'));
    await tester.pump();

    expect(settings.finaleStyle, FinaleStyle.still);
    expect(controller.game.players.every((player) => player.cast == CastTone.aucune), isTrue);
    await tester.tap(find.byTooltip('Animations'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sans animation  · actuel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('les animations suivent chaque taille et disposition', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var tables = 0;
    Future<void> openTable({
      required Size size,
      required int count,
      required FinaleStyle style,
      required List<String> names,
    }) async {
      tester.view.physicalSize = size;
      final controller = GameController(
        game: Game.start(playerCount: count, names: names),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: TableScreen(
            key: ValueKey('table-${tables++}-${size.width}x${size.height}-$count-$style'),
            controller: controller,
            settings: AppSettings.defaults.copyWith(
              haptic: false,
              beginnerTips: false,
              coachSeen: true,
              finaleStyle: style,
            ),
            onSettings: (_) {},
            onLeave: () {},
            onCoachDismissed: () {},
          ),
        ),
      );
      await tester.pump();
      final error = tester.takeException();
      if (error != null) {
        expect(
          RegExp(r'overflowed by 0\.\d+ pixels').hasMatch('$error'),
          isTrue,
          reason: '$size $count $style ouvert : $error',
        );
      }
      expect(find.byIcon(Icons.settings), findsWidgets);
      expect(find.text('Mes PV'), findsWidgets);
      expect(find.byTooltip('Animations'), findsOneWidget);
      return;
    }

    Future<GameController> current() async {
      final screen = tester.widget<TableScreen>(find.byType(TableScreen));
      return screen.controller;
    }

    void tolerate(Object? error, String why) {
      if (error == null) return;
      expect(
        RegExp(r'overflowed by 0\.\d+ pixels').hasMatch('$error'),
        isTrue,
        reason: '$why : $error',
      );
    }

    Future<void> defeatLast() async {
      final controller = await current();
      controller.addLife(controller.game.players.last.id, -40);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 480));
      tolerate(tester.takeException(), 'défaite');
      expect(find.text('Défaite'), findsWidgets);
      expect(find.text('Revenir à la table'), findsWidgets);
    }

    const sizes = <Size>[
      Size(360, 800),
      Size(800, 360),
      Size(600, 960),
      Size(1280, 800),
    ];
    for (final size in sizes) {
      for (final style in FinaleStyle.values) {
        await openTable(
          size: size,
          count: 3,
          style: style,
          names: const ['Ana', 'Bo', 'Célia'],
        );
        await defeatLast();
        final controller = await current();
        controller.addLife(controller.game.players[1].id, -40);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        tolerate(tester.takeException(), '$size $style victoire');
        expect(find.textContaining('gagne'), findsWidgets);
        expect(find.text('Revanche'), findsWidgets);
      }
    }

    for (final size in const [Size(360, 800), Size(800, 360), Size(1280, 800)]) {
      for (final count in const [2, 4, 6, 8]) {
        for (final style in const [FinaleStyle.mythic, FinaleStyle.carbon, FinaleStyle.lotus]) {
          await openTable(
            size: size,
            count: count,
            style: style,
            names: [for (var i = 1; i <= count; i++) 'Joueur $i'],
          );
          await defeatLast();
        }
      }
    }

    tester.view.physicalSize = const Size(1280, 800);
    for (final layout in const ['Table ronde', 'Liste droite']) {
      for (final style in const [FinaleStyle.mythic, FinaleStyle.lotus, FinaleStyle.carbon]) {
        await openTable(
          size: const Size(1280, 800),
          count: 3,
          style: style,
          names: const ['Ana', 'Bo', 'Célia'],
        );
        await tester.tap(find.byTooltip('Disposition de l’écran'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final item = find.textContaining(layout);
        expect(item, findsWidgets, reason: layout);
        await tester.tap(item.last);
        await tester.pump();
        tolerate(tester.takeException(), layout);
        await defeatLast();
      }
    }

    await openTable(
      size: const Size(800, 360),
      count: 3,
      style: FinaleStyle.mythic,
      names: const ['Ana', 'Bo', 'Célia'],
    );
    await defeatLast();
    await tester.tap(find.text('Revenir à la table').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final revived = await current();
    expect(
      revived.game.isDefeated(revived.game.players.last),
      isFalse,
    );
    tolerate(tester.takeException(), 'retour');
  });
}

Finder _citedAuthor() {
  const names = [
    'Pierre Corneille',
    'Victor Hugo',
    'Joachim du Bellay',
    'Paul Valéry',
    'Jules César',
    'Alfred de Vigny',
    'Charles Baudelaire',
    'Alphonse de Lamartine',
    'François de Malherbe',
    'Jean Racine',
  ];
  return find.byWidgetPredicate((widget) {
    final text = widget is Text ? widget.data : null;
    return text != null && names.contains(text);
  });
}
