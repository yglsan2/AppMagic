import 'package:mtg_table/domain/journal_event.dart';
import 'package:mtg_table/domain/models.dart';

class SeatStructure {
  const SeatStructure({
    required this.name,
    required this.lands,
    required this.ramp,
    required this.draw,
    required this.creatures,
    required this.threats,
    required this.noted,
    required this.notes,
  });

  final String name;
  final int lands;
  final int ramp;
  final int draw;
  final int creatures;
  final int threats;
  final int noted;
  final List<String> notes;
}

bool textRamps(String text) {
  final lower = text.toLowerCase();
  return lower.contains('add {') ||
      lower.contains('ajoutez {') ||
      lower.contains('ajoute {') ||
      lower.contains('search your library for a basic land') ||
      lower.contains('search your library for a land') ||
      lower.contains('cherchez un terrain') ||
      lower.contains('cherchez une carte de terrain') ||
      lower.contains('put a land card from') ||
      lower.contains('mettez un terrain');
}

bool textInteracts(String text) {
  final lower = text.toLowerCase();
  if (RegExp(r'deals? \d+ damage to (any target|target creature|target planeswalker)')
      .hasMatch(lower)) {
    return true;
  }
  return lower.contains('destroy target') ||
      lower.contains('exile target') ||
      lower.contains('counter target') ||
      (lower.contains('return target') && lower.contains('hand'));
}

bool textWipes(String text) {
  final lower = text.toLowerCase();
  return lower.contains('destroy all') ||
      lower.contains('exile all') ||
      lower.contains('return all') ||
      lower.contains('détruisez toutes') ||
      lower.contains('exilez toutes');
}

bool textAnyNumber(String text) {
  final lower = text.toLowerCase();
  return lower.contains('any number of cards named') ||
      lower.contains('un nombre quelconque de cartes');
}

bool textDraws(String text) {
  final lower = text.toLowerCase();
  return RegExp(r'draw (?:a|an|two|three|four|x|\d+) cards?').hasMatch(lower) ||
      lower.contains('piochez');
}

bool typeIsLand(String typeLine) {
  final lower = typeLine.toLowerCase();
  return lower.contains('land') || lower.contains('terrain');
}

bool typeIsCreature(String typeLine) {
  final lower = typeLine.toLowerCase();
  return lower.contains('creature') || lower.contains('créature');
}

/// Conseils à partir d’une liste complète (deck collé), pas d’une partie.
List<String> deckStructureNotes({
  required int lands,
  required int ramp,
  required int draw,
  required int creatures,
  required int threats,
  required int spells,
}) {
  final notes = <String>[];
  if (lands >= 38 && ramp >= 6 && creatures < 24) {
    notes.add(
      '$lands terrains et $ramp accélérations. '
      'Il ne reste que $creatures créatures : la préparation prend leur place.',
    );
  }
  if (lands >= 36 && draw >= 8 && threats < 6 && spells >= 20) {
    notes.add(
      '$draw sorts de pioche et $lands terrains, pour $threats sorts de 6 ou plus. '
      'Le deck prépare longtemps et a peu de grosses menaces.',
    );
  }
  if (lands >= 38 && ramp >= 8 && draw >= 8 && creatures < 20) {
    notes.add(
      'Terrains, accélération et pioche sont tous hauts. '
      'Le deck manque de créatures à poser une fois la mana en place.',
    );
  }
  return notes;
}

List<String> playedStructureNotes(SeatStructure seat) {
  if (seat.noted < 8) return const [];
  final notes = <String>[];
  final setup = seat.lands + seat.ramp + seat.draw;
  if (seat.lands >= 30 && seat.ramp >= 4 && seat.creatures + seat.threats < seat.lands / 2) {
    notes.add(
      '${seat.name} a noté ${seat.lands} terrains et ${seat.ramp} accélérations, '
      'pour ${seat.creatures} créatures et ${seat.threats} gros sorts. '
      'La préparation étouffe les menaces.',
    );
  } else if (setup > seat.creatures + seat.threats && seat.threats <= 1) {
    notes.add(
      'Sur les cartes notées de ${seat.name} : '
      '${seat.lands} terrains, ${seat.ramp} accélérations, ${seat.draw} pioches, '
      '${seat.creatures} créatures, ${seat.threats} sort de 6 ou plus. '
      'La partie a surtout montré de la préparation.',
    );
  }
  return notes;
}

List<SeatStructure> journalStructure(Game game, List<JournalEvent> events) {
  final byId = <String, _Tally>{};
  for (final event in events) {
    final type = event.cardTypeLine;
    final name = event.cardName;
    if (type == null && (name == null || name.isEmpty)) continue;
    final id = event.sourcePlayerId ?? '';
    final tally = byId.putIfAbsent(id, _Tally.new);
    tally.noted++;
    final typeLine = type ?? '';
    final oracle = event.oracleText ?? '';
    final land = typeIsLand(typeLine);
    final creature = typeIsCreature(typeLine);
    final ramp = !land && textRamps(oracle);
    final draw = textDraws(oracle);
    final mv = event.manaValue;
    final threat = mv != null &&
        mv >= 6 &&
        !land &&
        (creature || (!ramp && !draw));
    if (land) tally.lands++;
    if (ramp) tally.ramp++;
    if (draw) tally.draw++;
    if (creature) tally.creatures++;
    if (threat) tally.threats++;
  }
  final seats = <SeatStructure>[];
  for (final entry in byId.entries) {
    final playerName = entry.key.isEmpty
        ? 'La table'
        : _playerName(game, entry.key);
    final draft = SeatStructure(
      name: playerName,
      lands: entry.value.lands,
      ramp: entry.value.ramp,
      draw: entry.value.draw,
      creatures: entry.value.creatures,
      threats: entry.value.threats,
      noted: entry.value.noted,
      notes: const [],
    );
    seats.add(
      SeatStructure(
        name: draft.name,
        lands: draft.lands,
        ramp: draft.ramp,
        draw: draft.draw,
        creatures: draft.creatures,
        threats: draft.threats,
        noted: draft.noted,
        notes: playedStructureNotes(draft),
      ),
    );
  }
  return seats;
}

String _playerName(Game game, String id) {
  for (final player in game.players) {
    if (player.id == id) return player.name;
  }
  return 'Joueur';
}

class _Tally {
  int noted = 0;
  int lands = 0;
  int ramp = 0;
  int draw = 0;
  int creatures = 0;
  int threats = 0;
}
