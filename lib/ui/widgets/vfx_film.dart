import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/vfx_cast.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/widgets/table_audio.dart';

class VfxImages {
  static final _cache = <String, Future<ui.Image?>>{};

  static Future<ui.Image?> load(String asset) {
    return _cache.putIfAbsent(asset, () async {
      try {
        final data = await rootBundle.load(asset);
        // La vue peut commencer au milieu d’un tampon plus grand.
        // asUint8List() sans bornes y ajoute des octets et l’image ne se décode plus.
        final codec = await ui.instantiateImageCodec(
          Uint8List.sublistView(data),
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame.image;
      } catch (_) {
        _cache.remove(asset);
        return null;
      }
    });
  }
}

/// Où poser le carré d’effet dans le rectangle du joueur.
///
/// Le haut et le bas restent libres : les options y sont rangées, quelle
/// que soit la disposition. Le carré grandit avec la case, et avec
/// [scale], sans jamais en sortir.
class VfxFit {
  const VfxFit({required this.top, required this.bottom, required this.side});

  final double top;
  final double bottom;
  final double side;
}

VfxFit vfxFit(double width, double height, double scale) {
  if (width < 8 || height < 8) {
    return const VfxFit(top: 0, bottom: 0, side: 0);
  }
  final shortest = math.min(width, height);
  final factor = (scale / 1.2).clamp(0.9, 1.0);
  final side = shortest * factor;
  final pad = math.max(0.0, (height - side) / 2);
  return VfxFit(top: pad, bottom: pad, side: side);
}

/// Une planche jouée au centre du rectangle.
class VfxFilm extends StatelessWidget {
  const VfxFilm({
    super.key,
    required this.clipId,
    this.loop = false,
    this.scale = 1,
    this.pace = 1,
    this.frame,
    this.onDone,
  });

  final String clipId;
  final bool loop;
  final double scale;
  final double pace;

  final int? frame;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return FxBoard(
      layers: [
        FxLayer(
          id: clipId,
          clipId: clipId,
          loop: loop,
          scale: scale,
          pace: pace,
          frame: frame,
          onDone: onDone,
        ),
      ],
    );
  }
}

class FxLayer {
  const FxLayer({
    required this.id,
    required this.clipId,
    required this.scale,
    this.loop = false,
    this.pace = 1,
    this.frame,
    this.onDone,
  });

  final String id;
  final String clipId;
  final bool loop;
  final double scale;
  final double pace;
  final int? frame;
  final VoidCallback? onDone;
}

class FxBoard extends StatefulWidget {
  const FxBoard({super.key, required this.layers});

  final List<FxLayer> layers;

  @override
  State<FxBoard> createState() => _FxBoardState();
}

class _Play {
  _Play(this.spec);

  FxLayer spec;
  ui.Image? image;
  Timer? timer;
  var frame = 0;
  var token = 0;

  String get clipId => spec.clipId;

  void dispose() {
    token++;
    timer?.cancel();
  }
}

class _FxBoardState extends State<FxBoard> {
  final _plays = <String, _Play>{};

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(FxBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final keep = <String>{};
    for (final spec in widget.layers.take(4)) {
      keep.add(spec.id);
      final play = _plays[spec.id];
      final same = play != null &&
          play.clipId == spec.clipId &&
          play.spec.pace == spec.pace &&
          play.spec.frame == spec.frame;
      if (same) {
        play.spec = spec;
        continue;
      }
      play?.dispose();
      final created = _Play(spec);
      _plays[spec.id] = created;
      _start(created);
    }
    for (final id in _plays.keys.where((id) => !keep.contains(id)).toList()) {
      _plays.remove(id)?.dispose();
    }
  }

  Future<void> _start(_Play play) async {
    final clip = vfxById(play.clipId);
    if (clip == null) return;
    final token = ++play.token;
    final image = await VfxImages.load(clip.asset);
    if (!mounted || token != play.token || image == null) return;
    final held = play.spec.frame;
    setState(() {
      play.image = image;
      if (held != null) play.frame = held.clamp(0, clip.frames - 1);
    });
    if (held != null) return;
    final ms = (1000 / (clip.fps * play.spec.pace.clamp(0.4, 1.6)))
        .round()
        .clamp(16, 520);
    play.timer = Timer.periodic(Duration(milliseconds: ms), (_) {
      _advance(play, clip);
    });
  }

