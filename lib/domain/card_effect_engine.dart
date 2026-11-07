import 'package:mtg_table/data/scryfall_card.dart';
import 'package:mtg_table/domain/journal_event.dart';

/// Moteur léger : modèles connus + reconnaissance assistée du texte simple.
/// Les interactions complexes restent à confirmer par la table.
class CardEffectEngine {
  const CardEffectEngine();

  /// Suggestions à partir d’une carte Scryfall (templates puis parseur).
  List<EffectSuggestion> suggest(ScryfallCard card) {
    final keyed = _templateFor(card.name);
    if (keyed.isNotEmpty) return keyed;

    final fromText = parseOracleEffects(card.effectText);
    if (fromText.isNotEmpty) return fromText;

    if (card.isLand) {
      return const [
        EffectSuggestion(
          kind: EffectKind.noteOnly,
          amount: 0,
          scope: EffectScope.none,
          label: 'Terrain joué (pas d’effet de vie détecté)',
          confidence: 1,
        ),
      ];
    }

    return const [
      EffectSuggestion(
        kind: EffectKind.noteOnly,
        amount: 0,
        scope: EffectScope.none,
        label: 'Effet complexe · à saisir / confirmer manuellement',
        confidence: 0.2,
      ),
    ];
  }

  /// Parseur assisté EN/FR pour pertes/gains de vie et blessures simples.
  List<EffectSuggestion> parseOracleEffects(String text) {
    if (text.trim().isEmpty) return const [];
    final normalized = text
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final lower = normalized.toLowerCase();
    final out = <EffectSuggestion>[];

    void add(EffectSuggestion s) {
      // Évite les doublons grossiers.
      if (out.any((e) => e.label == s.label && e.amount == s.amount)) return;
      out.add(s);
    }

    // --- Gains de vie ---
    for (final m in RegExp(
      r'(?:you |vous )?(?:gain|gagnez?|gagne)\s+(\d+|x)\s+(?:life|points?\s+de\s+vie)',
      caseSensitive: false,
    ).allMatches(lower)) {
      final amount = _parseAmount(m.group(1)!);
      add(
        EffectSuggestion(
          kind: EffectKind.life,
          amount: amount ?? 0,
          scope: EffectScope.controller,
          label: amount == null
              ? 'Le lanceur gagne X PV'
              : 'Le lanceur gagne $amount PV',
          needsAmount: amount == null,
          confidence: 0.85,
        ),
      );
    }

    for (final m in RegExp(
      r'(?:target player|le joueur ciblé|un joueur ciblé)\s+(?:gains?|gagne)\s+(\d+|x)\s+(?:life|points?\s+de\s+vie)',
      caseSensitive: false,
    ).allMatches(lower)) {
      final amount = _parseAmount(m.group(1)!);
      add(
        EffectSuggestion(
          kind: EffectKind.life,
          amount: amount ?? 0,
          scope: EffectScope.target,
          label: amount == null
              ? 'Un joueur gagne X PV'
              : 'Un joueur gagne $amount PV',
          needsAmount: amount == null,
          confidence: 0.8,
        ),
      );
    }

    // --- Pertes de vie ---
    for (final m in RegExp(
      r'each opponent (?:loses?|lose)\s+(\d+|x)\s+life',
      caseSensitive: false,
    ).allMatches(lower)) {
      final amount = _parseAmount(m.group(1)!);
      add(
        EffectSuggestion(
          kind: EffectKind.life,
          amount: -(amount ?? 0),
          scope: EffectScope.opponents,
          label: amount == null
              ? 'Chaque adversaire perd X PV'
              : 'Chaque adversaire perd $amount PV',
          needsAmount: amount == null,
          confidence: 0.9,
        ),
      );
    }
    for (final m in RegExp(
      r'chaque adversaire (?:perd|perdez?)\s+(\d+|x)\s+points?\s+de\s+vie',
      caseSensitive: false,
    ).allMatches(lower)) {
      final amount = _parseAmount(m.group(1)!);
      add(
        EffectSuggestion(
          kind: EffectKind.life,
          amount: -(amount ?? 0),
          scope: EffectScope.opponents,
          label: amount == null
              ? 'Chaque adversaire perd X PV'
              : 'Chaque adversaire perd $amount PV',
          needsAmount: amount == null,
          confidence: 0.9,
        ),
      );
    }

    for (final m in RegExp(
      r'each player (?:loses?|lose)\s+(\d+|x)\s+life',
      caseSensitive: false,
    ).allMatches(lower)) {
      final amount = _parseAmount(m.group(1)!);
      add(
        EffectSuggestion(
          kind: EffectKind.life,
          amount: -(amount ?? 0),
          scope: EffectScope.eachPlayer,
          label: amount == null
              ? 'Chaque joueur perd X PV'
              : 'Chaque joueur perd $amount PV',
          needsAmount: amount == null,
          confidence: 0.85,
        ),
      );
    }
    for (final m in RegExp(
      r'chaque joueur (?:perd|perdez?)\s+(\d+|x)\s+points?\s+de\s+vie',
      caseSensitive: false,
    ).allMatches(lower)) {
      final amount = _parseAmount(m.group(1)!);
      add(
        EffectSuggestion(
          kind: EffectKind.life,
          amount: -(amount ?? 0),
          scope: EffectScope.eachPlayer,
          label: amount == null
              ? 'Chaque joueur perd X PV'
              : 'Chaque joueur perd $amount PV',
          needsAmount: amount == null,
          confidence: 0.85,
        ),
      );
    }

    for (final m in RegExp(
      r'(?:target (?:player|opponent)|le joueur ciblé|un adversaire ciblé|target creature or player|any target)\s+(?:loses?|lose|perd)\s+(\d+|x)\s+(?:life|points?\s+de\s+vie)',
      caseSensitive: false,
    ).allMatches(lower)) {
      final amount = _parseAmount(m.group(1)!);
      add(
        EffectSuggestion(
          kind: EffectKind.life,
          amount: -(amount ?? 0),
          scope: EffectScope.target,
          label: amount == null
              ? 'La cible perd X PV'
              : 'La cible perd $amount PV',
          needsAmount: amount == null,
          confidence: 0.8,
        ),
      );
    }

    for (final m in RegExp(
      r'(?:you |vous )?(?:lose|loses|perdez?|perd)\s+(\d+|x)\s+(?:life|points?\s+de\s+vie)',
      caseSensitive: false,
    ).allMatches(lower)) {
      // Ignore si déjà couvert par "each opponent/player".
      if (lower.contains('each opponent') ||
          lower.contains('chaque adversaire') ||
          lower.contains('each player') ||
          lower.contains('chaque joueur') ||
          lower.contains('target player') ||
          lower.contains('joueur ciblé')) {
        continue;
      }
      final amount = _parseAmount(m.group(1)!);
      add(
        EffectSuggestion(
          kind: EffectKind.life,
          amount: -(amount ?? 0),
          scope: EffectScope.controller,
          label: amount == null
              ? 'Le lanceur perd X PV'
              : 'Le lanceur perd $amount PV',
          needsAmount: amount == null,
          confidence: 0.75,
        ),
      );
    }

    // --- Blessures / damage ---
    for (final m in RegExp(
      r'(?:deals?|deal|inflige|infligent)\s+(\d+|x)\s+(?:damage|blessures?)',
      caseSensitive: false,
    ).allMatches(lower)) {
      final amount = _parseAmount(m.group(1)!);
      final toOpponents =
          lower.contains('each opponent') || lower.contains('chaque adversaire');
      final toEach =
          lower.contains('each player') || lower.contains('chaque joueur');
      add(
        EffectSuggestion(
          kind: EffectKind.life,
          amount: -(amount ?? 0),
          scope: toOpponents
              ? EffectScope.opponents
              : toEach
              ? EffectScope.eachPlayer
              : EffectScope.target,
          label: amount == null
              ? 'Inflige X blessures'
              : 'Inflige $amount blessures (PV)',
          needsAmount: amount == null,
          confidence: 0.7,
        ),
      );
    }

    // Poison
    for (final m in RegExp(
      r'(\d+|x)\s+poison\s+(?:counter|marqueurs?)',
      caseSensitive: false,
    ).allMatches(lower)) {
      final amount = _parseAmount(m.group(1)!);
      add(
        EffectSuggestion(
          kind: EffectKind.poison,
          amount: amount ?? 0,
          scope: EffectScope.target,
          label: amount == null
              ? 'X marqueurs poison'
              : '$amount marqueur(s) poison',
          needsAmount: amount == null,
          confidence: 0.75,
        ),
      );
    }

    return out;
  }

