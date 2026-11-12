/// Donjons de l’initiative. Les noms de salles suivent les deux donjons
/// officiels. Le rappel est une indication de table, pas le texte de la carte.
class DungeonRoom {
  const DungeonRoom({
    required this.id,
    required this.name,
    required this.hint,
    this.exits = const [],
  });

  final String id;
  final String name;
  final String hint;
  final List<String> exits;

  bool get finished => exits.isEmpty;
}

class DungeonDef {
  const DungeonDef({
    required this.id,
    required this.name,
    required this.rooms,
  });

  final String id;
  final String name;
  final List<DungeonRoom> rooms;

  DungeonRoom get start => rooms.first;

  DungeonRoom? room(String id) {
    for (final room in rooms) {
      if (room.id == id) return room;
    }
    return null;
  }
}

const lostMine = DungeonDef(
  id: 'mine',
  name: 'Mine perdue',
  rooms: [
    DungeonRoom(
      id: 'entrance',
      name: 'Entrée de la grotte',
      hint: 'Première salle. Deux chemins s’ouvrent.',
      exits: ['goblins', 'tunnels'],
    ),
    DungeonRoom(
      id: 'goblins',
      name: 'Repaire gobelin',
      hint: 'Une salle de gobelins. Choisis la suite.',
      exits: ['storeroom', 'pool'],
    ),
    DungeonRoom(
      id: 'tunnels',
      name: 'Tunnels de la mine',
      hint: 'Les tunnels se séparent.',
      exits: ['pool', 'fungi'],
    ),
    DungeonRoom(
      id: 'storeroom',
      name: 'Réserve',
      hint: 'Une réserve. Le temple est au bout.',
      exits: ['temple'],
    ),
    DungeonRoom(
      id: 'pool',
      name: 'Bassin sombre',
      hint: 'Un bassin. Le temple est au bout.',
      exits: ['temple'],
    ),
    DungeonRoom(
      id: 'fungi',
      name: 'Caverne aux champignons',
      hint: 'Des champignons. Le temple est au bout.',
      exits: ['temple'],
    ),
    DungeonRoom(
      id: 'temple',
      name: 'Temple de Dumathoin',
      hint: 'Dernière salle. Le donjon est achevé.',
    ),
  ],
);

const undercity = DungeonDef(
  id: 'undercity',
  name: 'Ville souterraine',
  rooms: [
    DungeonRoom(
      id: 'secret',
      name: 'Entrée secrète',
      hint: 'Trois portes. Une seule se prend.',
      exits: ['forge', 'well', 'arena'],
    ),
    DungeonRoom(
      id: 'forge',
      name: 'Forge',
      hint: 'La forge. Deux suites.',
      exits: ['trap', 'vault'],
    ),
    DungeonRoom(
      id: 'well',
      name: 'Puits perdu',
      hint: 'Le puits. Deux suites.',
      exits: ['vault', 'catacombs'],
    ),
    DungeonRoom(
      id: 'arena',
      name: 'Arène',
      hint: 'L’arène. Deux suites.',
      exits: ['catacombs', 'trap'],
    ),
    DungeonRoom(
      id: 'trap',
      name: 'Piège',
      hint: 'Un piège. Le trône est ensuite.',
      exits: ['throne'],
    ),
    DungeonRoom(
      id: 'vault',
      name: 'Chambre forte',
      hint: 'Une chambre. Le trône est ensuite.',
      exits: ['throne'],
    ),
    DungeonRoom(
      id: 'catacombs',
      name: 'Catacombes',
      hint: 'Les catacombes. Le trône est ensuite.',
      exits: ['throne'],
    ),
    DungeonRoom(
      id: 'throne',
      name: 'Trône des Trois Morts',
      hint: 'Dernière salle. Le donjon est achevé.',
    ),
  ],
);

const dungeons = <DungeonDef>[lostMine, undercity];

DungeonDef? dungeonById(String? id) {
  if (id == null) return null;
  for (final dungeon in dungeons) {
    if (dungeon.id == id) return dungeon;
  }
  return null;
}
