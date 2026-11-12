import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';

/// Rôle d’un effet dessiné.
enum VfxRole { mote, aura, surge, storm, hit, fall, crown }

class VfxClip {
  const VfxClip({
    required this.asset,
    required this.frames,
    required this.columns,
    required this.cell,
    required this.fps,
    required     this.loop,
    this.glow = false,
    this.crisp = false,
  });

  final String asset;
  final int frames;
  final int columns;
  final int cell;
  final int fps;
  final bool loop;
  final bool glow;
  final bool crisp;
}

/// 0 rien, 1 particules, 2 aura légère, 3 intense, 4 spectaculaire.
int woundTier(int lost) {
  if (lost <= 0) return 0;
  if (lost <= 5) return 1;
  if (lost <= 10) return 2;
  if (lost <= 20) return 3;
  return 4;
}

double woundScale(int tier) => switch (tier) {
  1 => 0.7,
  2 => 1.05,
  3 => 1.22,
  4 => 1.45,
  _ => 0,
};

/// Le palier monte encore quand la vie est déjà basse.
int shownWoundTier(int lost, LifeBand band) {
  var tier = woundTier(lost);
  if (band == LifeBand.warning && tier < 2) tier = 2;
  if (band == LifeBand.critical && tier < 3) tier = 3;
  return tier;
}

/// Points réellement perdus, soins compris comme rien, annulations retirées.
int woundTally(Iterable<LifeChange> log, String playerId) {
  var sum = 0;
  for (final event in log) {
    if (event.playerId != playerId || event.retracted || event.delta >= 0) {
      continue;
    }
    sum += -event.delta;
  }
  return sum;
}

bool colorLanguage(FinaleStyle style) => switch (style) {
  FinaleStyle.blanc ||
  FinaleStyle.noir ||
  FinaleStyle.bleu ||
  FinaleStyle.vert ||
  FinaleStyle.rouge ||
  FinaleStyle.teinte => true,
  _ => false,
};

VfxClip? vfxById(String? id) => id == null ? null : _clips[id];

/// Dernière perte de ce joueur : l’attaquant, ou null si le coup vient de lui.
String? latestStrike(Iterable<LifeChange> log, String playerId) {
  for (final event in log) {
    if (event.playerId != playerId || event.retracted || event.delta >= 0) {
      continue;
    }
    return event.sourceId;
  }
  return null;
}

/// Une couleur au hasard parmi celles du deck. Aucune couleur : lame neutre.
List<String> swordPool(List<String> inks, int salt) {
  final keys = manaInkList(inks);
  if (keys.isEmpty) return const ['slash-neutral'];
  return _blades[keys[salt.abs() % keys.length]] ?? const ['slash-neutral'];
}

const _blades = <String, List<String>>{
  'W': [
    'blade-w-1',
    'blade-w-2',
    'blade-w-3',
    'slash-holy-up',
    'slash-holy-down',
  ],
  'U': [
    'blade-u-1',
    'blade-u-2',
    'blade-u-3',
    'chain-astral',
    'slash-thunder-up',
    'slash-water-up',
    'slash-water-down',
  ],
  'B': [
    'blade-b-1',
    'blade-b-2',
    'blade-b-3',
    'chain-void',
    'slash-poison-up',
  ],
  'R': [
    'blade-r-1',
    'blade-r-2',
    'blade-r-3',
    'chain-infernal',
    'slash-fire-up',
    'slash-fire-down',
  ],
  'G': [
    'blade-g-1',
    'blade-g-2',
    'blade-g-3',
    'chain-verdant',
    'slash-poison-down',
  ],
};

const _neutral = <VfxRole, List<String>>{
  VfxRole.mote: ['crisp-sparkle'],
  VfxRole.aura: ['ember-heal', 'crisp-sparkle'],
  VfxRole.surge: ['crisp-sun'],
  VfxRole.storm: ['crisp-sun', 'ember-heal'],
  VfxRole.hit: ['slash-neutral', 'crisp-shock'],
  VfxRole.fall: ['slash-neutral'],
  VfxRole.crown: ['crisp-sun', 'ember-heal'],
};

/// Une couleur, une famille : petit, puis l’aura, puis une couche plus forte.
class WoundFamily {
  const WoundFamily({
    required this.mote,
    required this.aura,
    required this.upper,
    required this.hit,
  });

  final String mote;
  final String aura;
  final String upper;
  final List<String> hit;
}

const _silentFamily = WoundFamily(
  mote: '',
  aura: '',
  upper: '',
  hit: [],
);

const _plainFamily = WoundFamily(
  mote: 'veil-smoke',
  aura: 'veil-smoke',
  upper: 'veil-smoke',
  hit: ['ash-shatter'],
);