  /// Résout les suggestions en deltas concrets (après choix des cibles / montants).
  List<AppliedDelta> resolveDeltas({
    required EffectSuggestion suggestion,
    required String controllerId,
    required List<String> allPlayerIds,
    required List<String> targetIds,
    required int resolvedAmount,
    String? commanderId,
    bool asCommanderDamage = false,
  }) {
    if (suggestion.kind == EffectKind.noteOnly) return const [];

    List<String> recipients;
    switch (suggestion.scope) {
      case EffectScope.controller:
        recipients = [controllerId];
      case EffectScope.opponents:
        recipients = [
          for (final id in allPlayerIds)
            if (id != controllerId) id,
        ];
      case EffectScope.eachPlayer:
        recipients = [...allPlayerIds];
      case EffectScope.target:
        recipients = [...targetIds];
      case EffectScope.none:
        return const [];
    }
    if (recipients.isEmpty) return const [];

    if (suggestion.kind == EffectKind.poison) {
      final n = suggestion.needsAmount
          ? resolvedAmount.abs()
          : (suggestion.amount == 0
                ? resolvedAmount.abs()
                : suggestion.amount.abs());
      return [
        for (final id in recipients)
          AppliedDelta(playerId: id, lifeDelta: 0, poisonDelta: n),
      ];
    }

    final signed = _signedLife(suggestion, resolvedAmount);

    if (asCommanderDamage &&
        commanderId != null &&
        signed < 0) {
      return [
        for (final id in recipients)
          AppliedDelta(
            playerId: id,
            lifeDelta: 0,
            commanderId: commanderId,
            commanderDamageDelta: -signed,
          ),
      ];
    }

    return [
      for (final id in recipients)
        AppliedDelta(playerId: id, lifeDelta: signed),
    ];
  }