  void _advance(_Play play, VfxClip clip) {
    if (!mounted) return;
    final next = play.frame + 1;
    if (next >= clip.frames) {
      if (play.spec.loop && clip.loop) {
        setState(() => play.frame = 0);
        return;
      }
      play.timer?.cancel();
      play.timer = null;
      play.spec.onDone?.call();
      return;
    }
    setState(() => play.frame = next);
  }

  @override
  void dispose() {
    for (final play in _plays.values) {
      play.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = [
      for (final spec in widget.layers)
        if (_plays[spec.id]?.image != null) spec.id,
    ];
    if (ready.isEmpty) return const SizedBox.expand();
    return CustomPaint(
      painter: _FxPainter(
        layers: [for (final spec in widget.layers) _plays[spec.id]],
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _FxPainter extends CustomPainter {
  _FxPainter({required this.layers});

  final List<_Play?> layers;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    for (final play in layers) {
      final image = play?.image;
      final clip = play == null ? null : vfxById(play.clipId);
      if (play == null || image == null || clip == null || clip.frames <= 0) {
        continue;
      }
      final fit = vfxFit(size.width, size.height, play.spec.scale);
      if (fit.side < 8) continue;
      final index = play.frame.clamp(0, clip.frames - 1);
      final src = Rect.fromLTWH(
        (index % clip.columns) * clip.cell.toDouble(),
        (index ~/ clip.columns) * clip.cell.toDouble(),
        clip.cell.toDouble(),
        clip.cell.toDouble(),
      );
      canvas.drawImageRect(
        image,
        src,
        Rect.fromLTWH((size.width - fit.side) / 2, fit.top, fit.side, fit.side),
        Paint()
          ..filterQuality = clip.crisp
              ? FilterQuality.none
              : FilterQuality.medium,
      );
    }
  }

  @override
  bool shouldRepaint(_FxPainter oldDelegate) => true;
}

/// Blessures qui restent, coup, et couronne, par-dessus le rectangle.
class VfxStage extends StatefulWidget {
  const VfxStage({
    super.key,
    required this.style,
    required this.inks,
    required this.cast,
    required this.seatColor,
    required this.life,
    required this.wound,
    required this.band,
    required this.victorious,
    this.strikeKnown = false,
    this.strikeInks = const [],
    this.strikeSeat = 0,
  });

  final FinaleStyle style;
  final List<String> inks;
  final CastTone cast;
  final int seatColor;
  final int life;
  final int wound;
  final LifeBand band;
  final bool victorious;
  final bool strikeKnown;
  final List<String> strikeInks;
  final int strikeSeat;

  @override
  State<VfxStage> createState() => _VfxStageState();
}

class _VfxStageState extends State<VfxStage> {
  late int _seenLife = widget.life;
  var _salt = 1;
  var _tier = 0;
  String? _hitId;
  var _hitToken = 0;
  String? _baseId;
  String? _upperId;
  String? _crownId;

  @override
  void initState() {
    super.initState();
    _retarget(force: true);
    if (widget.victorious) {
      TableAudio.play('win');
      _crownId = pickClip(
        castPool(
          style: widget.style,
          role: VfxRole.crown,
          inks: widget.inks,
          seatColor: widget.seatColor,
          salt: _salt,
        ),
        null,
        _salt + 5,
      );
    }
  }

  @override
  void didUpdateWidget(VfxStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hit = widget.life < _seenLife;
    _seenLife = widget.life;
    if (hit && widget.style != FinaleStyle.still) {
      _salt += 1;
      final pool = woundHits(widget.cast, widget.inks, _salt);
      final next = pickClip(pool, _hitId, _salt);
      if (next != null) {
        _hitId = next;
        _hitToken += 1;
      }
    }
    final tier = shownWoundTier(widget.wound, widget.band);
    final restyle =
        tier != _tier ||
        widget.style != oldWidget.style ||
        widget.cast != oldWidget.cast ||
        widget.band != oldWidget.band ||
        !_sameInks(widget.inks, oldWidget.inks);
    if (hit || restyle) _retarget(force: restyle);
    if (widget.victorious && !oldWidget.victorious) {
      TableAudio.play('win');
    }
    if (widget.victorious != oldWidget.victorious ||
        widget.style != oldWidget.style) {
      _crownId = widget.victorious
          ? pickClip(
              castPool(
                style: widget.style,
                role: VfxRole.crown,
                inks: widget.inks,
                seatColor: widget.seatColor,
                salt: _salt,
              ),
              _crownId,
              _salt + 5,
            )
          : null;
    }
  }

  bool _sameInks(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _retarget({required bool force}) {
    final tier = shownWoundTier(widget.wound, widget.band);
    final family = woundFamily(widget.cast, widget.inks);
    _tier = tier;
    if (tier == 0) {
      _baseId = null;
      _upperId = null;
      return;
    }
    final nextBase = tier == 1 ? family.mote : family.aura;
    if (force || _baseId != nextBase) _baseId = nextBase;
    if (tier >= 3 && family.upper != nextBase) {
      if (force || _upperId != family.upper) _upperId = family.upper;
    } else {
      _upperId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pace = (widget.style == FinaleStyle.lotus ? 0.7 : 1.0) *
        switch (_tier) {
          3 => 1.12,
          4 => 1.35,
          _ => 1.0,
        };
    final base = _baseId;
    final upper = _upperId;
    final hit = _hitId;
    final crown = widget.victorious ? _crownId : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        FxBoard(
          layers: [
            if (base != null)
              FxLayer(
                id: 'base-$base',
                clipId: base,
                loop: true,
                scale: woundScale(_tier),
                pace: pace,
              ),
            if (upper != null && upper != base)
              FxLayer(
                id: 'upper-$upper',
                clipId: upper,
                loop: true,
                scale: _tier >= 4 ? 1.4 : 1.12,
                pace: pace,
              ),
            if (hit != null)
              FxLayer(
                id: 'hit-$_hitToken',
                clipId: hit,
                scale: 1.35 + _tier * 0.08,
                pace: pace,
                onDone: () {
                  if (mounted) setState(() => _hitId = null);
                },
              ),
            if (crown != null)
              FxLayer(
                id: 'crown-$crown',
                clipId: crown,
                loop: true,
                scale: 1.08,
                pace: pace,
              ),
          ],
        ),
        if (hit != null &&
            woundFamily(widget.cast, widget.inks).aura == 'crisp-sparkle')
          _WoundFlick(key: ValueKey('mark-$_hitToken')),
      ],
    );
  }
}

class _WoundFlick extends StatefulWidget {
  const _WoundFlick({super.key});

  @override
  State<_WoundFlick> createState() => _WoundFlickState();
}

class _WoundFlickState extends State<_WoundFlick>
    with SingleTickerProviderStateMixin {
  late final AnimationController _play = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..forward();

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _play,
      builder: (context, _) {
        return CustomPaint(
          painter: _WoundPainter(_play.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _WoundPainter extends CustomPainter {
  const _WoundPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final fade = t < 0.28 ? t / 0.28 : (1 - (t - 0.28) / 0.72).clamp(0.0, 1.0);
    final len = size.shortestSide * 0.34;
    final center = size.center(Offset.zero);
    final dir = Offset(math.cos(-0.45), math.sin(-0.45));
    final a = center - dir * (len / 2);
    final b = center + dir * (len / 2);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 10
        ..color = const Color(0xFFFF2438).withValues(alpha: 0.35 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.5
        ..color = const Color(0xFFFFF1F3).withValues(alpha: 0.9 * fade),
    );
  }

  @override
  bool shouldRepaint(_WoundPainter oldDelegate) => oldDelegate.t != t;
}
