import 'package:mtg_table/domain/models.dart';

/// Profil joueur réutilisable d’une soirée à l’autre.
class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.name,
    required this.color,
    this.commanders = const [],
    this.commanderArts = const [],
    this.panelArtUrl,
  });

  final String id;
  final String name;
  final int color;
  final List<String> commanders;
  final List<String?> commanderArts;
  final String? panelArtUrl;

  PlayerProfile copyWith({
    String? name,
    int? color,
    List<String>? commanders,
    List<String?>? commanderArts,
    String? panelArtUrl,
  }) {
    return PlayerProfile(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      commanders: commanders ?? this.commanders,
      commanderArts: commanderArts ?? this.commanderArts,
      panelArtUrl: panelArtUrl ?? this.panelArtUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'commanders': commanders,
    'commanderArts': commanderArts,
    'panelArtUrl': panelArtUrl,
  };

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    final commanders = [
      for (final name in (json['commanders'] as List? ?? [])) '$name',
    ];
    final artsRaw = json['commanderArts'] as List? ?? const [];
    return PlayerProfile(
      id: json['id'] as String? ?? newId('prof'),
      name: json['name'] as String? ?? 'Joueur',
      color: asInt(json['color']),
      commanders: commanders,
      commanderArts: [
        for (var i = 0; i < commanders.length; i++)
          i < artsRaw.length ? artsRaw[i] as String? : null,
      ],
      panelArtUrl: json['panelArtUrl'] as String?,
    );
  }

  factory PlayerProfile.fromDraft({
    required String name,
    required int color,
    required List<String> commanders,
    required List<String?> arts,
    String? panelArtUrl,
  }) {
    return PlayerProfile(
      id: newId('prof'),
      name: name.trim().isEmpty ? 'Joueur' : name.trim(),
      color: color,
      commanders: commanders,
      commanderArts: arts,
      panelArtUrl: panelArtUrl,
    );
  }
}
