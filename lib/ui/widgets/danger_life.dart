import 'package:flutter/material.dart';
import 'package:mtg_table/theme/app_theme.dart';

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
  });

  final int life;
  final int startingLife;
  final bool compact;

  /// Taille du chiffre. Sinon 68 en compact, 92 sinon.
  final double? fontSize;

  /// Sans le coussin autour du chiffre (ligne de PV perso).
  final bool tight;
  final Key? lifeKey;
  final VoidCallback? onTap;

  @override
  State<DangerLifeDisplay> createState() => _DangerLifeDisplayState();
}

class _DangerLifeDisplayState extends State<DangerLifeDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late LifeBand _band;

  @override
  void initState() {
    super.initState();
    _band = lifeBand(life: widget.life, startingLife: widget.startingLife);
    _pulse = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _band == LifeBand.critical ? 650 : 1100),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(DangerLifeDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = lifeBand(
      life: widget.life,
      startingLife: widget.startingLife,
    );
    if (next != _band) {
      _band = next;
      _pulse.duration = Duration(
        milliseconds: _band == LifeBand.critical ? 650 : 1100,
      );
      _syncPulse();
    }
  }

  void _syncPulse() {
    if (_band == LifeBand.safe) {
      _pulse
        ..stop()
        ..value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = lifeBandColor(_band);
    final size = widget.fontSize ?? (widget.compact ? 68.0 : 92.0);

    return GestureDetector(
      key: widget.lifeKey,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = _band == LifeBand.safe ? 0.0 : _pulse.value;
          final scale = 1 + (_band == LifeBand.critical ? 0.06 : 0.03) * t;
          final glow = (_band == LifeBand.critical ? 0.55 : 0.28) * (0.45 + t);
          return Transform.scale(
            scale: scale,
            child: Container(
              padding: widget.tight
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: _band == LifeBand.safe
                    ? null
                    : [
                        BoxShadow(
                          color: color.withValues(alpha: glow),
                          blurRadius: 28 + 16 * t,
                          spreadRadius: 2 + 4 * t,
                        ),
                      ],
              ),
              child: child,
            ),
          );
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: Tween(begin: 0.86, end: 1.0).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: FittedBox(
            key: ValueKey(widget.life),
            fit: BoxFit.scaleDown,
            child: Text('${widget.life}', style: lifeStyle(size, color)),
          ),
        ),
      ),
    );
  }
}

/// Bordure / teinte de panneau selon la menace PV.
class ThreatPanelShell extends StatefulWidget {
  const ThreatPanelShell({
    super.key,
    required this.band,
    required this.playerTint,
    required this.active,
    required this.defeated,
    required this.child,
  });

  final LifeBand band;
  final Color playerTint;
  final bool active;
  final bool defeated;
  final Widget child;

  @override
  State<ThreatPanelShell> createState() => _ThreatPanelShellState();
}

class _ThreatPanelShellState extends State<ThreatPanelShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sync();
  }

  @override
  void didUpdateWidget(ThreatPanelShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.band != widget.band ||
        oldWidget.defeated != widget.defeated) {
      _sync();
    }
  }

  void _sync() {
    final danger =
        !widget.defeated &&
        (widget.band == LifeBand.warning || widget.band == LifeBand.critical);
    if (danger) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threat = widget.defeated
        ? dangerCrit
        : switch (widget.band) {
            LifeBand.safe => widget.playerTint,
            LifeBand.warning => dangerWarn,
            LifeBand.critical => dangerCrit,
          };

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = widget.defeated ? 0.0 : _pulse.value;
        final borderW = widget.active
            ? 2.4
            : (widget.defeated || widget.band != LifeBand.safe
                ? 1.6 + (widget.band == LifeBand.critical ? 0.6 * t : 0)
                : 1.0);
        final wash = switch (widget.band) {
          LifeBand.safe => widget.active ? 0.08 : 0.0,
          LifeBand.warning => 0.10 + 0.06 * t,
          LifeBand.critical => 0.18 + 0.12 * t,
        };
        final tintBoost = widget.active ? 0.18 : 0.0;

        return Opacity(
          opacity: widget.defeated
              ? 0.48
              : widget.active
              ? 1.0
              : 0.58,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    threat.withValues(alpha: 0.22 + wash + tintBoost),
                    Color.alphaBlend(
                      widget.playerTint.withValues(
                        alpha: 0.28 + tintBoost,
                      ),
                      panelInk,
                    ),
                  ),
                  Color.alphaBlend(
                    threat.withValues(alpha: wash * 0.7),
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
                    : widget.active
                    ? widget.playerTint
                    : threat.withValues(
                        alpha: widget.band == LifeBand.safe
                            ? 0.22
                            : 0.85 + 0.15 * t,
                      ),
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
                        : 0.22 + 0.2 * t,
                  ),
                  blurRadius: widget.active
                      ? 26
                      : (widget.band == LifeBand.critical ? 22 + 10 * t : 10),
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
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
