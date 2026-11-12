import 'package:mtg_table/domain/models.dart';

/// Rappels du tour, seulement pour ce qui est vraiment en jeu.
/// Une option éteinte ou encore à zéro ne fait pas de bruit.
List<String> turnReminders(Game game, Player me) {
  final lines = <String>[];

  if (game.initiativeId == me.id) {
    lines.add('Initiative : en entretien, enfoncez-vous dans le donjon.');
  }
  if (game.monarchId == me.id) {
    lines.add('Monarque : une carte au début de l’étape de fin.');
  }
  if (me.rad > 0) {
    lines.add(
      'Radiation ${me.rad} : en phase principale, meulez ${me.rad}. '
      '1 vie par carte non-terrain, puis retirez 1 radiation.',
    );
  }
  if (game.trackCommanderTax) {
    final tax = me.commanders.fold<int>(0, (sum, commander) => sum + commander.tax);
    if (tax > 0) {
      lines.add('Taxe : +$tax pour relancer un commandant depuis la zone de commandement.');
    }
  }
  if (game.format == MatchFormat.oathbreaker || me.signatureCasts > 0) {
    final name = me.signatureName.trim().isEmpty ? 'Sort signature' : me.signatureName.trim();
    final extra = me.signatureCasts * 2;
    lines.add(
      extra > 0
          ? '$name : +$extra pour le relancer depuis la zone de commandement.'
          : '$name : premier lancement, sans surcoût.',
    );
  }
  if (me.speed > 0 && me.speed < 4) {
    lines.add('Vitesse ${me.speed}/4 : une seule fois ce tour, si une créature a attaqué.');
  }
  if (me.ring > 0 && me.ring < 4) {
    lines.add('Anneau ${me.ring}/4.');
  }
  if (me.blessing) {
    lines.add('Faveur de la Cité : acquise pour le reste de la partie.');
  }
  if (me.poison > 0) {
    lines.add('Poison ${me.poison}/${game.poisonThreshold}.');
  }
  if (me.treasure > 0) lines.add('Trésors : ${me.treasure}.');
  if (me.energy > 0) lines.add('Énergie : ${me.energy}.');
  if (me.experience > 0) lines.add('Expérience : ${me.experience}.');
  if (me.storm > 0) {
    lines.add(
      game.resetStormOnTurn
          ? 'Tempête ${me.storm} : elle repart à zéro en fin de tour.'
          : 'Tempête ${me.storm}.',
    );
  }
  if (game.resetManaOnTurn && me.mana.values.any((amount) => amount > 0)) {
    lines.add('Du mana flotte encore : il se vide en fin de tour.');
  }
  for (final counter in me.custom) {
    if (counter.value != 0) lines.add('${counter.name} : ${counter.value}.');
  }
  if (game.trackCommanderDamage) {
    for (final entry in me.damageTaken.entries) {
      final taken = entry.value;
      if (taken <= 0 || taken + 5 < game.commanderThreshold) continue;
      final name = _commanderName(game, entry.key) ?? 'Un commandant';
      lines.add('$name : $taken/${game.commanderThreshold} dégâts sur vous.');
    }
  }
  if (game.planechase) {
    lines.add('Planechase : ${game.currentPlane}.');
  }
  if (game.bounty) {
    lines.add('Prime : ${game.currentBounty.name}.');
  }
  if (game.archenemy && game.archenemyId == me.id) {
    lines.add('Vous êtes l’archenemy. Stratagème : ${game.currentScheme}.');
  }
  return lines;
}

String? _commanderName(Game game, String commanderId) {
  for (final player in game.players) {
    for (final commander in player.commanders) {
      if (commander.id == commanderId) return commander.name;
    }
  }
  return null;
}
