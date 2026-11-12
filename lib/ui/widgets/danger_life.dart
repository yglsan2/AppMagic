import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/widgets/finale_fx.dart';
import 'package:mtg_table/ui/widgets/option_glyphs.dart';
import 'package:mtg_table/ui/widgets/table_audio.dart';
import 'package:mtg_table/ui/widgets/vfx_film.dart';

/// Aura + chiffre de vie qui pulsent en zone dangereuse.
class DangerLifeDisplay extends StatefulWidget {
  const DangerLifeDisplay({
    super.key,
    required this.life,
    required this.startingLife,
    required this.compact,
    this.fontSize,
    this.tight = false,
    this.lifeKey,
    this.onTap,
    this.steelLine = false,
  });

  final int life;
  final int startingLife;
  final bool compact;

  /// Taille du chiffre. Sinon 68 en compact, 92 sinon.
  final double? fontSize;

  /// Sans le coussin autour du chiffre (ligne de PV perso).
  final bool tight;
  final Key? lifeKey;
  final bool steelLine;
  final VoidCallback? onTap;

  @override
  State<DangerLifeDisplay> createState() => _DangerLifeDisplayState();
}

class _DangerLifeDisplayState extends State<DangerLifeDisplay>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _drop;
  late LifeBand _band;
  var _style = FinaleStyle.mythic;
  var _bound = false;
  var _gain = false;

  @override
  void initState() {
    super.initState();
    _band = lifeBand(life: widget.life, startingLife: widget.startingLife);
    _pulse = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _band == LifeBand.critical ? 920 : 1400),
    );
    _drop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _syncPulse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = FinaleScope.styleOf(context);
    if (_bound && next == _style) return;
    _style = next;
    _bound = true;
    _syncPulse();
  }

  @override
  void didUpdateWidget(DangerLifeDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.life != oldWidget.life && _style != FinaleStyle.still) {
      _gain = widget.life > oldWidget.life;
      _drop.duration = Duration(
        milliseconds: _style == FinaleStyle.lean || _style == FinaleStyle.carbon
            ? 140
            : 280,
      );
      _drop.forward(from: 0);
    }
    final next = lifeBand(
      life: widget.life,
      startingLife: widget.startingLife,
    );
    if (next != _band) {
      _band = next;
      _pulse.duration = Duration(
        milliseconds: _band == LifeBand.critical ? 920 : 1400,
      );
      _syncPulse();
    }
  }

  void _syncPulse() {
    final danger = _band != LifeBand.safe;
    if (_style == FinaleStyle.mythic && danger) {
      _pulse.duration = Duration(
        milliseconds: _band == LifeBand.critical ? 1080 : 1600,
      );
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
      return;
    }
    if (_style == FinaleStyle.lotus) {
      _holdLotus(danger);
      return;
    }
    _pulse
      ..stop()
      ..value = 0;
  }

  void _holdLotus(bool danger) {
    _pulse.duration = const Duration(milliseconds: 560);
    if (danger) {
      if (_pulse.status != AnimationStatus.forward && _pulse.value < 1) {
        _pulse.forward();
      }
      return;
    }
    if (_pulse.value > 0 && _pulse.status != AnimationStatus.reverse) {
      _pulse.reverse();
    }
  }

  List<Shadow> _numberShadows({required bool critical, required double blink}) {
    return switch (_style) {
      FinaleStyle.mythic when critical || blink > 0 => [
        const Shadow(color: Color(0xFF1A060A), offset: Offset(0, 2)),
        Shadow(
          color: sacreEmber.withValues(alpha: 0.2 + 0.35 * blink),
          blurRadius: 10 + 6 * blink,
        ),
      ],
      FinaleStyle.lotus => const [
        Shadow(color: Color(0xCC000000), offset: Offset(0, 2), blurRadius: 6),
      ],
      FinaleStyle.carbon => const [
        Shadow(color: Color(0xE6000000), offset: Offset(0, 2)),
      ],
      FinaleStyle.still => const [
        Shadow(color: Color(0x99000000), blurRadius: 4),
      ],
      _ => [
        Shadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 8,
        ),
      ],
    };
  }

  @override
  void dispose() {
    _pulse.dispose();
    _drop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = lifeBandColor(_band);
    final size = widget.fontSize ?? (widget.compact ? 68.0 : 92.0);
    final critical = _band == LifeBand.critical;
    final still = _style == FinaleStyle.still;

    return GestureDetector(
      key: widget.lifeKey,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _drop]),
        builder: (context, child) {
          final blink = _style == FinaleStyle.mythic && _band != LifeBand.safe
              ? _pulse.value
              : _style == FinaleStyle.lotus
              ? Curves.easeInOutCubic.transform(_pulse.value)
              : 0.0;
          final scale = switch (_style) {
            FinaleStyle.mythic =>
              1 + (critical ? 0.04 : 0.02) * blink,
            FinaleStyle.arena => 1 + 0.07 * (_drop.value == 0 || _drop.value == 1
                ? 0
                : 1 - Curves.easeOut.transform(_drop.value)),
            _ => 1.0,
          };
          final glow = switch (_style) {
            FinaleStyle.mythic =>
              (critical ? 0.4 : 0.2) * (0.35 + 0.65 * blink),
            FinaleStyle.lean => critical ? 0.2 : 0.0,
            FinaleStyle.arena => 0.0,
            _ => 0.0,
          };
          final hit = still || _drop.value == 0 || _drop.value == 1
              ? 0.0
              : 1 - Curves.easeOut.transform(_drop.value);
          final flashColor = switch (_style) {
            FinaleStyle.carbon => const Color(0xFFD5DCE6),
            FinaleStyle.lotus => const Color(0xFFF4E8E2),
            FinaleStyle.mythic when _gain => const Color(0xFFFFF3C4),
            FinaleStyle.mythic => sacreIvory,
            _ when _gain => const Color(0xFFFFF6D8),
            _ => const Color(0xFFFFF4F0),
          };
          final rested = _style == FinaleStyle.lotus && _band != LifeBand.safe
              ? Color.lerp(color, const Color(0xFFE4C8C0), blink * 0.8)!
              : color;
          final shown = Color.lerp(rested, flashColor, hit * 0.9)!;
          return Transform.scale(
            scale: scale,
            child: Container(
              padding: widget.tight
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: glow == 0 && hit == 0
                    ? null
                    : [
                        if (_style == FinaleStyle.mythic)
                          BoxShadow(
                            color: const Color(0xFF2A0A10).withValues(
                              alpha: 0.4 + 0.2 * blink,
                            ),
                            blurRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        BoxShadow(
                          color: (_gain
                                  ? const Color(0xFFFFE7A3)
                                  : (_style == FinaleStyle.mythic
                                      ? sacreEmber
                                      : shown))
                              .withValues(
                                alpha: (glow + hit * 0.22).clamp(0.0, 0.7),
                              ),
                          blurRadius: _style == FinaleStyle.mythic
                              ? 14 + 8 * blink
                              : 6,
                          spreadRadius: 0,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: AnimatedSwitcher(
                duration: Duration(
                  milliseconds: switch (_style) {
                    FinaleStyle.still => 0,
                    FinaleStyle.lotus => 420,
                    FinaleStyle.carbon || FinaleStyle.lean => 120,
                    FinaleStyle.arena => 140,
                    _ => 180,
                  },
                ),
                transitionBuilder: (next, anim) {
                  if (_style == FinaleStyle.lotus ||
                      _style == FinaleStyle.carbon ||
                      _style == FinaleStyle.still) {
                    return FadeTransition(opacity: anim, child: next);
                  }
                  final begin = _style == FinaleStyle.arena ? 1.1 : 0.86;
                  return ScaleTransition(
                    scale: Tween(begin: begin, end: 1.0).animate(anim),
                    child: FadeTransition(opacity: anim, child: next),
                  );
                },
                child: FittedBox(
                  key: ValueKey(widget.life),
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.life}',
                        style: lifeStyle(size, shown).copyWith(
                          shadows: _numberShadows(
                            critical: critical,
                            blink: blink,
                          ),
                        ),
                      ),
                      if (widget.steelLine && _style == FinaleStyle.carbon)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          height: 1,
                          width: size * 0.55,
                          color: chiselEdge,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bordure / teinte de panneau selon la menace PV.
class ThreatPanelShell extends StatefulWidget {
  const ThreatPanelShell({
    super.key,
    required this.band,
    required this.life,
    required this.startingLife,
    required this.playerTint,
    required this.active,
    required this.defeated,
    required this.child,
    this.victorious = false,
    this.dimmed = false,
    this.wound = 0,
    this.inks = const [],
    this.cast = CastTone.standard,
    this.seatColor = 0,
    this.strikeKnown = false,
    this.strikeInks = const [],
    this.strikeSeat = 0,
  });

  final LifeBand band;
  final int life;
  final int startingLife;
  final Color playerTint;
  final bool active;
  final bool defeated;
  final bool victorious;
  final bool dimmed;
  final int wound;
  final List<String> inks;
  final CastTone cast;
  final int seatColor;
  final bool strikeKnown;
  final List<String> strikeInks;
  final int strikeSeat;
  final Widget child;

  @override
  State<ThreatPanelShell> createState() => _ThreatPanelShellState();
}

class _ThreatPanelShellState extends State<ThreatPanelShell>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _hit;
  late final AnimationController _win;
  late final AnimationController _burst;
  late final AnimationController _boon;
  late final AnimationController _aura;
  var _style = FinaleStyle.mythic;
  var _bound = false;
  var _strength = 1.0;
  Timer? _crown;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
    _hit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _win = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _boon = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _aura = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _syncAura();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = FinaleScope.styleOf(context);
    if (_bound && next == _style) return;
    _style = next;
    _bound = true;
    _sync();
    _syncWin();
    _syncAura();
  }

  @override
  void didUpdateWidget(ThreatPanelShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.band != widget.band ||
        oldWidget.defeated != widget.defeated) {
      _sync();
    }
    if (widget.life != oldWidget.life &&
        _style != FinaleStyle.still &&
        widget.cast != CastTone.aucune) {
      TableAudio.playWound(widget.life - oldWidget.life);
    }
    if (widget.life < oldWidget.life && _style != FinaleStyle.still) {
      final drop = oldWidget.life - widget.life;
      final lethalLife = _style == FinaleStyle.mythic &&
          widget.defeated &&
          oldWidget.life > 0 &&
          widget.life <= 0;
      if (!lethalLife) {
        _strength = (drop / 8).clamp(0.28, 1.0);
        _hit.duration = Duration(
          milliseconds: _style == FinaleStyle.lean || _style == FinaleStyle.carbon
              ? 140
              : drop <= 2
              ? 180
              : 420,
        );
        _hit.forward(from: 0);
      }
    }
    if (widget.life > oldWidget.life &&
        _style != FinaleStyle.still &&
        widget.cast != CastTone.aucune) {
      _boon.forward(from: 0);
    }
    if (widget.life != oldWidget.life ||
        widget.defeated != oldWidget.defeated ||
        widget.cast != oldWidget.cast ||
        widget.startingLife != oldWidget.startingLife) {
      _syncAura();
    }
    if (widget.victorious != oldWidget.victorious) _syncWin();
  }

  void _syncWin() {
    _crown?.cancel();
    if (widget.victorious && _style == FinaleStyle.mythic) {
      _crown = Timer(const Duration(milliseconds: 120), () {
        if (!mounted || !widget.victorious || _style != FinaleStyle.mythic) {
          return;
        }
        if (_burst.value == 0 && !_burst.isAnimating) _burst.forward();
        if (_win.value == 0 && !_win.isAnimating) _win.forward();
      });
      return;
    }
    if (widget.victorious && _style == FinaleStyle.arena) {
      if (!_burst.isAnimating && _burst.value == 0) _burst.forward();
      return;
    }
    _burst
      ..stop()
      ..value = 0;
    _win
      ..stop()
      ..value = 0;
  }

  void _sync() {
    final danger =
        !widget.defeated &&
        (widget.band == LifeBand.warning || widget.band == LifeBand.critical);
    if (_style != FinaleStyle.lotus && danger) {
      _pulse.duration = Duration(
        milliseconds: widget.band == LifeBand.critical ? 720 : 1100,
      );
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
      return;
    }
    if (_style == FinaleStyle.lotus) {
      _pulse.duration = const Duration(milliseconds: 560);
      if (danger) {
        if (_pulse.status != AnimationStatus.forward && _pulse.value < 1) {
          _pulse.forward();
        }
      } else if (_pulse.value > 0 &&
          _pulse.status != AnimationStatus.reverse) {
        _pulse.reverse();
      }
      return;
    }
    _pulse
      ..stop()
      ..value = _style == FinaleStyle.lean && danger ? 1 : 0;
  }

  void _syncAura() {
    final blessed = !widget.defeated &&
        widget.life > widget.startingLife &&
        _style != FinaleStyle.still &&
        widget.cast != CastTone.aucune;
    if (blessed) {
      if (!_aura.isAnimating) _aura.repeat(reverse: true);
      return;
    }
    _aura
      ..stop()
      ..value = 0;
  }

  @override
  void dispose() {
    _crown?.cancel();
    _pulse.dispose();
    _hit.dispose();
    _win.dispose();
    _burst.dispose();
    _boon.dispose();
    _aura.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threat = widget.defeated
        ? switch (_style) {
            FinaleStyle.lotus => const Color(0xFF3A342C),
            FinaleStyle.carbon => chiselEdge,
            FinaleStyle.mythic => sacreCrimson,
            _ => dangerCrit,
          }
        : switch (_style) {
            FinaleStyle.mythic => switch (widget.band) {
              LifeBand.safe => widget.playerTint,
              LifeBand.warning => const Color(0xFFE07A3A),
              LifeBand.critical => sacreCrimson,
            },
            FinaleStyle.carbon => widget.band == LifeBand.critical
                ? chiselEdge
                : widget.playerTint,
            FinaleStyle.lotus => widget.playerTint,
            _ => switch (widget.band) {
              LifeBand.safe => widget.playerTint,
              LifeBand.warning => const Color(0xFFE07A3A),
              LifeBand.critical => const Color(0xFFD0122A),
            },
          };

    final showFx = !widget.defeated &&
        _style != FinaleStyle.still &&
        widget.cast != CastTone.aucune;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
      opacity: widget.dimmed ? 0.58 : 1,
      duration: const Duration(milliseconds: 420),
      child: AnimatedBuilder(
      animation: Listenable.merge([_pulse, _hit, _win, _burst, _boon, _aura]),
      builder: (context, child) {
        final critical = widget.band == LifeBand.critical;
        final dangerBand = widget.band != LifeBand.safe;
        final blink = !dangerBand || widget.defeated
            ? 0.0
            : _style == FinaleStyle.lotus
            ? Curves.easeInOutCubic.transform(_pulse.value)
            : _pulse.value;
        final borderW = widget.band == LifeBand.critical
            ? 3.8 + 1.6 * blink
            : widget.band == LifeBand.warning
            ? 2.8 + 0.8 * blink
            : widget.active
            ? 2.4
            : (widget.defeated ? 1.6 : 1.0);
        final wash = switch (_style) {
          FinaleStyle.mythic => switch (widget.band) {
            LifeBand.safe => widget.active ? 0.08 : 0.0,
            LifeBand.warning => 0.12 + 0.22 * blink,
            LifeBand.critical => 0.22 + 0.34 * blink,
          },
          FinaleStyle.lean => switch (widget.band) {
            LifeBand.critical => 0.2,
            LifeBand.warning => 0.08,
            LifeBand.safe => 0.0,
          },
          FinaleStyle.still => widget.band == LifeBand.critical ? 0.14 : 0.0,
          FinaleStyle.arena => widget.band == LifeBand.critical ? 0.12 : 0.0,
          FinaleStyle.seal => widget.band == LifeBand.critical ? 0.06 : 0.0,
          _ => widget.active ? 0.06 : 0.0,
        };
        final dangerFloor = switch (widget.band) {
          LifeBand.safe => 0.0,
          LifeBand.warning => 0.22 + 0.14 * blink,
          LifeBand.critical => 0.38 + 0.24 * blink,
        };
        final washShown = wash < dangerFloor ? dangerFloor : wash;
        final tintBoost = widget.active ? 0.18 : 0.0;
        final danger =
            !widget.defeated && widget.band != LifeBand.safe;
        final winT = _win.value;
        final hitT = Curves.easeIn.transform(_hit.value);
        final night = TableDay.of(context) == DayState.night;

        final plate = DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    threat.withValues(alpha: 0.22 + washShown + tintBoost),
                    Color.alphaBlend(
                      widget.playerTint.withValues(
                        alpha: 0.28 + tintBoost,
                      ),
                      panelInk,
                    ),
                  ),
                  Color.alphaBlend(
                    threat.withValues(alpha: washShown * 0.7),
                    Color.alphaBlend(
                      widget.playerTint.withValues(
                        alpha: widget.active ? 0.22 : 0.10,
                      ),
                      ink,
                    ),
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.defeated
                    ? dangerCrit
                    : widget.band != LifeBand.safe
                    ? threat
                    : widget.active
                    ? widget.playerTint
                    : threat.withValues(alpha: 0.22),
                width: borderW,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.active ? widget.playerTint : threat)
                      .withValues(
                    alpha: widget.active
                        ? 0.55
                        : widget.band == LifeBand.safe
                        ? 0.04
                        : 0.12 + 0.4 * blink,
                  ),
                  blurRadius: widget.active
                      ? 26
                      : (critical ? 18 + 16 * blink : 8 + 6 * blink),
                  spreadRadius: widget.active ? 1.5 : 0,
                  offset: const Offset(0, 5),
                ),
                if (widget.active)
                  BoxShadow(
                    color: widget.playerTint.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 0.5,
                  ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                child!,
                SkyVeil(state: TableDay.of(context), tint: widget.playerTint),
                if (!widget.defeated &&
                    _style != FinaleStyle.still &&
                    widget.cast != CastTone.aucune &&
                    (_aura.value > 0.01 ||
                        (_boon.value > 0 && _boon.value < 1)))
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _BoonPainter(
                        flash: _boon.value,
                        aura: _aura.value,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (dangerBand && !widget.defeated)
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: RadialGradient(
                          colors: [
                            const Color(0x00FF2438),
                            threat.withValues(
                              alpha: critical
                                  ? 0.22 + 0.28 * blink
                                  : 0.16 + 0.12 * blink,
                            ),
                          ],
                          stops: [critical ? 0.42 : 0.62, 1],
                        ),
                      ),
                    ),
                  ),
                if (_style == FinaleStyle.lotus && blink > 0.02 && !widget.defeated)
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: epitaphInk.withValues(alpha: 0.32 * blink),
                      ),
                    ),
                  ),
                if (_style == FinaleStyle.mythic && blink > 0.55 && !widget.defeated)
                  IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.all(1.5),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: sacreEmber.withValues(
                              alpha: ((blink - 0.55) / 0.45).clamp(0.0, 1.0) * 0.85,
                            ),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_hit.value > 0 &&
                    _hit.value < 1 &&
                    _style != FinaleStyle.still &&
                    widget.cast != CastTone.aucune)
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: switch (_style) {
                          FinaleStyle.mythic => sacreCrimson.withValues(
                            alpha: (1 - hitT) * 0.5 * _strength,
                          ),
                          FinaleStyle.arena => const Color(0xFFFF4D3A).withValues(
                            alpha: (1 - hitT) * 0.42,
                          ),
                          FinaleStyle.carbon => chiselSteel.withValues(
                            alpha: (1 - hitT) * 0.32,
                          ),
                          FinaleStyle.lotus => epitaphWarm.withValues(
                            alpha: (1 - hitT) * 0.28,
                          ),
                          FinaleStyle.lean => sacreCrimson.withValues(
                            alpha: (1 - hitT) * 0.22,
                          ),
                          _ => sacreCrimson.withValues(alpha: (1 - hitT) * 0.3),
                        },
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (widget.victorious && _style == FinaleStyle.mythic)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: WinnerAuraPainter(
                        pulse: winT,
                        burst: _burst.value,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (widget.victorious && _style == FinaleStyle.seal)
                  const IgnorePointer(
                    child: CustomPaint(
                      painter: SealPainter(progress: 1, gold: true),
                      child: SizedBox.expand(),
                    ),
                  ),
                if (!widget.defeated &&
                    danger &&
                    _style == FinaleStyle.seal)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: SealPainter(progress: critical ? 1 : 0.65),
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
        );
        final dimmed = TweenAnimationBuilder<double>(
          tween: Tween(end: night ? SkyVeil.warmNight : 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          builder: (context, scale, child) {
            if (scale > 0.995) return child!;
            return ColorFiltered(
              colorFilter: SkyVeil.warmNightFilter(scale),
              child: child,
            );
          },
          child: plate,
        );
        return dimmed;
      },
      child: widget.child,
    ),
        ),
        if (showFx)
          IgnorePointer(
            child: VfxStage(
              style: _style,
              inks: widget.inks,
              cast: widget.cast,
              seatColor: widget.seatColor,
              life: widget.life,
              wound: widget.wound,
              band: widget.band,
              victorious: widget.victorious,
              strikeKnown: widget.strikeKnown,
              strikeInks: widget.strikeInks,
              strikeSeat: widget.strikeSeat,
            ),
          ),
      ],
    );
  }
}