const _failleFamily = WoundFamily(
  mote: 'faille-rift',
  aura: 'faille-rift',
  upper: 'elec-crackle',
  hit: ['elec-lightning', 'chain-void'],
);

const _sceauFamily = WoundFamily(
  mote: 'ash-charge',
  aura: 'ash-sigil',
  upper: 'ash-charge',
  hit: ['ash-nova', 'ash-shatter'],
);

const _pilierFamily = WoundFamily(
  mote: 'ash-pillar',
  aura: 'ash-pillar',
  upper: 'ash-charge',
  hit: ['ash-shatter', 'ash-nova'],
);

const _novaFamily = WoundFamily(
  mote: 'nova-orbit',
  aura: 'nova-ring',
  upper: 'nova-orbit',
  hit: ['nova-ring', 'nova-orbit'],
);

const _motifs = <CastTone, WoundFamily>{
  CastTone.standard: _plainFamily,
  CastTone.faille: _failleFamily,
  CastTone.sceau: _sceauFamily,
  CastTone.pilier: _pilierFamily,
  CastTone.nova: _novaFamily,
};

const _families = <String, WoundFamily>{
  'W': WoundFamily(
    mote: 'crisp-sparkle',
    aura: 'aura-radiant',
    upper: 'crisp-sun',
    hit: ['slash-holy-up', 'spell-light-impact'],
  ),
  'U': WoundFamily(
    mote: 'bleu-runes',
    aura: 'bleu-runes',
    upper: 'bleu-runes',
    hit: ['bleu-bruine'],
  ),
  'B': WoundFamily(
    mote: 'noir-spirale',
    aura: 'noir-spirale',
    upper: 'noir-spirale',
    hit: ['noir-lightning'],
  ),
  'R': WoundFamily(
    mote: 'lite-fire',
    aura: 'aura-fire',
    upper: 'hi-firewall',
    hit: ['hi-fire-burst', 'chain-infernal'],
  ),
  'G': WoundFamily(
    mote: 'vert-foret',
    aura: 'vert-foret',
    upper: 'vert-foret',
    hit: ['vert-coup'],
  ),
};

List<String> _castColors(CastTone cast, List<String> inks) {
  return switch (cast) {
    CastTone.aucune ||
    CastTone.standard ||
    CastTone.faille ||
    CastTone.sceau ||
    CastTone.pilier ||
    CastTone.nova => const [],
    CastTone.blanc => const ['W'],
    CastTone.bleu => const ['U'],
    CastTone.noir => const ['B'],
    CastTone.rouge => const ['R'],
    CastTone.vert => const ['G'],
    CastTone.teinte => manaInkList(inks),
  };
}

/// Aura stable tant que le choix du joueur ne change pas.
WoundFamily woundFamily(CastTone cast, List<String> inks) {
  if (cast == CastTone.aucune) return _silentFamily;
  final motif = _motifs[cast];
  if (motif != null) return motif;
  final colors = _castColors(cast, inks);
  if (colors.isEmpty) return _plainFamily;
  var index = colors.join().hashCode % colors.length;
  if (index < 0) index += colors.length;
  return _families[colors[index]] ?? _plainFamily;
}

/// Deux coups très différents, une couleur à la fois.
List<String> woundHits(CastTone cast, List<String> inks, int salt) {
  if (cast == CastTone.aucune) return const [];
  final motif = _motifs[cast];
  if (motif != null) return motif.hit;
  final colors = _castColors(cast, inks);
  if (colors.isEmpty) return _plainFamily.hit;
  final key = colors[salt.abs() % colors.length];
  return _families[key]?.hit ?? _plainFamily.hit;
}

/// Famille de son qui va avec l’image.
String soundPoolFor(String clipId) {
  if (clipId.startsWith('chain-') ||
      clipId.contains('lightning') ||
      clipId.contains('thunder')) {
    return 'bolt';
  }
  if (clipId.contains('fire') ||
      clipId.contains('lava') ||
      clipId.contains('infernal') ||
      clipId.contains('camp')) {
    return 'fire';
  }
  if (clipId.contains('frost') ||
      clipId.contains('ice') ||
      clipId.contains('water') ||
      clipId.contains('astral')) {
    return 'ice';
  }
  if (clipId.contains('void') ||
      clipId.contains('shadow') ||
      clipId.contains('smoke') ||
      clipId.contains('demon')) {
    return 'fall';
  }
  return 'swing';
}

/// Choisit un effet du paquet, jamais deux fois de suite s’il en existe un autre.
String? pickClip(List<String> pool, String? previous, int salt) {
  if (pool.isEmpty) return null;
  final options = pool.length == 1
      ? pool
      : [for (final id in pool) if (id != previous) id];
  if (options.isEmpty) return pool.first;
  final index = salt.abs() % options.length;
  return options[index];
}

