import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/setup/setup_screen.dart';
import 'package:mtg_table/ui/sheets/settings_sheet.dart';
import 'package:mtg_table/ui/table/table_screen.dart';
import 'package:mtg_table/ui/widgets/help_tip.dart';
import 'package:mtg_table/ui/widgets/player_panel.dart';

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
      expect(find.text('Tous adv.'), findsWidgets);
      expect(find.text('Infligé'), findsWidgets);
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
      expect(find.text('Tous adv.'), findsWidgets);
      await pick('Façon téléphone');
      noOverflow(tester.takeException(), 'téléphone $size');
    }

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
      expect(find.text('Infligé'), findsWidgets);
      await pick('En cercle');
      noOverflow(tester.takeException(), '8 cercle $size');
      expect(find.text('Mes PV'), findsWidgets);
      expect(find.text('Tous adv.'), findsWidgets);
      expect(find.text('Infligé'), findsWidgets);
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
    // − enlève 1 point de commandant et 1 vie.
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
      expect(find.textContaining('1/21 · vie'), findsWidgets);
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

    expect(find.text('Joueurs (2–8)'), findsOneWidget);
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
      expect(find.text(message), findsOneWidget);
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
    expect(find.text(message), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text(message),
        matching: find.byWidgetPredicate(
          (widget) => widget is RotatedBox && widget.quarterTurns == 2,
        ),
      ),
      findsOneWidget,
    );
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
        of: find.byKey(ValueKey('pane-${first.id}')),
        matching: find.byType(PlayerPanel),
      );
      expect(
        find.descendant(of: panel, matching: find.text('Monarque')),
        findsWidgets,
      );
      expect(
        find.descendant(of: panel, matching: find.text('☠ 3')),
        findsWidgets,
      );
      expect(
        find.descendant(of: panel, matching: find.text('Énergie 2')),
        findsWidgets,
      );
      expect(
        find.descendant(of: panel, matching: find.text('U 4')),
        findsWidgets,
      );
      expect(
        find.descendant(of: panel, matching: find.text('Indices 2')),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('chaque profil choisit son affichage', (tester) async {
    final controller = sample();
    addTearDown(controller.dispose);
    await pumpTable(tester, const Size(1280, 800), controller);
    final ana = controller.game.players.first;
    final bo = controller.game.players[1];
    Finder panel(String id) => find.ancestor(
      of: find.byKey(ValueKey('pane-$id')),
      matching: find.byType(PlayerPanel),
    );

    await tester.tap(find.byKey(ValueKey('pane-${ana.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrer pour Ana'), findsOneWidget);
    await tester.tap(find.text('Mes pertes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2700));

    expect(
      find.descendant(of: panel(ana.id), matching: find.text('Reçu')),
      findsWidgets,
    );
    expect(
      find.descendant(of: panel(ana.id), matching: find.text('Infligé')),
      findsNothing,
    );
    expect(
      find.descendant(of: panel(bo.id), matching: find.text('Infligé')),
      findsWidgets,
    );
    expect(
      find.descendant(of: panel(bo.id), matching: find.text('Reçu')),
      findsNothing,
    );

    await tester.tap(find.byKey(ValueKey('pane-${ana.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer pour Ana'));
    await tester.pump();
    expect(find.textContaining('Préférence enregistrée pour Ana'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('l’affichage du téléphone se règle et reste remplaçable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppSettings current = AppSettings.defaults;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SettingsSheet(
            settings: current,
            onChanged: (next) => current = next,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Mes pertes'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Mes pertes'));
    await tester.pump();
    expect(current.scorePane, ScorePane.own);
    expect(current.paneNamed('Yann'), ScorePane.own);
    current = current.savingPane('Yann', ScorePane.foes);
    expect(current.paneNamed('Yann'), ScorePane.foes);
    expect(current.paneNamed('Bo'), ScorePane.own);
  });
}
