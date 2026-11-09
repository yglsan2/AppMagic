import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/seating.dart';

void main() {
  GameController pod({
    int players = 4,
    bool shared = false,
    MatchFormat format = MatchFormat.commander,
    int life = 40,
  }) {
    return GameController(
      game: Game.start(
        format: format,
        playerCount: players,
        startingLife: life,
        sharedLife: shared,
        names: [for (var i = 0; i < players; i++) 'P$i'],
        commanderNames: [
          for (var i = 0; i < players; i++)
            if (i == 1) ['Kraum', 'Tymna'] else ['Cmd$i'],
        ],
      ),
    );
  }

  test('un dégât de commandant retire 1 point de vie', () {
    final game = pod();
    final defender = game.game.players[0];
    final commander = game.game.players[1].commanders[0];
    game.addCommanderDamage(
      defenderId: defender.id,
      commanderId: commander.id,
      delta: 1,
    );
    expect(game.playerById(defender.id).life, 39);
    expect(game.playerById(defender.id).damageTaken[commander.id], 1);
  });

  test('les dégâts de commandant baissent toujours la vie', () {
    final game = pod();
    final defender = game.game.players[0];
    final commander = game.game.players[1].commanders.first;
    game.addCommanderDamage(
      defenderId: defender.id,
      commanderId: commander.id,
      delta: 3,
    );
    expect(game.playerById(defender.id).life, 37);
    expect(game.playerById(defender.id).damageTaken[commander.id], 3);
  });

  test('corriger les dégâts ne rend que la vie vraiment retirée', () {
    final game = pod();
    final defender = game.game.players[0];
    final commander = game.game.players[1].commanders.first;
    game.addCommanderDamage(
      defenderId: defender.id,
      commanderId: commander.id,
      delta: 3,
    );
    game.addCommanderDamage(
      defenderId: defender.id,
      commanderId: commander.id,
      delta: -10,
    );
    expect(game.playerById(defender.id).damageTaken[commander.id], 0);
    expect(game.playerById(defender.id).life, 40);
  });

  test('corriger sans drain préalable n’invente pas de PV', () {
    final game = pod();
    final defender = game.game.players[0];
    final commander = game.game.players[1].commanders.first;
    defender.damageTaken[commander.id] = 5;
    game.addCommanderDamage(
      defenderId: defender.id,
      commanderId: commander.id,
      delta: -5,
    );
    expect(game.playerById(defender.id).life, 40);
    expect(game.playerById(defender.id).damageTaken[commander.id], 0);
  });

  test('revenir à la table ne dépasse pas la vie de départ', () {
    final game = pod();
    final defender = game.game.players[0];
    final commander = game.game.players[1].commanders.first;
    game.addCommanderDamage(
      defenderId: defender.id,
      commanderId: commander.id,
      delta: 21,
    );
    expect(game.game.isDefeated(game.playerById(defender.id)), isTrue);
    expect(game.playerById(defender.id).life, 19);
    game.revivePlayer(defender.id);
    final after = game.playerById(defender.id);
    expect(game.game.isDefeated(after), isFalse);
    expect(after.damageTaken[commander.id], 20);
    expect(after.life, 20);
    expect(after.life, lessThanOrEqualTo(40));
    game.addCommanderDamage(
      defenderId: defender.id,
      commanderId: commander.id,
      delta: -20,
    );
    expect(game.playerById(defender.id).life, 40);
  });

  test('deux commandants sont suivis à part et 21 est létal', () {
    final game = pod();
    final defender = game.game.players[0];
    final first = game.game.players[1].commanders[0];
    final second = game.game.players[1].commanders[1];
    game.addCommanderDamage(
      defenderId: defender.id,
      commanderId: first.id,
      delta: 20,
    );
    game.addCommanderDamage(
      defenderId: defender.id,
      commanderId: second.id,
      delta: 20,
    );
    final player = game.playerById(defender.id);
    expect(player.damageTaken[first.id], 20);
    expect(player.damageTaken[second.id], 20);
    expect(game.game.commanderRemaining(player, first.id), 1);
    expect(game.game.commanderLethal(player), isFalse);
    game.addCommanderDamage(
      defenderId: defender.id,
      commanderId: first.id,
      delta: 1,
    );
    final after = game.playerById(defender.id);
    expect(game.game.commanderRemaining(after, first.id), 0);
    expect(game.game.commanderLethal(after), isTrue);
    expect(game.game.isDefeated(after), isTrue);
  });

  test('changer le nombre de joueurs ajoute et retire', () {
    final game = pod(players: 4);
    game.setPlayerCount(6);
    expect(game.game.players, hasLength(6));
    game.setPlayerCount(3);
    expect(game.game.players, hasLength(3));
  });

  test('0 point de vie élimine', () {
    final game = pod();
    final id = game.game.players[0].id;
    game.setLife(id, 0);
    expect(game.game.isDefeated(game.playerById(id)), isTrue);
  });

  test('retirer un commandant efface ses dégâts', () {
    final game = pod();
    final defender = game.game.players[0];
    final commander = game.game.players[1].commanders.first;
    game.addCommanderDamage(
      defenderId: defender.id,
      commanderId: commander.id,
      delta: 4,
    );
    game.removeCommander(commander.id);
    expect(
      game.playerById(defender.id).damageTaken.containsKey(commander.id),
      isFalse,
    );
    expect(game.game.players[1].commanders, hasLength(1));
  });

  test('retirer le dernier commandant garde au moins un', () {
    final game = pod();
    final owner = game.game.players[1];
    expect(owner.commanders, hasLength(2));
    game.removeLastCommander(owner.id);
    expect(game.playerById(owner.id).commanders, hasLength(1));
    game.removeLastCommander(owner.id);
    expect(game.playerById(owner.id).commanders, hasLength(1));
  });

  test('revanche remonte la manche sans changer le siège actif', () {
    final game = pod();
    game.setActive(2);
    game.addLife(game.game.players[0].id, -5);
    game.rematch();
    expect(game.game.roundNumber, 2);
    expect(game.game.activeIndex, 2);
    expect(game.playerById(game.game.players[0].id).life, 40);
  });

  test('remise à zéro repart manche 1 au premier siège', () {
    final game = pod();
    game.setActive(2);
    game.rematch();
    game.addLife(game.game.players[0].id, -3);
    game.resetRound();
    expect(game.game.roundNumber, 1);
    expect(game.game.activeIndex, 0);
    expect(game.playerById(game.game.players[0].id).life, 40);
  });

  test('mélanger les places garde le joueur actif', () {
    final game = pod();
    final activeId = game.game.players[1].id;
    game.setActive(1);
    game.shuffleSeats();
    expect(game.game.players[game.game.activeIndex].id, activeId);
    expect(game.game.players.map((p) => p.id).toSet(), hasLength(4));
  });

  test('annuler et rétablir restaurent vie et dégâts', () {
    final game = pod();
    final defender = game.game.players[0];
    final commander = game.game.players[2].commanders.first;
    game.addCommanderDamage(
      defenderId: defender.id,
      commanderId: commander.id,
      delta: 2,
    );
    game.undo();
    expect(game.playerById(defender.id).life, 40);
    expect(game.playerById(defender.id).damageTaken[commander.id] ?? 0, 0);
    game.redo();
    expect(game.playerById(defender.id).life, 38);
    expect(game.playerById(defender.id).damageTaken[commander.id], 2);
  });

  test('la vitesse s’arrête à 4, comme dans les règles', () {
    final game = pod();
    final id = game.game.players[0].id;
    game.bumpStat(id, Stat.speed, 9);
    expect(game.playerById(id).speed, 4);
    game.setRing(id, 8);
    expect(game.playerById(id).ring, 4);
    expect(statPlayOrder.first, Stat.poison);
    expect(statPlayOrder[1], Stat.treasure);
    expect(statLabel(Stat.storm), 'Tempête');
  });

  test('10 poison élimine, 9 non', () {
    final game = pod();
    final id = game.game.players[0].id;
    game.bumpStat(id, Stat.poison, 9);
    expect(game.game.poisonLethal(game.playerById(id)), isFalse);
    game.bumpStat(id, Stat.poison, 1);
    expect(game.game.poisonLethal(game.playerById(id)), isTrue);
  });

  test('le tour suivant vide mana et storm puis avance la manche', () {
    final game = pod();
    final first = game.game.players[0].id;
    game.bumpMana(first, 'U', 3);
    game.bumpStat(first, Stat.storm, 4);
    game.bumpMana(game.game.players[1].id, 'R', 2);
    game.nextTurn();
    expect(game.playerById(first).mana['U'], 0);
    expect(game.playerById(first).storm, 0);
    expect(game.playerById(game.game.players[1].id).mana['R'], 2);
    for (var i = 0; i < 3; i++) {
      game.nextTurn();
    }
    expect(game.game.activeIndex, 0);
    expect(game.game.roundNumber, 2);
    expect(game.game.turnCount, 5);
    expect(game.playerById(first).mana['U'], 0);
    expect(game.playerById(first).storm, 0);
  });

  test('la couronne suit les blessures de combat et le départ', () {
    final game = pod();
    final monarch = game.game.players[0];
    final attacker = game.game.players[1];
    final commander = attacker.commanders.first;
    expect(game.game.monarchId, isNull);
    game.toggleMonarch(monarch.id);
    expect(game.game.monarchId, monarch.id);

    game.addLife(monarch.id, -1);
    expect(game.game.monarchId, monarch.id);
    expect(game.combatAsk?.attackerId, isNull);
    game.answerCombat(null);
    expect(game.combatAsk, isNull);
    game.addLife(monarch.id, -1);
    expect(game.combatAsk, isNull);

    game.nextTurn();
    game.addLife(monarch.id, -1, dealtBy: attacker.id);
    expect(game.combatAsk?.attackerId, attacker.id);
    game.answerCombat(attacker.id);
    expect(game.game.monarchId, attacker.id);
    expect(game.crownChange?.lostId, monarch.id);
    expect(game.crownChange?.gainedId, attacker.id);

    game.toggleMonarch(monarch.id);
    game.addCommanderDamage(
      defenderId: monarch.id,
      commanderId: commander.id,
      delta: 1,
    );
    expect(game.game.monarchId, attacker.id);
    game.undo();
    expect(game.game.monarchId, monarch.id);

    game.addLife(monarch.id, -80);
    expect(game.game.monarchId, attacker.id);
  });

  test('l’initiative suit le commandant et le départ', () {
    final game = pod();
    final holder = game.game.players[0];
    final attacker = game.game.players[1];
    final commander = attacker.commanders.first;
    game.toggleInitiative(holder.id);
    game.addCommanderDamage(
      defenderId: holder.id,
      commanderId: commander.id,
      delta: 1,
    );
    expect(game.game.initiativeId, attacker.id);
    game.undo();
    expect(game.game.initiativeId, holder.id);

    game.removePlayer(holder.id);
    expect(game.game.initiativeId, attacker.id);
  });

  test('le poison du géant à deux têtes est à 15', () {
    final game = pod(players: 4, shared: true, format: MatchFormat.twoHeaded);
    game.applyRules(AppSettings.defaults);
    expect(game.game.poisonThreshold, 15);
    game.applyRules(AppSettings.defaults.copyWith(poisonThreshold: 12));
    expect(game.game.poisonThreshold, 12);
  });

  test('un seul monarque à la fois', () {
    final game = pod();
    final a = game.game.players[0].id;
    final b = game.game.players[1].id;
    game.toggleMonarch(a);
    game.toggleMonarch(b);
    expect(game.game.monarchId, b);
    game.toggleMonarch(b);
    expect(game.game.monarchId, isNull);
  });

  test('la vie de Two-Headed Giant est partagée', () {
    final game = pod(
      players: 4,
      shared: true,
      format: MatchFormat.twoHeaded,
      life: 30,
    );
    final teamA = game.game.players[0];
    final mate = game.game.players[1];
    final other = game.game.players[2];
    game.addLife(teamA.id, -2);
    expect(game.playerById(teamA.id).life, 28);
    expect(game.playerById(mate.id).life, 28);
    expect(game.playerById(other.id).life, 30);
    final commander = mate.commanders.first;
    game.addCommanderDamage(
      defenderId: other.id,
      commanderId: commander.id,
      delta: 1,
    );
    expect(game.playerById(other.id).life, 29);
    expect(game.playerById(game.game.players[3].id).life, 29);
    expect(game.playerById(teamA.id).life, 28);
  });

  test('la sauvegarde json survit à un aller-retour', () {
    final game = pod();
    final defender = game.game.players[0];
    game.addLife(defender.id, -5);
    final restored = Game.fromJson(game.game.toJson());
    expect(restored.playerById(defender.id).life, 35);
    expect(restored.players[1].commanders, hasLength(2));
  });

  test('les jetons de commandant portent le bon nom', () {
    final game = pod();
    final owner = game.game.players[1];
    expect(commanderChipLabel(owner, owner.commanders[0]), 'Cdt P1 · Kraum');
    expect(commanderChipLabel(owner, owner.commanders[1]), 'Cdt P1 · Tymna');
    final solo = game.game.players[0];
    expect(commanderChipLabel(solo, solo.commanders.first), 'Cdt Cmd0');
  });

  test('le duel commander ne suit pas les dégâts par défaut', () {
    final game = Game.start(format: MatchFormat.duel, playerCount: 2);
    expect(game.trackCommanderDamage, isFalse);
    expect(game.trackCommanderTax, isTrue);
    expect(game.startingLife, 20);
  });

  test('les taps PV rapides fusionnent en un seul décompte', () {
    final game = pod();
    final p = game.game.players[0];
    game.addLife(p.id, -1);
    game.addLife(p.id, -1);
    game.addLife(p.id, -1);
    expect(game.lifeLog, hasLength(1));
    expect(game.lifeLog.first.delta, -3);
    expect(game.lifeLog.first.from, 40);
    expect(game.lifeLog.first.to, 37);
    game.addLife(p.id, 2);
    expect(game.lifeLog, hasLength(2));
    expect(game.lifeLog.first.delta, 2);
  });

  test('les taps Cdt rapides fusionnent et gardent l’historique', () {
    final game = pod();
    final defender = game.game.players[0];
    final commander = game.game.players[1].commanders[0];
    game.addCommanderDamage(
      defenderId: defender.id,
      commanderId: commander.id,
      delta: 1,
    );
    game.addCommanderDamage(
      defenderId: defender.id,
      commanderId: commander.id,
      delta: 1,
    );
    game.addCommanderDamage(
      defenderId: defender.id,
      commanderId: commander.id,
      delta: 1,
    );
    expect(game.cmdDamageLog, hasLength(1));
    expect(game.cmdDamageLog.first.delta, 3);
    expect(game.cmdDamageLog.first.toTaken, 3);
    expect(game.playerById(defender.id).life, 37);
    final recent = game.recentCmdDamageChangesFor(
      defenderId: defender.id,
      commanderId: commander.id,
    );
    expect(recent, hasLength(1));
    expect(recent.first.deltaLabel, '+3');
  });

  test('places téléphone et tablette', () {
    expect(phonePlan(1).south, [0]);
    expect(phonePlan(1).north, isEmpty);
    expect(phonePlan(2).south, [0]);
    expect(phonePlan(2).north, [1]);
    expect(phonePlan(3).south, [0, 2]);
    expect(phonePlan(3).north, [1]);
    expect(phonePlan(4).south, [0, 3]);
    expect(phonePlan(4).north, [1, 2]);
    expect(phonePlan(5).south, [0, 4, 3]);
    expect(phonePlan(5).north, [1, 2]);
    expect(phonePlan(6).south, [0, 5, 4]);
    expect(phonePlan(6).north, [1, 2, 3]);

    final four = tabletPlan(4);
    expect(four.south, [0]);
    expect(four.westTopToBottom, [1]);
    expect(four.north, [2]);
    expect(four.eastTopToBottom, [3]);

    final five = tabletPlan(5);
    expect(five.south, [0, 4]);
    expect(five.westTopToBottom, [1]);
    expect(five.north, [2]);
    expect(five.eastTopToBottom, [3]);

    final six = tabletPlan(6);
    expect(six.south, [0, 5]);
    expect(six.westTopToBottom, [1]);
    expect(six.north, [2, 3]);
    expect(six.eastTopToBottom, [4]);

    final poker7 = pokerPlan(7);
    expect(poker7.westTopToBottom, hasLength(1));
    expect(poker7.eastTopToBottom, hasLength(1));
    expect(poker7.south.length + poker7.north.length, 5);

    final poker8 = pokerPlan(8);
    expect(poker8.westTopToBottom, hasLength(1));
    expect(poker8.eastTopToBottom, hasLength(1));
    expect(
      poker8.south.length +
          poker8.north.length +
          poker8.westTopToBottom.length +
          poker8.eastTopToBottom.length,
      8,
    );

    final eight = tabletPlan(8);
    expect(eight.south, [0, 7]);
    expect(eight.westTopToBottom, [2, 1]);
    expect(eight.north, [3, 4]);
    expect(eight.eastTopToBottom, [5, 6]);

    final duel = phonePlan(2);
    expect(facingSeatIndex(duel, 0), 1);
    expect(facingSeatIndex(duel, 1), 0);
  });

  test('plusieurs cibles perdent les mêmes points en un seul annuler', () {
    final game = pod();
    final ids = game.game.players.map((player) => player.id).toList();
    game.addLifeMany(ids.skip(1), -2);
    expect(game.playerById(ids[0]).life, 40);
    expect(game.playerById(ids[1]).life, 38);
    expect(game.playerById(ids[2]).life, 38);
    expect(game.playerById(ids[3]).life, 38);
    game.addLifeMany(ids, -3);
    expect(game.playerById(ids[0]).life, 37);
    expect(game.playerById(ids[1]).life, 35);
    game.undo();
    expect(game.playerById(ids[0]).life, 40);
    expect(game.playerById(ids[1]).life, 38);

    final commander = game.game.players[0].commanders.first;
    game.addCommanderDamageMany(
      defenderIds: ids.skip(1),
      commanderId: commander.id,
      delta: 2,
    );
    expect(game.playerById(ids[1]).life, 36);
    expect(game.playerById(ids[1]).damageTaken[commander.id], 2);
    expect(game.playerById(ids[2]).damageTaken[commander.id], 2);
    expect(game.playerById(ids[0]).damageTaken[commander.id] ?? 0, 0);
    game.undo();
    expect(game.playerById(ids[1]).life, 38);
    expect(game.playerById(ids[1]).damageTaken[commander.id] ?? 0, 0);
  });

  test('le chronomètre reste éteint tant qu’on ne l’active pas', () {
    final game = Game.start();
    expect(game.timersEnabled, isFalse);
    final legacy = Map<String, dynamic>.from(game.toJson())
      ..remove('timersEnabled');
    expect(Game.fromJson(legacy).timersEnabled, isFalse);
    final settings = Map<String, dynamic>.from(AppSettings.defaults.toJson())
      ..remove('timersEnabled');
    expect(AppSettings.fromJson(settings).timersEnabled, isFalse);

    final controller = GameController(game: game);
    expect(controller.turnOverAlert, isFalse);
    controller.applyRules(
      AppSettings.defaults.copyWith(timersEnabled: true),
    );
    expect(controller.game.timersEnabled, isTrue);
    controller.applyRules(AppSettings.defaults);
    expect(controller.game.timersEnabled, isFalse);
  });

  test('une préférence d’affichage suit le pseudo', () {
    final saved = AppSettings.defaults.savingPane('Yann', ScorePane.own);
    expect(saved.paneNamed('yann'), ScorePane.own);
    expect(saved.paneNamed('Bo'), ScorePane.foes);
    final replaced = saved.savingPane('YANN', ScorePane.both);
    expect(replaced.namedPanes.length, 1);
    expect(replaced.paneNamed('Yann'), ScorePane.both);
    expect(replaced.forgettingPane('yann').paneNamed('Yann'), ScorePane.foes);
    final phone = AppSettings.defaults.copyWith(scorePane: ScorePane.own);
    expect(phone.paneNamed('Inconnu'), ScorePane.own);
    final kept = phone.savingPane('Yann', ScorePane.foes);
    expect(kept.paneNamed('Yann'), ScorePane.foes);
    expect(kept.paneNamed('Bo'), ScorePane.own);
    final legacy = AppSettings.fromJson({
      'namedPanes': {'Yann': 'own'},
    });
    expect(legacy.paneNamed('Yann'), ScorePane.own);
  });
}
