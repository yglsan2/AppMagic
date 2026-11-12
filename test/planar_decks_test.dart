import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/planar_decks.dart';

void main() {
  test('nouvelle partie Planechase tire un vrai paquet de plans', () {
    final game = Game.start(planechase: true, playerCount: 4);
    expect(game.planes.length, officialPlanes.length);
    expect(game.currentPlaneChaos, isNotEmpty);
    expect(game.currentPlaneChaos, contains('Chaos'));
    expect(game.planes.where(isPhenomenon).length, 7);
  });

  test('résoudre un phénomène le retire du paquet', () {
    final game = Game.start(planechase: true, playerCount: 2);
    final controller = GameController(game: game);
    addTearDown(controller.dispose);
    game.planes.removeWhere((name) => name == 'Chaotic Aether');
    game.planes.insert(0, 'Chaotic Aether');
    game.planeIndex = 0;
    final before = game.planes.length;
    controller.planeswalk();
    expect(game.planes.contains('Chaotic Aether'), isFalse);
    expect(game.planes.length, before - 1);
  });

  test('Archenemy mélange les schémas officiels', () {
    final game = Game.start(archenemy: true, playerCount: 4);
    expect(game.schemes.length, officialSchemes.length);
    expect(game.currentSchemeEffect, isNotEmpty);
  });

  test('le dé planaire coûte plus cher et ne change pas de plan', () {
    final game = Game.start(planechase: true, playerCount: 2);
    final before = game.currentPlane;
    final controller = GameController(game: game);
    addTearDown(controller.dispose);
    final first = controller.rollPlanarDie(0);
    expect(first.face, PlanarFace.planeswalk);
    expect(first.cost, 0);
    expect(game.currentPlane, before);
    expect(game.planarRolls, 1);
    final second = controller.rollPlanarDie(1);
    expect(second.face, PlanarFace.chaos);
    expect(second.cost, 1);
    controller.rollPlanarDie(3);
    expect(game.planarRolls, 3);
    controller.nextTurn();
    expect(game.planarRolls, 0);
  });

  test('Bounty expose une carte de prime', () {
    final game = Game.start(bounty: true, playerCount: 4);
    expect(game.bounty, isTrue);
    expect(game.currentBounty.name, isNotEmpty);
    expect(game.currentBounty.reward, isNotEmpty);
  });
}
