import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/planar_decks.dart';

void main() {
  test('nouvelle partie Planechase tire un vrai paquet de plans', () {
    final game = Game.start(planechase: true, playerCount: 4);
    expect(game.planes.length, officialPlanes.length);
    expect(game.currentPlaneChaos, isNotEmpty);
    expect(game.currentPlaneChaos, contains('Chaos'));
  });

  test('Archenemy mélange les schémas officiels', () {
    final game = Game.start(archenemy: true, playerCount: 4);
    expect(game.schemes.length, officialSchemes.length);
    expect(game.currentSchemeEffect, isNotEmpty);
  });

  test('Bounty expose une carte de prime', () {
    final game = Game.start(bounty: true, playerCount: 4);
    expect(game.bounty, isTrue);
    expect(game.currentBounty.name, isNotEmpty);
    expect(game.currentBounty.reward, isNotEmpty);
  });
}
