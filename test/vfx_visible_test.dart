import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/ui/table/table_screen.dart';
import 'package:mtg_table/ui/widgets/option_glyphs.dart';
import 'package:mtg_table/ui/widgets/player_panel.dart';
import 'package:mtg_table/ui/widgets/vfx_film.dart';

void main() {
  test('or et ocre prennent le gris neutre la nuit', () {
    for (final tint in const [
      Color(0xFFE4B15C),
      Color(0xFFFF9A62),
      Color(0xFFC48A2A),
      Color(0xFF6AA8FF),
      Color(0xFFFF7D9C),
      Color(0xFF3DDCB4),
      Color(0xFFB59BFF),
      Color(0xFFFF7A6E),
    ]) {
      expect(SkyVeil.nightFor(tint), const Color(0x00000000));
    }
    expect(SkyVeil.warmNight, 0.28);
  });

  test('une planche décalée dans un tampon plus grand se décode', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final data = await rootBundle.load('assets/vfx/ash-shatter.png');
    final tight = Uint8List.sublistView(data);
    final padded = Uint8List(tight.length + 80);
    padded.setRange(40, 40 + tight.length, tight);
    final view = ByteData.sublistView(padded, 40, 40 + tight.length);
    final codec = await ui.instantiateImageCodec(Uint8List.sublistView(view));
    final frame = await codec.getNextFrame();
    codec.dispose();
    expect(frame.image.width, 4096);
    expect(frame.image.height, 128);
  });

  testWidgets('l animation entiere couvre chaque joueur, jour comme nuit', (
    tester,
  ) async {
    Future<void> open(
      GameController controller,
      Size size, {
      FinaleStyle style = FinaleStyle.mythic,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: TableScreen(
            controller: controller,
            settings: AppSettings.defaults.copyWith(
              haptic: false,
              coachSeen: true,
              beginnerTips: false,
              finaleStyle: style,
            ),
            onSettings: (_) {},
            onLeave: () {},
            onCoachDismissed: () {},
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> expectFull(int count, String why) async {
      final error = tester.takeException();
      if (error != null) {
        final tiny = RegExp(r'overflowed by 0\.\d+ pixels').hasMatch('$error');
        expect(tiny, isTrue, reason: '$why : $error');
      }
      for (var i = 0; i < 25 && find.descendant(
            of: find.byType(FxBoard),
            matching: find.byType(CustomPaint),
          ).evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 280));
      final panels = find.byType(PlayerPanel);
      expect(panels, findsNWidgets(count), reason: why);
      for (var i = 0; i < count; i++) {
        final panel = panels.at(i);
        final films = find.descendant(
          of: panel,
          matching: find.byType(FxBoard),
        );
        expect(films, findsWidgets, reason: '$why joueur $i');
        expect(
          find.descendant(
            of: panel,
            matching: find.byType(BackdropFilter),
          ),
          findsNothing,
          reason: '$why le voile ne remplace pas la case',
        );
        final paints = find.descendant(
          of: films.first,
          matching: find.byType(CustomPaint),
        );
        expect(paints, findsWidgets, reason: '$why joueur $i');
        expect(
          find.ancestor(of: paints.first, matching: find.byType(SkyVeil)),
          findsNothing,
          reason: '$why le voile ne contient pas l animation',
        );
        final wash = tester.widget<CustomPaint>(
          find.descendant(
            of: panel,
            matching: find.byKey(const ValueKey('sky-veil')),
          ),
        );
        final sky = wash.painter! as SkyWash;
        expect(
          sky.mode,
          why.contains('night') ? BlendMode.multiply : BlendMode.srcOver,
          reason: '$why',
        );
        final paintSize = tester.getSize(paints.first);
        final panelSize = tester.getSize(panel);
        final shortest = panelSize.shortestSide;
        expect(
          paintSize.shortestSide,
          greaterThan(shortest * 0.75),
          reason: '$why effet ${paintSize.shortestSide} case $shortest',
        );
        final paintRect = tester.getRect(paints.first);
        final panelRect = tester.getRect(panel);
        expect(panelRect.inflate(4).contains(paintRect.topLeft), isTrue);
        expect(panelRect.inflate(4).contains(paintRect.bottomRight), isTrue);
      }
    }

    for (final count in [2, 3, 4, 5, 6, 7, 8]) {
      for (final size in const [
        Size(360, 800),
        Size(800, 360),
        Size(1280, 800),
      ]) {
        final controller = GameController(
          game: Game.start(
            playerCount: count,
            names: [for (var i = 1; i <= count; i++) 'Joueur $i'],
          ),
        );
        addTearDown(controller.dispose);
        await open(controller, size);
        for (final player in controller.game.players) {
          controller.addLife(player.id, -8);
        }
        await tester.pump();
        for (final state in [DayState.day, DayState.night]) {
          controller.setDay(state);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await expectFull(count, '$count $size $state');
        }
      }
    }
  });

  testWidgets('sans animation voulue, aucun effet', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final still = GameController(
      game: Game.start(playerCount: 4, names: const ['Ana', 'Bo', 'Célia', 'Dan']),
    );
    addTearDown(still.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: TableScreen(
          controller: still,
          settings: AppSettings.defaults.copyWith(
            haptic: false,
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
    still.addLife(still.game.players.first.id, -5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FxBoard), findsNothing);

    final quiet = GameController(
      game: Game.start(playerCount: 3, names: const ['Ana', 'Bo', 'Célia']),
    );
    addTearDown(quiet.dispose);
    quiet.setCastAll(CastTone.aucune);
    await tester.pumpWidget(
      MaterialApp(
        home: TableScreen(
          controller: quiet,
          settings: AppSettings.defaults.copyWith(
            haptic: false,
            coachSeen: true,
          ),
          onSettings: (_) {},
          onLeave: () {},
          onCoachDismissed: () {},
        ),
      ),
    );
    await tester.pump();
    quiet.addLife(quiet.game.players[1].id, -5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FxBoard), findsNothing);
  });
}