List<String> castPool({
  required FinaleStyle style,
  required VfxRole role,
  required List<String> inks,
  required int seatColor,
  int? salt,
}) {
  if (style == FinaleStyle.still) return const [];
  if (style == FinaleStyle.lean &&
      role != VfxRole.hit &&
      role != VfxRole.mote &&
      role != VfxRole.fall) {
    return const [];
  }
  final fixed = _stylePools[style]?[role];
  if (fixed != null) return fixed;
  if (!colorLanguage(style)) return const [];
  final colors = _playingInks(style, inks);
  if (style == FinaleStyle.teinte && colors.isEmpty) {
    return _neutral[role] ?? const [];
  }
  if (salt != null && colors.length > 1) {
    final ink = colors[salt.abs() % colors.length];
    return _inkPools[ink]?[role] ?? const [];
  }
  final out = <String>[];
  final seen = <String>{};
  for (final ink in colors) {
    for (final id in _inkPools[ink]?[role] ?? const <String>[]) {
      if (seen.add(id)) out.add(id);
    }
  }
  return out;
}

enum _Ink { w, u, b, r, g }

_Ink? _inkOf(String key) => switch (key) {
  'W' => _Ink.w,
  'U' => _Ink.u,
  'B' => _Ink.b,
  'R' => _Ink.r,
  'G' => _Ink.g,
  _ => null,
};

List<_Ink> _playingInks(FinaleStyle style, List<String> inks) {
  return switch (style) {
    FinaleStyle.blanc => const [_Ink.w],
    FinaleStyle.noir => const [_Ink.b],
    FinaleStyle.bleu => const [_Ink.u],
    FinaleStyle.vert => const [_Ink.g],
    FinaleStyle.rouge => const [_Ink.r],
    FinaleStyle.teinte => [
      for (final key in inks)
        if (_inkOf(key) != null) _inkOf(key)!,
    ],
    _ => const [],
  };
}