  int _signedLife(EffectSuggestion suggestion, int resolvedAmount) {
    final label = suggestion.label.toLowerCase();
    final mag = suggestion.needsAmount || suggestion.amount == 0
        ? resolvedAmount.abs()
        : suggestion.amount.abs();
    if (suggestion.amount < 0) return -mag;
    if (suggestion.amount > 0) return mag;
    if (label.contains('gagne')) return mag;
    if (label.contains('perd') ||
        label.contains('blessure') ||
        label.contains('inflige')) {
      return -mag;
    }
    return -mag;
  }

  int? _parseAmount(String raw) {
    final t = raw.trim().toLowerCase();
    if (t == 'x') return null;
    return int.tryParse(t);
  }

  List<EffectSuggestion> _templateFor(String name) {
    final key = name.toLowerCase().trim();
    final templates = <String, List<EffectSuggestion>>{
      'lightning bolt': [
        const EffectSuggestion(
          kind: EffectKind.life,
          amount: -3,
          scope: EffectScope.target,
          label: 'Inflige 3 blessures à une cible',
          confidence: 1,
        ),
      ],
      'shock': [
        const EffectSuggestion(
          kind: EffectKind.life,
          amount: -2,
          scope: EffectScope.target,
          label: 'Inflige 2 blessures à une cible',
          confidence: 1,
        ),
      ],
      'lava spike': [
        const EffectSuggestion(
          kind: EffectKind.life,
          amount: -3,
          scope: EffectScope.target,
          label: 'Inflige 3 blessures à un joueur',
          confidence: 1,
        ),
      ],
      'gray merchant of asphodel': [
        const EffectSuggestion(
          kind: EffectKind.life,
          amount: 0,
          scope: EffectScope.opponents,
          label: 'Chaque adversaire perd X PV (dévotion au noir)',
          needsAmount: true,
          confidence: 0.95,
        ),
        const EffectSuggestion(
          kind: EffectKind.life,
          amount: 0,
          scope: EffectScope.controller,
          label: 'Le lanceur gagne autant de PV',
          needsAmount: true,
          confidence: 0.95,
        ),
      ],
      'exsanguinate': [
        const EffectSuggestion(
          kind: EffectKind.life,
          amount: 0,
          scope: EffectScope.opponents,
          label: 'Chaque adversaire perd X PV',
          needsAmount: true,
          confidence: 1,
        ),
        const EffectSuggestion(
          kind: EffectKind.life,
          amount: 0,
          scope: EffectScope.controller,
          label: 'Vous gagnez la somme perdue',
          needsAmount: true,
          confidence: 0.9,
        ),
      ],
      'toxic deluge': [
        const EffectSuggestion(
          kind: EffectKind.noteOnly,
          amount: 0,
          scope: EffectScope.none,
          label: '−X/−X jusqu’à la fin du tour (créatures · manuel)',
          confidence: 0.5,
        ),
      ],
      'swords to plowshares': [
        const EffectSuggestion(
          kind: EffectKind.life,
          amount: 0,
          scope: EffectScope.target,
          label: 'Le contrôleur de la créature gagne autant de points de vie que sa force',
          needsAmount: true,
          confidence: 0.85,
        ),
      ],
      'path to exile': [
        const EffectSuggestion(
          kind: EffectKind.noteOnly,
          amount: 0,
          scope: EffectScope.none,
          label: 'Exile la créature. Son contrôleur peut chercher un terrain.',
          confidence: 0.6,
        ),
      ],
      'sol ring': [
        const EffectSuggestion(
          kind: EffectKind.noteOnly,
          amount: 0,
          scope: EffectScope.none,
          label: 'Artefact de mana · journal seulement',
          confidence: 1,
        ),
      ],
      'feed the swarm': [
        const EffectSuggestion(
          kind: EffectKind.life,
          amount: 0,
          scope: EffectScope.controller,
          label: 'Vous perdez autant de points de vie que le coût de mana',
          needsAmount: true,
          confidence: 0.85,
        ),
      ],
      'vampiric tutor': [
        const EffectSuggestion(
          kind: EffectKind.life,
          amount: -2,
          scope: EffectScope.controller,
          label: 'Vous perdez 2 PV',
          confidence: 1,
        ),
      ],
      'demonic tutor': [
        const EffectSuggestion(
          kind: EffectKind.noteOnly,
          amount: 0,
          scope: EffectScope.none,
          label: 'Recherche de carte · journal seulement',
          confidence: 1,
        ),
      ],
      'fracture': [
        const EffectSuggestion(
          kind: EffectKind.noteOnly,
          amount: 0,
          scope: EffectScope.none,
          label: 'Détruit artefact ou enchantement · journal',
          confidence: 0.7,
        ),
      ],
      'generous gift': [
        const EffectSuggestion(
          kind: EffectKind.noteOnly,
          amount: 0,
          scope: EffectScope.none,
          label: 'Détruit permanent · jeton 3/3 · journal',
          confidence: 0.7,
        ),
      ],
      'beast within': [
        const EffectSuggestion(
          kind: EffectKind.noteOnly,
          amount: 0,
          scope: EffectScope.none,
          label: 'Détruit permanent · jeton 3/3 · journal',
          confidence: 0.7,
        ),
      ],
      'aetherflux reservoir': [
        const EffectSuggestion(
          kind: EffectKind.life,
          amount: -50,
          scope: EffectScope.target,
          label: 'Payer 50 PV : 50 blessures à une cible',
          confidence: 0.9,
        ),
      ],
      'deflecting swat': [
        const EffectSuggestion(
          kind: EffectKind.noteOnly,
          amount: 0,
          scope: EffectScope.none,
          label: 'Change la cible d’un sort · journal',
          confidence: 0.5,
        ),
      ],
      'fierce guardianship': [
        const EffectSuggestion(
          kind: EffectKind.noteOnly,
          amount: 0,
          scope: EffectScope.none,
          label: 'Contrecarre un sort non-créature · journal',
          confidence: 0.6,
        ),
      ],
      'deadly rollick': [
        const EffectSuggestion(
          kind: EffectKind.noteOnly,
          amount: 0,
          scope: EffectScope.none,
          label: 'Exile une créature · journal',
          confidence: 0.6,
        ),
      ],
    };

    // Alias FR courants
    final aliases = <String, String>{
      'éclair': 'lightning bolt',
      'foudre': 'lightning bolt',
      'choc': 'shock',
      'pointe de lave': 'lava spike',
      'marchand gris d\'asphodèle': 'gray merchant of asphodel',
      'exsangue': 'exsanguinate',
      'déluge toxique': 'toxic deluge',
      'épées en socs de charrue': 'swords to plowshares',
      'voie de l\'exil': 'path to exile',
      'anneau solaire': 'sol ring',
      'nourrir l\'essaim': 'feed the swarm',
      'précepteur vampirique': 'vampiric tutor',
      'précepteur démoniaque': 'demonic tutor',
    };

    final resolved = aliases[key] ?? key;
    return templates[resolved] ?? const [];
  }
}

const cardEffectEngine = CardEffectEngine();
