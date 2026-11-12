import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/coach.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';

void main() {
  test('le coach ne parle que de ce qui est en jeu', () {
    final controller = GameController(
      game: Game.start(playerCount: 2, names: const ['Léa', 'Nico']),
    );
    final me = controller.game.players.first;
    expect(turnReminders(controller.game, me), isEmpty);

    controller.toggleMonarch(me.id);
    controller.toggleInitiative(me.id);
    me.rad = 2;
    me.poison = 8;
    me.commanders.first.casts = 2;
    me.treasure = 3;
    controller.game.dayState = DayState.night;

    final lines = turnReminders(controller.game, me).join('\n');
    expect(lines, contains('Initiative'));
    expect(lines, contains('Monarque'));
    expect(lines, contains('Radiation 2'));
    expect(lines, contains('Taxe : +4'));
    expect(lines, contains('Poison 8/'));
    expect(lines, contains('Trésors : 3'));
    expect(lines, isNot(contains('Il fait nuit')));
    expect(lines, isNot(contains('Énergie')));
  });
}