const _clips = <String, VfxClip>{
  'finale-confetti': VfxClip(
    asset: 'assets/vfx/finale-confetti.png',
    frames: 64,
    columns: 8,
    cell: 128,
    fps: 16,
    loop: false,
  ),
  'finale-slam': VfxClip(
    asset: 'assets/vfx/finale-slam.png',
    frames: 9,
    columns: 9,
    cell: 32,
    fps: 14,
    loop: false,
    crisp: true,
  ),
  'aura-arcane': VfxClip(
    asset: 'assets/vfx/aura-arcane.png',
    frames: 32,
    columns: 8,
    cell: 256,
    fps: 13,
    loop: true,
    glow: true,
  ),
  'aura-fire': VfxClip(
    asset: 'assets/vfx/aura-fire.png',
    frames: 64,
    columns: 8,
    cell: 256,
    fps: 5,
    loop: true,
  ),
  'aura-frost': VfxClip(
    asset: 'assets/vfx/aura-frost.png',
    frames: 64,
    columns: 8,
    cell: 256,
    fps: 13,
    loop: true,
    glow: true,
  ),
  'aura-nature': VfxClip(
    asset: 'assets/vfx/aura-nature.png',
    frames: 64,
    columns: 8,
    cell: 256,
    fps: 10,
    loop: true,
  ),
  'aura-shadow': VfxClip(
    asset: 'assets/vfx/aura-shadow.png',
    frames: 64,
    columns: 8,
    cell: 256,
    fps: 12,
    loop: true,
  ),
  'aura-radiant': VfxClip(
    asset: 'assets/vfx/aura-radiant.png',
    frames: 96,
    columns: 12,
    cell: 256,
    fps: 5,
    loop: true,
    glow: true,
  ),
  'ember-campfire': VfxClip(
    asset: 'assets/vfx/ember-campfire.png',
    frames: 64,
    columns: 8,
    cell: 256,
    fps: 16,
    loop: true,
  ),
  'ember-fireball': VfxClip(
    asset: 'assets/vfx/ember-fireball.png',
    frames: 96,
    columns: 8,
    cell: 256,
    fps: 24,
    loop: false,
  ),
  'ember-arcane': VfxClip(
    asset: 'assets/vfx/ember-arcane.png',
    frames: 33,
    columns: 8,
    cell: 256,
    fps: 24,
    loop: false,
    glow: true,
  ),
  'ember-heal': VfxClip(
    asset: 'assets/vfx/ember-heal.png',
    frames: 64,
    columns: 8,
    cell: 256,
    fps: 16,
    loop: true,
    glow: true,
  ),
  'ember-lightning': VfxClip(
    asset: 'assets/vfx/ember-lightning.png',
    frames: 44,
    columns: 8,
    cell: 256,
    fps: 24,
    loop: false,
    glow: true,
  ),
  'ember-water': VfxClip(
    asset: 'assets/vfx/ember-water.png',
    frames: 47,
    columns: 8,
    cell: 256,
    fps: 24,
    loop: false,
  ),
  'ember-smoke': VfxClip(
    asset: 'assets/vfx/ember-smoke.png',
    frames: 64,
    columns: 8,
    cell: 256,
    fps: 14,
    loop: true,
  ),
  'ember-shock': VfxClip(
    asset: 'assets/vfx/ember-shock.png',
    frames: 15,
    columns: 8,
    cell: 256,
    fps: 24,
    loop: false,
    glow: true,
  ),
  'ember-lava': VfxClip(
    asset: 'assets/vfx/ember-lava.png',
    frames: 57,
    columns: 8,
    cell: 256,
    fps: 20,
    loop: false,
  ),
  'ember-rock': VfxClip(
    asset: 'assets/vfx/ember-rock.png',
    frames: 45,
    columns: 8,
    cell: 256,
    fps: 20,
    loop: false,
  ),
  'crisp-sparkle': VfxClip(
    asset: 'assets/vfx/crisp-sparkle.png',
    frames: 24,
    columns: 8,
    cell: 192,
    fps: 16,
    loop: true,
    glow: true,
  ),
  'crisp-gem': VfxClip(
    asset: 'assets/vfx/crisp-gem.png',
    frames: 20,
    columns: 8,
    cell: 192,
    fps: 20,
    loop: false,
    glow: true,
  ),
  'crisp-fire': VfxClip(
    asset: 'assets/vfx/crisp-fire.png',
    frames: 24,
    columns: 8,
    cell: 192,
    fps: 20,
    loop: false,
  ),
  'crisp-shock': VfxClip(
    asset: 'assets/vfx/crisp-shock.png',
    frames: 16,
    columns: 8,
    cell: 192,
    fps: 20,
    loop: false,
    glow: true,
  ),
  'crisp-star': VfxClip(
    asset: 'assets/vfx/crisp-star.png',
    frames: 24,
    columns: 8,
    cell: 192,
    fps: 20,
    loop: false,
    glow: true,
  ),
  'crisp-sun': VfxClip(
    asset: 'assets/vfx/crisp-sun.png',
    frames: 36,
    columns: 8,
    cell: 256,
    fps: 6,
    loop: true,
    glow: true,
  ),
  'crisp-ripple': VfxClip(
    asset: 'assets/vfx/crisp-ripple.png',
    frames: 14,
    columns: 8,
    cell: 192,
    fps: 20,
    loop: false,
  ),
  'spell-void-impact': VfxClip(
    asset: 'assets/vfx/spell-void-impact.png',
    frames: 9,
    columns: 4,
    cell: 160,
    fps: 16,
    loop: false,
  ),
  'spell-void-slash': VfxClip(
    asset: 'assets/vfx/spell-void-slash.png',
    frames: 9,
    columns: 4,
    cell: 160,
    fps: 16,
    loop: false,
  ),
  'spell-void-aura': VfxClip(
    asset: 'assets/vfx/spell-void-aura.png',
    frames: 14,
    columns: 4,
    cell: 160,
    fps: 12,
    loop: true,
  ),
  'spell-earth-impact': VfxClip(
    asset: 'assets/vfx/spell-earth-impact.png',
    frames: 9,
    columns: 4,
    cell: 160,
    fps: 16,
    loop: false,
  ),
  'spell-earth-slash': VfxClip(
    asset: 'assets/vfx/spell-earth-slash.png',
    frames: 9,
    columns: 4,
    cell: 160,
    fps: 16,
    loop: false,
  ),
  'spell-earth-aura': VfxClip(
    asset: 'assets/vfx/spell-earth-aura.png',
    frames: 14,
    columns: 4,
    cell: 160,
    fps: 12,
    loop: true,
  ),
  'spell-ice-impact': VfxClip(
    asset: 'assets/vfx/spell-ice-impact.png',
    frames: 9,
    columns: 4,
    cell: 160,
    fps: 16,
    loop: false,
    glow: true,
  ),
  'spell-light-impact': VfxClip(
    asset: 'assets/vfx/spell-light-impact.png',
    frames: 9,
    columns: 4,
    cell: 160,
    fps: 16,
    loop: false,
    glow: true,
  ),
  'spell-light-slash': VfxClip(
    asset: 'assets/vfx/spell-light-slash.png',
    frames: 9,
    columns: 4,
    cell: 160,
    fps: 16,
    loop: false,
    glow: true,
  ),
  'spell-fire-slash': VfxClip(
    asset: 'assets/vfx/spell-fire-slash.png',
    frames: 9,
    columns: 4,
    cell: 160,
    fps: 16,
    loop: false,
  ),
  'spell-wind-impact': VfxClip(
    asset: 'assets/vfx/spell-wind-impact.png',
    frames: 9,
    columns: 4,
    cell: 160,
    fps: 16,
    loop: false,
  ),
  'spell-wind-aura': VfxClip(
    asset: 'assets/vfx/spell-wind-aura.png',
    frames: 14,
    columns: 4,
    cell: 160,
    fps: 12,
    loop: true,
  ),
  'spell-water-impact': VfxClip(
    asset: 'assets/vfx/spell-water-impact.png',
    frames: 9,
    columns: 4,
    cell: 160,
    fps: 16,
    loop: false,
  ),
  'lite-holy': VfxClip(
    asset: 'assets/vfx/lite-holy.png',
    frames: 12,
    columns: 8,
    cell: 192,
    fps: 12,
    loop: true,
    glow: true,
  ),
  'lite-fire': VfxClip(
    asset: 'assets/vfx/lite-fire.png',
    frames: 8,
    columns: 8,
    cell: 192,
    fps: 8,
    loop: true,
  ),
  'lite-water': VfxClip(
    asset: 'assets/vfx/lite-water.png',
    frames: 12,
    columns: 8,
    cell: 192,
    fps: 12,
    loop: true,
    glow: true,
  ),
  'lite-wind': VfxClip(
    asset: 'assets/vfx/lite-wind.png',
    frames: 14,
    columns: 8,
    cell: 192,
    fps: 14,
    loop: false,
  ),
  'lite-lightning': VfxClip(
    asset: 'assets/vfx/lite-lightning.png',
    frames: 12,
    columns: 8,
    cell: 192,
    fps: 16,
    loop: false,
    glow: true,
  ),
  'lite-circle': VfxClip(
    asset: 'assets/vfx/lite-circle.png',
    frames: 16,
    columns: 8,
    cell: 192,
    fps: 14,
    loop: false,
    glow: true,
  ),
  'slash-holy-up': VfxClip(
    asset: 'assets/vfx/slash-holy-up.png',
    frames: 42,
    columns: 7,
    cell: 128,
    fps: 28,
    loop: false,
  ),
  'slash-holy-down': VfxClip(
    asset: 'assets/vfx/slash-holy-down.png',
    frames: 42,
    columns: 7,
    cell: 128,
    fps: 28,
    loop: false,
  ),
  'slash-arcane-up': VfxClip(
    asset: 'assets/vfx/slash-arcane-up.png',
    frames: 35,
    columns: 7,
    cell: 128,
    fps: 28,
    loop: false,
  ),
  'slash-arcane-down': VfxClip(
    asset: 'assets/vfx/slash-arcane-down.png',
    frames: 35,
    columns: 7,
    cell: 128,
    fps: 28,
    loop: false,
  ),
  'slash-water-up': VfxClip(
    asset: 'assets/vfx/slash-water-up.png',
    frames: 42,
    columns: 7,
    cell: 128,
    fps: 28,
    loop: false,
  ),
  'slash-water-down': VfxClip(
    asset: 'assets/vfx/slash-water-down.png',
    frames: 42,
    columns: 7,
    cell: 128,
    fps: 28,
    loop: false,
  ),
  'slash-thunder-up': VfxClip(
    asset: 'assets/vfx/slash-thunder-up.png',
    frames: 36,
    columns: 6,
    cell: 128,
    fps: 28,
    loop: false,
  ),
  'slash-thunder-down': VfxClip(
    asset: 'assets/vfx/slash-thunder-down.png',
    frames: 36,
    columns: 6,
    cell: 128,
    fps: 28,
    loop: false,
  ),
  'slash-fire-up': VfxClip(
    asset: 'assets/vfx/slash-fire-up.png',
    frames: 45,
    columns: 9,
    cell: 128,
    fps: 28,
    loop: false,
  ),
  'slash-fire-down': VfxClip(
    asset: 'assets/vfx/slash-fire-down.png',
    frames: 45,
    columns: 9,
    cell: 128,
    fps: 28,
    loop: false,
  ),
  'slash-poison-up': VfxClip(
    asset: 'assets/vfx/slash-poison-up.png',
    frames: 42,
    columns: 7,
    cell: 128,
    fps: 28,
    loop: false,
  ),
  'slash-poison-down': VfxClip(
    asset: 'assets/vfx/slash-poison-down.png',
    frames: 42,
    columns: 7,
    cell: 128,
    fps: 28,
    loop: false,
  ),
  'slash-demon': VfxClip(
    asset: 'assets/vfx/slash-demon.png',
    frames: 75,
    columns: 15,
    cell: 128,
    fps: 30,
    loop: false,
  ),
  'slash-neutral': VfxClip(
    asset: 'assets/vfx/slash-neutral.png',
    frames: 8,
    columns: 8,
    cell: 128,
    fps: 18,
    loop: false,
    glow: true,
  ),
  'bolt-astral': VfxClip(
    asset: 'assets/vfx/bolt-astral.png',
    frames: 16,
    columns: 16,
    cell: 128,
    fps: 20,
    loop: false,
    glow: true,
  ),
  'bolt-infernal': VfxClip(
    asset: 'assets/vfx/bolt-infernal.png',
    frames: 16,
    columns: 16,
    cell: 128,
    fps: 20,
    loop: false,
    glow: true,
  ),
  'bolt-verdant': VfxClip(
    asset: 'assets/vfx/bolt-verdant.png',
    frames: 16,
    columns: 16,
    cell: 128,
    fps: 20,
    loop: false,
  ),
  'bolt-void': VfxClip(
    asset: 'assets/vfx/bolt-void.png',
    frames: 16,
    columns: 16,
    cell: 128,
    fps: 20,
    loop: false,
  ),
  'blade-w-1': VfxClip(asset: 'assets/vfx/blade-w-1.png', frames: 10, columns: 10, cell: 64, fps: 25, loop: false, glow: true),
  'blade-w-2': VfxClip(asset: 'assets/vfx/blade-w-2.png', frames: 10, columns: 10, cell: 64, fps: 25, loop: false, glow: true),
  'blade-w-3': VfxClip(asset: 'assets/vfx/blade-w-3.png', frames: 10, columns: 10, cell: 64, fps: 25, loop: false, glow: true),
  'blade-u-1': VfxClip(asset: 'assets/vfx/blade-u-1.png', frames: 10, columns: 10, cell: 64, fps: 25, loop: false, glow: true),
  'blade-u-2': VfxClip(asset: 'assets/vfx/blade-u-2.png', frames: 10, columns: 10, cell: 64, fps: 25, loop: false, glow: true),
  'blade-u-3': VfxClip(asset: 'assets/vfx/blade-u-3.png', frames: 10, columns: 10, cell: 64, fps: 25, loop: false, glow: true),
  'blade-b-1': VfxClip(asset: 'assets/vfx/blade-b-1.png', frames: 10, columns: 10, cell: 64, fps: 25, loop: false, glow: true),
  'blade-b-2': VfxClip(asset: 'assets/vfx/blade-b-2.png', frames: 10, columns: 10, cell: 64, fps: 25, loop: false, glow: true),
  'blade-b-3': VfxClip(asset: 'assets/vfx/blade-b-3.png', frames: 10, columns: 10, cell: 64, fps: 25, loop: false, glow: true),
  'blade-r-1': VfxClip(asset: 'assets/vfx/blade-r-1.png', frames: 10, columns: 10, cell: 64, fps: 25, loop: false, glow: true),
  'blade-r-2': VfxClip(asset: 'assets/vfx/blade-r-2.png', frames: 10, columns: 10, cell: 64, fps: 25, loop: false, glow: true),
  'blade-r-3': VfxClip(asset: 'assets/vfx/blade-r-3.png', frames: 10, columns: 10, cell: 64, fps: 25, loop: false, glow: true),
  'blade-g-1': VfxClip(asset: 'assets/vfx/blade-g-1.png', frames: 10, columns: 10, cell: 64, fps: 25, loop: false, glow: true),
  'blade-g-2': VfxClip(asset: 'assets/vfx/blade-g-2.png', frames: 10, columns: 10, cell: 64, fps: 25, loop: false, glow: true),
  'blade-g-3': VfxClip(asset: 'assets/vfx/blade-g-3.png', frames: 10, columns: 10, cell: 64, fps: 25, loop: false, glow: true),
  'chain-astral': VfxClip(asset: 'assets/vfx/chain-astral.png', frames: 24, columns: 24, cell: 128, fps: 24, loop: false, glow: true),
  'chain-infernal': VfxClip(asset: 'assets/vfx/chain-infernal.png', frames: 24, columns: 24, cell: 128, fps: 24, loop: false, glow: true),
  'chain-verdant': VfxClip(asset: 'assets/vfx/chain-verdant.png', frames: 24, columns: 24, cell: 128, fps: 24, loop: false, glow: true),
  'chain-void': VfxClip(asset: 'assets/vfx/chain-void.png', frames: 24, columns: 24, cell: 128, fps: 24, loop: false, glow: true),
  'veil-smoke': VfxClip(
    asset: 'assets/vfx/veil-smoke.png',
    frames: 90,
    columns: 10,
    cell: 256,
    fps: 12,
    loop: true,
  ),
  'hi-fire-burst': VfxClip(
    asset: 'assets/vfx/hi-fire-burst.png',
    frames: 16,
    columns: 4,
    cell: 512,
    fps: 16,
    loop: false,
    glow: true,
  ),
  'hi-firewall': VfxClip(
    asset: 'assets/vfx/hi-firewall.png',
    frames: 16,
    columns: 4,
    cell: 512,
    fps: 6,
    loop: true,
    glow: true,
  ),
  'elec-lightning': VfxClip(
    asset: 'assets/vfx/elec-lightning.png',
    frames: 32,
    columns: 8,
    cell: 256,
    fps: 18,
    loop: false,
    glow: true,
  ),
  'elec-crackle': VfxClip(
    asset: 'assets/vfx/elec-crackle.png',
    frames: 16,
    columns: 4,
    cell: 256,
    fps: 14,
    loop: true,
    glow: true,
  ),
  'bleu-runes': VfxClip(
    asset: 'assets/vfx/bleu-runes.png',
    frames: 16,
    columns: 4,
    cell: 512,
    fps: 4,
    loop: true,
  ),
  'bleu-bruine': VfxClip(
    asset: 'assets/vfx/bleu-bruine.png',
    frames: 12,
    columns: 4,
    cell: 512,
    fps: 12,
    loop: false,
  ),
  'noir-spirale': VfxClip(
    asset: 'assets/vfx/noir-spirale.png',
    frames: 24,
    columns: 4,
    cell: 512,
    fps: 5,
    loop: true,
  ),
  'noir-lightning': VfxClip(
    asset: 'assets/vfx/noir-eclat.png',
    frames: 12,
    columns: 4,
    cell: 512,
    fps: 10,
    loop: false,
  ),
  'vert-foret': VfxClip(
    asset: 'assets/vfx/vert-foret.png',
    frames: 24,
    columns: 4,
    cell: 512,
    fps: 3,
    loop: true,
  ),
  'vert-coup': VfxClip(
    asset: 'assets/vfx/vert-coup.png',
    frames: 12,
    columns: 4,
    cell: 512,
    fps: 12,
    loop: false,
  ),
  'ash-smoke': VfxClip(
    asset: 'assets/vfx/ash-smoke.png',
    frames: 64,
    columns: 8,
    cell: 256,
    fps: 14,
    loop: true,
    glow: true,
  ),
  'ash-rift': VfxClip(
    asset: 'assets/vfx/ash-rift.png',
    frames: 28,
    columns: 28,
    cell: 128,
    fps: 16,
    loop: true,
    glow: true,
  ),
  'ash-sigil': VfxClip(
    asset: 'assets/vfx/ash-sigil.png',
    frames: 26,
    columns: 26,
    cell: 128,
    fps: 12,
    loop: true,
    glow: true,
  ),
  'ash-pillar': VfxClip(
    asset: 'assets/vfx/ash-pillar.png',
    frames: 32,
    columns: 32,
    cell: 128,
    fps: 14,
    loop: true,
    glow: true,
  ),
  'ash-charge': VfxClip(
    asset: 'assets/vfx/ash-charge.png',
    frames: 24,
    columns: 24,
    cell: 128,
    fps: 14,
    loop: true,
    glow: true,
  ),
  'ash-nova': VfxClip(
    asset: 'assets/vfx/ash-nova.png',
    frames: 24,
    columns: 24,
    cell: 128,
    fps: 18,
    loop: true,
    glow: true,
  ),
  'ash-shatter': VfxClip(
    asset: 'assets/vfx/ash-shatter.png',
    frames: 32,
    columns: 32,
    cell: 128,
    fps: 20,
    loop: false,
    glow: true,
  ),
  'faille-rift': VfxClip(
    asset: 'assets/vfx/faille-rift.png',
    frames: 28,
    columns: 28,
    cell: 128,
    fps: 16,
    loop: true,
    glow: true,
  ),
  'nova-ring': VfxClip(
    asset: 'assets/vfx/nova-ring.png',
    frames: 24,
    columns: 24,
    cell: 128,
    fps: 6,
    loop: true,
    glow: true,
  ),
  'nova-orbit': VfxClip(
    asset: 'assets/vfx/nova-orbit.png',
    frames: 24,
    columns: 24,
    cell: 128,
    fps: 6,
    loop: true,
    glow: true,
  ),
};