/// Lumière brève au gain, et halo tant que la vie dépasse le départ.
class _BoonPainter extends CustomPainter {
  const _BoonPainter({required this.flash, required this.aura});

  final double flash;
  final double aura;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    if (aura > 0.01) {
      final veil = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 0.85,
          colors: [
            const Color(0xFFFFF6D2).withValues(alpha: 0.05 + 0.10 * aura),
            const Color(0xFFFFE08A).withValues(alpha: 0.04 + 0.06 * aura),
            const Color(0x00FFF6D2),
          ],
          stops: const [0.0, 0.42, 1],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(1.5), const Radius.circular(18)),
        veil,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(18)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFFFE7A8).withValues(alpha: 0.18 + 0.28 * aura),
      );
    }
    if (flash <= 0 || flash >= 1) return;
    final spots = <(double, double, double)>[
      (0.50, 0.40, 0.0),
      (0.30, 0.28, 0.16),
      (0.70, 0.30, 0.30),
      (0.42, 0.62, 0.42),
    ];
    for (final (fx, fy, start) in spots) {
      if (flash < start) continue;
      final local = ((flash - start) / 0.38).clamp(0.0, 1.0);
      if (local >= 1) continue;
      final a = 4 * local * (1 - local);
      canvas.drawCircle(
        Offset(size.width * fx, size.height * fy),
        8 + 18 * a,
        Paint()..color = const Color(0xFFFFF8DC).withValues(alpha: 0.62 * a),
      );
    }
    final bloom = 4 * flash * (1 - flash);
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFFFFF1C2).withValues(alpha: 0.16 * bloom),
    );
  }

  @override
  bool shouldRepaint(covariant _BoonPainter oldDelegate) =>
      oldDelegate.flash != flash || oldDelegate.aura != aura;
}
