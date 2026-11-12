import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/net/table_link.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/setup/setup_screen.dart';
import 'package:mtg_table/ui/sheets/my_commander_sheet.dart';
import 'package:mtg_table/ui/sheets/settings_sheet.dart';
import 'package:mtg_table/ui/table/table_screen.dart';
import 'package:mtg_table/ui/widgets/danger_life.dart';
import 'package:mtg_table/ui/widgets/help_tip.dart';
import 'package:mtg_table/ui/widgets/option_glyphs.dart';
import 'package:mtg_table/ui/widgets/player_panel.dart';
import 'package:mtg_table/ui/widgets/vfx_film.dart';

class _HoldSettings extends StatefulWidget {
  const _HoldSettings({
    super.key,
    required this.controller,
    required this.settings,
  });

  final GameController controller;
  final AppSettings settings;

  @override
  State<_HoldSettings> createState() => _HoldSettingsState();
}

class _HoldSettingsState extends State<_HoldSettings> {
  late AppSettings _settings = widget.settings;

  @override
  void didUpdateWidget(covariant _HoldSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) _settings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    return TableScreen(
      controller: widget.controller,
      settings: _settings,
      onSettings: (next) => setState(() => _settings = next),
      onLeave: () {},
      onCoachDismissed: () {},
    );
  }
}

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
    bool selfScoring = false,
    bool tips = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: _HoldSettings(
          key: ValueKey(
            '${size.width}x${size.height}x${controller.game.players.length}x$selfScoring',
          ),
          controller: controller,
          settings: AppSettings.defaults.copyWith(
            haptic: false,
            viewMode: mode,
            coachSeen: !coach,
            beginnerTips: tips,
            scorePane: selfScoring ? ScorePane.own : ScorePane.foes,
          ),
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

  testWidgets('4 joueurs : quatre rectangles égaux, jour au centre', (
    tester,
  ) async {
    Future<void> check(Size size) async {
      final controller = sample();
      addTearDown(controller.dispose);
      await pumpTable(tester, size, controller);
      final error = tester.takeException();
      if (error != null) {
        final tiny = RegExp(r'overflowed by 0\.\d+ pixels').hasMatch('$error');
        expect(tiny, isTrue, reason: '$size : $error');
      }
      final panels = find.byType(PlayerPanel);
      expect(panels, findsNWidgets(4));
      final rects = [
        for (var i = 0; i < 4; i++) tester.getRect(panels.at(i)),
      ]..sort((a, b) {
        final down = a.top.compareTo(b.top);
        return down != 0 ? down : a.left.compareTo(b.left);
      });
      final topLeft = rects[0];
      final topRight = rects[1];
      final bottomLeft = rects[2];
      final bottomRight = rects[3];
      for (final rect in rects.skip(1)) {
        expect(rect.width, closeTo(topLeft.width, 3), reason: '$size');
        expect(rect.height, closeTo(topLeft.height, 3), reason: '$size');
      }
      expect(topRight.left, closeTo(topLeft.right, 8), reason: '$size');
      expect(bottomLeft.top, closeTo(topLeft.bottom, 8), reason: '$size');
      expect(bottomRight.left, closeTo(bottomLeft.right, 8), reason: '$size');
      expect(bottomRight.top, closeTo(topRight.bottom, 8), reason: '$size');
      expect(topLeft.left, lessThan(topRight.left));
      expect(topLeft.top, lessThan(bottomLeft.top));

      int seatOf(Rect area) {
        for (var i = 0; i < 4; i++) {
          final panel = panels.at(i);
          if ((tester.getRect(panel).center - area.center).distance < 30) {
            final id = tester.widget<PlayerPanel>(panel).playerId;
            return controller.game.players.indexWhere(
              (player) => player.id == id,
            );
          }
        }
        return -1;
      }

      expect(seatOf(topLeft), 0, reason: '$size haut gauche');
      expect(seatOf(topRight), 1, reason: '$size haut droite');
      expect(seatOf(bottomRight), 2, reason: '$size bas droite');
      expect(seatOf(bottomLeft), 3, reason: '$size bas gauche');

      final sky = tester.getRect(find.byType(DayNightControl));
      final meet = Offset(
        (topLeft.right + topRight.left) / 2,
        (topLeft.bottom + bottomLeft.top) / 2,
      );
      expect(sky.center.dx, closeTo(meet.dx, 28), reason: '$size');
      expect(sky.center.dy, closeTo(meet.dy, 28), reason: '$size');
    }

    await check(const Size(360, 800));
    await check(const Size(800, 360));
    await check(const Size(700, 700));
    await check(const Size(1280, 800));
  });

  testWidgets('le voile jour et nuit couvre chaque joueur', (tester) async {
    Future<void> check(int count, Size size) async {
      final controller = GameController(
        game: Game.start(
          playerCount: count,
          names: [for (var i = 1; i <= count; i++) 'Joueur $i'],
        ),
      );
      addTearDown(controller.dispose);
      await pumpTable(tester, size, controller);
      final error = tester.takeException();
      if (error != null) {
        final tiny = RegExp(r'overflowed by 0\.\d+ pixels').hasMatch('$error');
        expect(tiny, isTrue, reason: '$count $size : $error');
      }

      void expectVeil(DayState sky) {
        final panels = find.byType(PlayerPanel);
        expect(panels, findsNWidgets(count), reason: '$count $size');
        expect(find.byType(SkyVeil), findsNWidgets(count), reason: '$count $size');
        for (var i = 0; i < count; i++) {
          final panel = panels.at(i);
          final box = find.descendant(
            of: panel,
            matching: find.byKey(const ValueKey('sky-veil')),
          );
          expect(box, findsOneWidget, reason: '$count joueur $i');
          final tint = tester
              .widget<ThreatPanelShell>(
                find.descendant(
                  of: panel,
                  matching: find.byType(ThreatPanelShell),
                ),
              )
              .playerTint;
          final color = switch (sky) {
            DayState.night => SkyVeil.nightFor(tint),
            DayState.day => SkyVeil.dayTint,
            DayState.unset => const Color(0x00000000),
          };
          expect(
            tester.widget<CustomPaint>(box).painter,
            isA<SkyWash>().having((wash) => wash.color, 'color', color),
            reason: '$count $size',
          );
          if (sky == DayState.night) {
            expect(
              find.descendant(of: panel, matching: find.byType(ColorFiltered)),
              findsOneWidget,
              reason: '$count $size assombri comme l or',
            );
          }
          final veil = tester.getRect(box);
          final rect = tester.getRect(panel);
          expect(veil.width, closeTo(rect.width, 28), reason: '$count $size');
          expect(veil.height, closeTo(rect.height, 28), reason: '$count $size');
          expect(rect.contains(veil.center), isTrue, reason: '$count joueur $i');
          final film = find.descendant(
            of: panel,
            matching: find.byType(FxBoard),
          );
          if (film.evaluate().isNotEmpty) {
            expect(
              tester.getRect(film.first).shortestSide,
              greaterThan(20),
              reason: '$count joueur $i animation',
            );
          }
        }
      }

      expectVeil(DayState.unset);
      controller.setDay(DayState.night);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expectVeil(DayState.night);
      controller.addLife(controller.game.players.first.id, -4);
      await tester.pump();
      expect(find.byType(FxBoard), findsWidgets, reason: '$count $size');
      final struck = find.byType(FxBoard).first;
      expect(tester.getRect(struck).shortestSide, greaterThan(20));
      controller.setDay(DayState.day);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expectVeil(DayState.day);
    }

    await check(2, const Size(360, 800));
    await check(2, const Size(1280, 800));
    await check(3, const Size(390, 844));
    await check(3, const Size(1280, 800));
    await check(4, const Size(360, 800));
    await check(4, const Size(800, 360));
    await check(4, const Size(1280, 800));
    await check(5, const Size(900, 1400));
    await check(6, const Size(360, 800));
    await check(6, const Size(1280, 800));
    await check(8, const Size(900, 1600));
  });

  testWidgets('5 à 8 joueurs gardent le même plateau, empilé', (tester) async {
    for (final count in [5, 6, 8]) {
      final controller = GameController(
        game: Game.start(
          playerCount: count,
          names: [for (var i = 1; i <= count; i++) 'Joueur $i'],
        ),
      );
      addTearDown(controller.dispose);
      for (final size in const [
        Size(360, 800),
        Size(800, 360),
        Size(1280, 800),
      ]) {
        await pumpTable(tester, size, controller);
      final error = tester.takeException();
      if (error != null) {
        final tiny = RegExp(r'overflowed by 0\.\d+ pixels').hasMatch('$error');
        expect(tiny, isTrue, reason: '$count joueurs : $error');
      }
      expect(find.text('Mes PV'), findsWidgets);
      expect(find.text('Tous adv.'), findsNothing);
      expect(find.text('Infligé'), findsNothing);
      expect(find.text('Cdt'), findsWidgets);
      expect(find.text('Cdt Joueur 2'), findsNothing);
      expect(find.text('−5'), findsWidgets);
      expect(find.text('+5'), findsWidgets);
      }
    }
  });

  testWidgets('écran tactile : empilé, téléphone, ou 4 quarts', (tester) async {
    Future<void> pick(String label) async {
      await tester.tap(find.byTooltip('Disposition de l’écran'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(label).last);
      await tester.pump();
    }

    void noOverflow(Object? error, String why) {
      if (error == null) return;
      final tiny = RegExp(r'overflowed by 0\.\d+ pixels').hasMatch('$error');
      expect(tiny, isTrue, reason: '$why : $error');
    }

    final four = GameController(
      game: Game.start(
        playerCount: 4,
        names: const ['Ana', 'Bo', 'Célia', 'Dan'],
      ),
    );
    addTearDown(four.dispose);
    for (final size in const [Size(360, 800), Size(1280, 800)]) {
      await pumpTable(tester, size, four);
      await pick('4 écrans');
      noOverflow(tester.takeException(), '4 écrans $size');
      expect(find.text('Mes PV'), findsWidgets);
      await pick('Comptes empilés');
      noOverflow(tester.takeException(), 'empilés $size');
      expect(find.text('Mes PV'), findsWidgets);
      expect(find.text('Cdt'), findsWidgets);
      expect(find.text('Cdt Bo'), findsNothing);
      await pick('Façon téléphone');
      noOverflow(tester.takeException(), 'téléphone $size');
    }

    final picked = GameController(
      game: Game.start(
        playerCount: 4,
        names: const ['Ana', 'Bo', 'Celia', 'Dan'],
      ),
    );
    addTearDown(picked.dispose);
    await pumpTable(
      tester,
      const Size(1280, 800),
      picked,
      selfScoring: true,
    );
    expect(find.text('Cdt'), findsWidgets);
    expect(find.text('Cdt Celia'), findsNothing);
    final anaPanel = find.ancestor(
      of: find.text('Ana'),
      matching: find.byType(PlayerPanel),
    ).first;
    await tester.tap(
      find.descendant(of: anaPanel, matching: find.text('Cdt')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Cdt Celia'), findsOneWidget);
    await tester.tap(find.text('Cdt Celia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Cdt Celia'), findsOneWidget);
    expect(find.text('Cdt Bo'), findsNothing);
    noOverflow(tester.takeException(), 'choix commandant');

    final eight = GameController(
      game: Game.start(
        playerCount: 8,
        names: [for (var i = 1; i <= 8; i++) 'Joueur $i'],
      ),
    );
    addTearDown(eight.dispose);
    for (final size in const [Size(800, 600), Size(1280, 800)]) {
      await pumpTable(tester, size, eight);
      noOverflow(tester.takeException(), '8 liste $size');
      expect(find.text('Mes PV'), findsWidgets);
      expect(find.text('Infligé'), findsNothing);
      expect(find.text('Cdt'), findsWidgets);
      expect(find.text('Cdt Joueur 2'), findsNothing);
      await pick('En cercle');
      noOverflow(tester.takeException(), '8 cercle $size');
      expect(find.text('Mes PV'), findsWidgets);
      expect(find.text('Tous adv.'), findsNothing);
      expect(find.text('Infligé'), findsNothing);
      expect(find.text('Cdt'), findsWidgets);
      expect(find.text('Cdt Joueur 2'), findsNothing);
      expect(find.text('−5'), findsWidgets);
    }

    final two = GameController(
      game: Game.start(
        playerCount: 2,
        names: const ['Joueur 1', 'Joueur 2'],
      ),
    );
    addTearDown(two.dispose);
    await pumpTable(tester, const Size(800, 1200), two);
    await pick('Comptes empilés');
    noOverflow(tester.takeException(), 'duel empilé');
    expect(find.text('Mes PV'), findsWidgets);
    await pick('Façon téléphone');
    noOverflow(tester.takeException(), 'duel téléphone');
  });

  testWidgets('3 joueurs : un en face, deux collés en bas', (tester) async {
    final three = GameController(
      game: Game.start(
        playerCount: 3,
        names: const ['Ana', 'Bo', 'Célia'],
      ),
    );
    addTearDown(three.dispose);

    Future<void> expectFacing(Size size) async {
      await pumpTable(tester, size, three);
      final error = tester.takeException();
      if (error != null) {
        final tiny = RegExp(r'overflowed by 0\.\d+ pixels').hasMatch('$error');
        expect(tiny, isTrue, reason: '$size : $error');
      }
      final finder = find.byType(PlayerPanel);
      expect(finder, findsNWidgets(3));
      final rects = [
        for (var i = 0; i < 3; i++) tester.getRect(finder.at(i)),
      ]..sort((a, b) => a.top.compareTo(b.top));
      final top = rects.first;
      final lower = rects.sublist(1)..sort((a, b) => a.left.compareTo(b.left));
      expect(top.bottom, lessThanOrEqualTo(lower[0].top));
      expect(lower[1].top, closeTo(lower[0].top, 2));
      expect((lower[1].left - lower[0].right).abs(), lessThan(2));
      expect(top.left, closeTo(lower[0].left, 2));
      expect(top.right, closeTo(lower[1].right, 2));
    }

    await expectFacing(const Size(360, 800));
    await expectFacing(const Size(800, 360));
    await expectFacing(const Size(1280, 800));
  });

  testWidgets('3 joueurs : table ronde sur grand écran', (tester) async {
    final three = GameController(
      game: Game.start(
        playerCount: 3,
        names: const ['Ana', 'Bo', 'Célia'],
      ),
    );
    addTearDown(three.dispose);

    await pumpTable(tester, const Size(360, 800), three);
    await tester.tap(find.byTooltip('Disposition de l’écran'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Table ronde'), findsNothing);
    await tester.tapAt(const Offset(8, 700));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await pumpTable(tester, const Size(1280, 800), three);
    await tester.tap(find.byTooltip('Disposition de l’écran'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Table ronde'), findsOneWidget);
    await tester.tap(find.text('Table ronde'));
    await tester.pump();
    final error = tester.takeException();
    if (error != null) {
      final tiny = RegExp(r'overflowed by 0\.\d+ pixels').hasMatch('$error');
      expect(tiny, isTrue, reason: '$error');
    }
    expect(find.text('Ana'), findsWidgets);
    expect(find.text('Bo'), findsWidgets);
    expect(find.text('Célia'), findsWidgets);
    expect(find.text('Mes PV'), findsWidgets);
    expect(find.text('Cdt'), findsWidgets);
    expect(find.text('Cdt Bo'), findsNothing);
    final minus = find.text('−');
    expect(minus, findsWidgets);
    var changed = false;
    for (var i = 0; i < tester.widgetList(minus).length; i++) {
      await tester.tap(minus.at(i), warnIfMissed: false);
      await tester.pump();
      if (three.game.players.any((player) => player.life != 40)) {
        changed = true;
        break;
      }
    }
    expect(changed, isTrue);
  });

  testWidgets('3 joueurs : liste droite selon l’écran', (tester) async {
    final three = GameController(
      game: Game.start(
        playerCount: 3,
        names: const ['Ana', 'Bo', 'Célia'],
      ),
    );
    addTearDown(three.dispose);

    Future<void> openLine(Size size) async {
      await pumpTable(tester, size, three);
      await tester.tap(find.byTooltip('Disposition de l’écran'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await openLine(const Size(360, 800));
    expect(find.text('Liste droite'), findsNothing);
    await tester.tapAt(const Offset(8, 700));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await openLine(const Size(1280, 800));
    expect(find.text('Liste droite'), findsOneWidget);
    await tester.tap(find.text('Liste droite'));
    await tester.pump();
    final wideError = tester.takeException();
    if (wideError != null) {
      expect(
        RegExp(r'overflowed by 0\.\d+ pixels').hasMatch('$wideError'),
        isTrue,
        reason: '$wideError',
      );
    }
    final ana = tester.getCenter(find.text('Ana').first);
    final bo = tester.getCenter(find.text('Bo').first);
    final celia = tester.getCenter(find.text('Célia').first);
    expect(bo.dx, greaterThan(ana.dx + 200));
    expect(celia.dx, greaterThan(bo.dx + 200));
    expect((ana.dy - bo.dy).abs(), lessThan(80));

    await openLine(const Size(800, 1280));
    final lineItems = find.text('Liste droite');
    expect(lineItems, findsWidgets);
    await tester.tap(lineItems.last);
    await tester.pump();
    final tallError = tester.takeException();
    if (tallError != null) {
      expect(
        RegExp(r'overflowed by 0\.\d+ pixels').hasMatch('$tallError'),
        isTrue,
        reason: '$tallError',
      );
    }
    final top = tester.getCenter(find.text('Ana').first);
    final mid = tester.getCenter(find.text('Bo').first);
    final bottom = tester.getCenter(find.text('Célia').first);
    expect(mid.dy, greaterThan(top.dy + 200));
    expect(bottom.dy, greaterThan(mid.dy + 200));
    expect((top.dx - mid.dx).abs(), lessThan(80));
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
    final anaPanel = find.ancestor(
      of: find.text('Ana'),
      matching: find.byType(PlayerPanel),
    ).first;
    await tester.tap(find.descendant(of: anaPanel, matching: find.text('Cdt')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Cdt Bo · Kraum'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(ValueKey('chip-minus-${ana.id}-${kraum.id}')));
    await tester.pump();
    expect(controller.playerById(ana.id).life, before - 1);
    expect(controller.playerById(ana.id).damageTaken[kraum.id], 1);
  });

  testWidgets('table 1v1 : − sur mon commandant retire les PV adversaire', (
    tester,
  ) async {
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
    // Siège J2 → son commandant ; − enlève 1 vie à J1 et compte 1/21.
    await tester.tap(find.byKey(ValueKey('chip-minus-${j1.id}-${cdt2.id}')));
    await tester.pump();
      expect(controller.playerById(j1.id).life, beforeJ1 - 1);
      expect(controller.playerById(j2.id).life, beforeJ2);
      expect(controller.playerById(j1.id).damageTaken[cdt2.id], 1);
  });

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
      find
          .descendant(
            of: find.byKey(ValueKey('life-pad-${ana.id}-${ana.id}')),
            matching: find.byType(Text),
          )
          .first,
    );
    expect(lifeText.style?.color, lifeBandColor(LifeBand.critical));
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

  testWidgets('commander à 2 et duel commander montrent leurs sièges', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Game? started;
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(
          settings: AppSettings.defaults,
          group: null,
          resumeLabel: null,
          onStart: (game) => started = game,
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

    expect(find.text('Joueurs (2–12)'), findsOneWidget);
    expect(find.byKey(const ValueKey('player-count-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-count-1')), findsNothing);
    expect(find.byKey(const ValueKey('player-count-8')), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(8));
    expect(find.text('Commander à deux'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('player-count-2')));
    await tester.tap(find.byKey(const ValueKey('player-count-2')));
    await tester.pumpAndSettle();
    expect(find.text('Commander à deux'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));

    await tester.ensureVisible(find.textContaining('Lancer'));
    await tester.tap(find.textContaining('Lancer'));
    await tester.pump();
    expect(started!.format, MatchFormat.commander);
    expect(started!.players, hasLength(2));
    expect(started!.startingLife, 40);
    expect(started!.trackCommanderDamage, isTrue);

    await tester.ensureVisible(find.text('Duel Commander'));
    await tester.tap(find.text('Duel Commander'));
    await tester.pumpAndSettle();
    expect(find.text('Duel Commander · 2 joueurs'), findsOneWidget);
    expect(find.text('Joueurs (2)'), findsOneWidget);
    expect(find.byKey(const ValueKey('player-count-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-count-3')), findsNothing);
    expect(find.byKey(const ValueKey('player-count-4')), findsNothing);
    expect(find.textContaining('20 PV'), findsWidgets);
    expect(find.byType(TextField), findsNWidgets(4));

    await tester.ensureVisible(find.textContaining('Lancer'));
    await tester.tap(find.textContaining('Lancer'));
    await tester.pump();
    expect(started!.format, MatchFormat.duel);
    expect(started!.players, hasLength(2));
    expect(started!.startingLife, 20);
    expect(started!.trackCommanderDamage, isFalse);
    expect(started!.trackCommanderTax, isTrue);
    expect(tester.takeException(), isNull);
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

  testWidgets('l’aide reste dans l’écran d’un téléphone', (tester) async {
    const message =
        'Format le plus répandu : un commandant légendaire, deck de 100 cartes, '
        '40 points de vie. 21 dégâts de combat du même commandant éliminent. '
        'Aussi appelé EDH. La table classique est à 4, mais on peut jouer à 2 '
        'avec exactement ces règles. Le Duel Commander est un autre format.';

    Future<void> open(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(
            body: Center(
              child: HelpTip(
                title: 'Commander (EDH)',
                message: message,
                showIcon: true,
                child: Text('Format'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(find.text('Commander (EDH). $message'), findsOneWidget);
      expect(find.text('Compris'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Compris'));
      await tester.pumpAndSettle();
    }

    await open(const Size(360, 740));
    await open(const Size(740, 360));
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('l’aide du joueur d’en face est tournée avec son siège', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    const message = 'Le monarque pioche une carte en plus.';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
          body: SeatReading(
            quarterTurns: 2,
            child: Center(
              child: HelpTip(
                title: 'Monarque',
                message: message,
                showIcon: true,
                child: Text('Monarque'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(find.text('Monarque. $message'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Monarque. $message'),
        matching: find.byWidgetPredicate(
          (widget) => widget is RotatedBox && widget.quarterTurns == 2,
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('3 joueurs choisissent le commandant qui les attaque', (
    tester,
  ) async {
    final three = GameController(
      game: Game.start(
        playerCount: 3,
        names: const ['Ana', 'Bo', 'Celia'],
      ),
    );
    addTearDown(three.dispose);
    await pumpTable(tester, const Size(1280, 800), three);
    expect(find.text('Cdt'), findsWidgets);
    expect(find.text('Cdt Celia'), findsNothing);
    expect(find.byType(CommanderEmblem), findsWidgets);
    expect(find.text('2e'), findsNothing);
    final anaPanel = find.ancestor(
      of: find.text('Ana'),
      matching: find.byType(PlayerPanel),
    ).first;
    await tester.tap(
      find.descendant(of: anaPanel, matching: find.text('Cdt')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Cdt Celia'), findsOneWidget);
    await tester.tap(find.text('Cdt Celia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Cdt Celia'), findsOneWidget);
    expect(find.text('Cdt Bo'), findsNothing);
    expect(find.byIcon(Icons.visibility), findsNothing);
  });

  testWidgets('la couronne inscrit deux commandants', (tester) async {
    final three = GameController(
      game: Game.start(
        playerCount: 3,
        names: const ['Ana', 'Bo', 'Celia'],
      ),
    );
    addTearDown(three.dispose);
    await pumpTable(tester, const Size(1280, 800), three);
    final anaPanel = find
        .ancestor(of: find.text('Ana'), matching: find.byType(PlayerPanel))
        .first;
    await tester.tap(
      find.descendant(of: anaPanel, matching: find.byType(CommanderEmblem)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mon commandant'), findsOneWidget);
    await tester.tap(find.text('Deux'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Atraxa');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final ana = three.game.players.firstWhere((player) => player.name == 'Ana');
    expect(ana.commanders, hasLength(2));
    expect(ana.commanders[0].name, 'Atraxa');
    expect(ana.commanders[1].name, 'Cdt 2');
    final boPanel = find
        .ancestor(of: find.text('Bo'), matching: find.byType(PlayerPanel))
        .first;
    await tester.tap(find.descendant(of: boPanel, matching: find.text('Cdt')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Cdt Ana · Atraxa'), findsOneWidget);
    expect(find.text('Cdt Ana · 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('l’aide débutant explique le poison dans la roue crantée', (
    tester,
  ) async {
    final controller = sample();
    addTearDown(controller.dispose);
    await pumpTable(tester, const Size(800, 800), controller, tips: true);
    await tester.tap(find.byIcon(Icons.settings).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ce n’est pas une perte de vie'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsWidgets);
    await tester.tap(find.byIcon(Icons.info_outline).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Relancer ce commandant'), findsOneWidget);
    expect(find.text('Compris'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le monarque confirme sa pioche avant de passer', (tester) async {
    final controller = sample();
    addTearDown(controller.dispose);
    final active = controller.game.players[controller.game.activeIndex];
    controller.toggleMonarch(active.id);
    await pumpTable(tester, const Size(800, 800), controller);
    await tester.tap(find.text('Fin de tour'));
    await tester.pumpAndSettle();
    expect(find.text('Étape de fin'), findsOneWidget);
    expect(controller.game.activeIndex, 0);
    await tester.tap(find.text('Pas encore'));
    await tester.pumpAndSettle();
    expect(controller.game.activeIndex, 0);
    await tester.tap(find.text('Fin de tour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oui, carte piochée'));
    await tester.pumpAndSettle();
    expect(controller.game.activeIndex, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chacun retire ses propres points', (tester) async {
    Future<void> check(GameController controller, Size size) async {
      await pumpTable(
        tester,
        size,
        controller,
        selfScoring: true,
      );
      expect(find.text('Tous adv.'), findsNothing);
      expect(find.text('Choisis un joueur'), findsNothing);
      expect(find.text('Fin de tour'), findsOneWidget);
      final players = controller.game.players;
      for (final seat in players) {
        for (final other in players) {
          final key = ValueKey('life-pad-${seat.id}-${other.id}');
          expect(
            find.byKey(key),
            seat.id == other.id ? findsWidgets : findsNothing,
          );
        }
      }
      final before = [
        for (final player in controller.game.players) player.life,
      ];
      await tester.tap(find.text('−').first);
      await tester.pump();
      final after = [
        for (final player in controller.game.players) player.life,
      ];
      final changed = [
        for (var i = 0; i < before.length; i++)
          if (after[i] != before[i]) i,
      ];
      expect(changed, hasLength(1));
      expect(after[changed.single], before[changed.single] - 1);
      expect(tester.takeException(), isNull);
    }

    await check(sample(), const Size(360, 800));
    await check(
      GameController(game: Game.start(playerCount: 2, names: const ['Ana', 'Bo'])),
      const Size(400, 800),
    );
  });

  testWidgets('les options choisies restent en Mes pertes', (tester) async {
    for (final count in [2, 4, 8]) {
      final controller = GameController(
        game: Game.start(playerCount: count),
      );
      addTearDown(controller.dispose);
      final first = controller.game.players.first;
      controller.toggleMonarch(first.id);
      controller.bumpStat(first.id, Stat.poison, 3);
      controller.bumpStat(first.id, Stat.energy, 2);
      controller.bumpMana(first.id, 'U', 4);
      controller.addCustom(first.id, 'Indices');
      final counter = controller.playerById(first.id).custom.first;
      controller.bumpCustom(first.id, counter.id, 2);
      await pumpTable(
        tester,
        const Size(360, 800),
        controller,
        selfScoring: true,
      );
      final panel = find.ancestor(
        of: find.byKey(ValueKey('life-pad-${first.id}-${first.id}')),
        matching: find.byType(PlayerPanel),
      );
      expect(
        find.descendant(of: panel, matching: find.bySemanticsLabel('Monarque')),
        findsWidgets,
      );
      expect(
        find.descendant(of: panel, matching: find.bySemanticsLabel('Poison 3')),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: panel,
          matching: find.bySemanticsLabel('Énergie 2'),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: panel,
          matching: find.bySemanticsLabel('Mana bleu 4'),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(of: panel, matching: find.bySemanticsLabel('Indices 2')),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('les réglages de la table s’ouvrent sans choix d’affichage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final current = AppSettings.defaults;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SettingsSheet(
            settings: current,
            onChanged: (_) {},
            cast: CastTone.standard,
            onCast: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Affichage des points'), findsNothing);
    expect(find.text('Mes pertes'), findsNothing);
    expect(find.text('Adversaires'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Mémoire des commandants'),
      120,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Mémoire des commandants'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un téléphone relié donne l’écran à son siège', (tester) async {
    final controller = sample();
    addTearDown(controller.dispose);
    final link = TableLinkController();
    addTearDown(link.stop);
    await tester.runAsync(() => link.hostTable(controller.exportSession()));
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> show() {
      return tester.pumpWidget(
        MaterialApp(
          home: TableScreen(
            controller: controller,
            settings: AppSettings.defaults.copyWith(
              haptic: false,
              beginnerTips: false,
            ),
            onSettings: (_) {},
            onLeave: () {},
            onCoachDismissed: () {},
            link: link,
          ),
        ),
      );
    }

    await show();
    await tester.pump();
    expect(find.text('Ce téléphone joue quel siège ?'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('C’est moi').first);
    await tester.pump();
    expect(find.text('Mes PV'), findsOneWidget);
    final bo = controller.game.players[1].id;
    expect(find.byKey(ValueKey('rail-$bo')), findsOneWidget);
    expect(find.text('Bo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Bo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Mes PV'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    tester.view.physicalSize = const Size(800, 360);
    await tester.pump();
    expect(find.text('Mes PV'), findsWidgets);
    expect(find.byKey(ValueKey('rail-$bo')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