const _w = <VfxRole, List<String>>{
  VfxRole.mote: ['crisp-sparkle'],
  VfxRole.aura: ['aura-radiant'],
  VfxRole.surge: ['aura-radiant', 'crisp-sun'],
  VfxRole.storm: ['aura-radiant', 'crisp-sun'],
  VfxRole.hit: ['slash-holy-up', 'spell-light-impact'],
  VfxRole.fall: ['spell-light-impact', 'slash-holy-up'],
  VfxRole.crown: ['crisp-sun', 'aura-radiant'],
};

const _u = <VfxRole, List<String>>{
  VfxRole.mote: ['bleu-runes'],
  VfxRole.aura: ['bleu-runes'],
  VfxRole.surge: ['bleu-runes'],
  VfxRole.storm: ['bleu-runes'],
  VfxRole.hit: ['bleu-bruine'],
  VfxRole.fall: ['bleu-bruine'],
  VfxRole.crown: ['bleu-runes'],
};

const _b = <VfxRole, List<String>>{
  VfxRole.mote: ['noir-spirale'],
  VfxRole.aura: ['noir-spirale'],
  VfxRole.surge: ['noir-spirale'],
  VfxRole.storm: ['noir-spirale'],
  VfxRole.hit: ['noir-lightning'],
  VfxRole.fall: ['noir-lightning'],
  VfxRole.crown: ['noir-spirale'],
};

