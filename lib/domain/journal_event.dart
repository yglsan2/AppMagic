import 'package:mtg_table/domain/models.dart';

/// Couche journal : événements corrigibles (pas un moteur de règles complet).
enum JournalKind {
  cardPlayed,
  landPlayed,
  manualNote,
  assistedEffect,
}

enum EffectKind {
  life,
  poison,
  commanderDamage,
  noteOnly,
}

class EffectSuggestion {
  const EffectSuggestion({
    required this.kind,
    required this.amount,
    required this.scope,
    required this.label,
    this.needsAmount = false,
    this.confidence = 0.7,
  });

  final EffectKind kind;
  final int amount;
  final EffectScope scope;
  final String label;
  final bool needsAmount;
  final double confidence;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'amount': amount,
    'scope': scope.name,
    'label': label,
    'needsAmount': needsAmount,
    'confidence': confidence,
  };

  factory EffectSuggestion.fromJson(Map<String, dynamic> json) {
    return EffectSuggestion(
      kind: EffectKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => EffectKind.life,
      ),
      amount: asInt(json['amount']),
      scope: EffectScope.values.firstWhere(
        (s) => s.name == json['scope'],
        orElse: () => EffectScope.target,
      ),
      label: json['label'] as String? ?? '',
      needsAmount: json['needsAmount'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.7,
    );
  }
}

enum EffectScope {
  /// Un joueur à choisir.
  target,

  /// Tous les adversaires du lanceur.
  opponents,

  /// Tous les joueurs.
  eachPlayer,

  /// Le lanceur uniquement.
  controller,

  /// Journal seulement (pas de PV).
  none,
}

/// Delta concret confirmé par la table, prêt à appliquer.
class AppliedDelta {
  const AppliedDelta({
    required this.playerId,
    required this.lifeDelta,
    this.poisonDelta = 0,
    this.commanderId,
    this.commanderDamageDelta = 0,
  });

  final String playerId;
  final int lifeDelta;
  final int poisonDelta;
  final String? commanderId;
  final int commanderDamageDelta;

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'lifeDelta': lifeDelta,
    'poisonDelta': poisonDelta,
    if (commanderId != null) 'commanderId': commanderId,
    'commanderDamageDelta': commanderDamageDelta,
  };

  factory AppliedDelta.fromJson(Map<String, dynamic> json) {
    return AppliedDelta(
      playerId: json['playerId'] as String? ?? '',
      lifeDelta: asInt(json['lifeDelta']),
      poisonDelta: asInt(json['poisonDelta']),
      commanderId: json['commanderId'] as String?,
      commanderDamageDelta: asInt(json['commanderDamageDelta']),
    );
  }
}

class JournalEvent {
  JournalEvent({
    required this.id,
    required this.kind,
    required this.label,
    required this.createdAtMs,
    required this.roundNumber,
    required this.turnCount,
    this.sourcePlayerId,
    this.cardName,
    this.cardTypeLine,
    this.manaValue,
    this.oracleText,
    this.artUrl,
    this.scryfallId,
    this.note,
    this.suggestions = const [],
    this.deltas = const [],
    this.assisted = false,
  });

  final String id;
  final JournalKind kind;
  final String label;
  final int createdAtMs;
  final int roundNumber;
  final int turnCount;
  final String? sourcePlayerId;
  final String? cardName;
  final String? cardTypeLine;
  final int? manaValue;
  final String? oracleText;
  final String? artUrl;
  final String? scryfallId;
  final String? note;
  final List<EffectSuggestion> suggestions;
  final List<AppliedDelta> deltas;
  final bool assisted;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  bool get changedLife =>
      deltas.any((d) => d.lifeDelta != 0 || d.commanderDamageDelta != 0);

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'label': label,
    'createdAtMs': createdAtMs,
    'roundNumber': roundNumber,
    'turnCount': turnCount,
    'sourcePlayerId': sourcePlayerId,
    'cardName': cardName,
    'cardTypeLine': cardTypeLine,
    'manaValue': manaValue,
    'oracleText': oracleText,
    'artUrl': artUrl,
    'scryfallId': scryfallId,
    'note': note,
    'suggestions': [for (final s in suggestions) s.toJson()],
    'deltas': [for (final d in deltas) d.toJson()],
    'assisted': assisted,
  };

  factory JournalEvent.fromJson(Map<String, dynamic> json) {
    return JournalEvent(
      id: json['id'] as String? ?? newId('evt'),
      kind: JournalKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => JournalKind.manualNote,
      ),
      label: json['label'] as String? ?? '',
      createdAtMs: asInt(json['createdAtMs']),
      roundNumber: asInt(json['roundNumber'], 1),
      turnCount: asInt(json['turnCount'], 1),
      sourcePlayerId: json['sourcePlayerId'] as String?,
      cardName: json['cardName'] as String?,
      cardTypeLine: json['cardTypeLine'] as String?,
      manaValue: json['manaValue'] == null ? null : asInt(json['manaValue']),
      oracleText: json['oracleText'] as String?,
      artUrl: json['artUrl'] as String?,
      scryfallId: json['scryfallId'] as String?,
      note: json['note'] as String?,
      suggestions: [
        for (final raw in (json['suggestions'] as List? ?? const []))
          if (raw is Map<String, dynamic>)
            EffectSuggestion.fromJson(raw)
          else if (raw is Map)
            EffectSuggestion.fromJson(Map<String, dynamic>.from(raw)),
      ],
      deltas: [
        for (final raw in (json['deltas'] as List? ?? const []))
          if (raw is Map<String, dynamic>)
            AppliedDelta.fromJson(raw)
          else if (raw is Map)
            AppliedDelta.fromJson(Map<String, dynamic>.from(raw)),
      ],
      assisted: json['assisted'] as bool? ?? false,
    );
  }
}