const _r = <VfxRole, List<String>>{
  VfxRole.mote: ['lite-fire'],
  VfxRole.aura: ['aura-fire'],
  VfxRole.surge: ['aura-fire', 'hi-firewall'],
  VfxRole.storm: ['hi-firewall', 'aura-fire'],
  VfxRole.hit: ['hi-fire-burst', 'chain-infernal'],
  VfxRole.fall: ['hi-fire-burst'],
  VfxRole.crown: ['aura-fire', 'hi-firewall'],
};

const _g = <VfxRole, List<String>>{
  VfxRole.mote: ['vert-foret'],
  VfxRole.aura: ['vert-foret'],
  VfxRole.surge: ['vert-foret'],
  VfxRole.storm: ['vert-foret'],
  VfxRole.hit: ['vert-coup'],
  VfxRole.fall: ['vert-coup'],
  VfxRole.crown: ['vert-foret'],
};

const _inkPools = <_Ink, Map<VfxRole, List<String>>>{
  _Ink.w: _w,
  _Ink.u: _u,
  _Ink.b: _b,
  _Ink.r: _r,
  _Ink.g: _g,
};

const _stylePools = <FinaleStyle, Map<VfxRole, List<String>>>{
  FinaleStyle.mythic: {
    VfxRole.mote: ['crisp-sparkle', 'lite-holy'],
    VfxRole.aura: ['ember-heal', 'lite-holy'],
    VfxRole.surge: ['crisp-sun', 'ember-heal'],
    VfxRole.storm: ['crisp-sun', 'ember-heal'],
    VfxRole.hit: [
      'spell-light-impact',
      'spell-light-slash',
      'crisp-star',
      'crisp-shock',
      'lite-lightning',
    ],
    VfxRole.fall: ['spell-light-impact', 'crisp-star', 'lite-circle'],
    VfxRole.crown: ['crisp-sun', 'ember-heal'],
  },
  FinaleStyle.lotus: {
    VfxRole.mote: ['aura-shadow'],
    VfxRole.aura: ['aura-shadow', 'spell-void-aura'],
    VfxRole.surge: ['ember-smoke', 'aura-shadow'],
    VfxRole.storm: ['ember-smoke', 'aura-shadow'],
    VfxRole.hit: ['spell-void-impact', 'spell-void-slash'],
    VfxRole.fall: ['spell-void-impact', 'aura-shadow'],
    VfxRole.crown: ['aura-shadow'],
  },
  FinaleStyle.carbon: {
    VfxRole.mote: ['spell-earth-aura'],
    VfxRole.aura: ['spell-earth-aura'],
    VfxRole.surge: ['spell-earth-aura'],
    VfxRole.storm: ['spell-earth-aura'],
    VfxRole.hit: ['ember-rock', 'spell-earth-impact', 'spell-earth-slash'],
    VfxRole.fall: ['ember-rock', 'spell-earth-impact'],
    VfxRole.crown: ['spell-earth-aura'],
  },
  FinaleStyle.arena: {
    VfxRole.mote: ['aura-arcane'],
    VfxRole.aura: ['aura-arcane'],
    VfxRole.surge: ['aura-arcane'],
    VfxRole.storm: ['aura-arcane'],
    VfxRole.hit: [
      'ember-lightning',
      'ember-shock',
      'ember-fireball',
      'lite-lightning',
      'crisp-shock',
    ],
    VfxRole.fall: ['ember-shock', 'ember-fireball'],
    VfxRole.crown: ['aura-arcane'],
  },
  FinaleStyle.seal: {
    VfxRole.mote: ['aura-arcane'],
    VfxRole.aura: ['aura-arcane'],
    VfxRole.surge: ['aura-arcane'],
    VfxRole.storm: ['aura-arcane'],
    VfxRole.hit: ['ember-arcane', 'lite-circle', 'lite-lightning'],
    VfxRole.fall: ['lite-circle', 'ember-arcane'],
    VfxRole.crown: ['aura-arcane'],
  },
  FinaleStyle.lean: {
    VfxRole.mote: ['crisp-sparkle', 'crisp-ripple'],
    VfxRole.hit: ['crisp-ripple', 'crisp-shock', 'ember-shock'],
    VfxRole.fall: ['crisp-shock', 'ember-shock'],
  },
};
