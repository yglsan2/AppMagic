import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mtg_table/ui/widgets/table_audio.dart';

/// Bouton au doigt.
///
/// Un toucher court compte au relâchement, même si le doigt a un peu bougé.
/// Un maintien enchaîne. Si le doigt glisse franchement, le coup est annulé
/// (pour ne pas compter un défilement). Aucun recognizer de geste : le doigt
/// n’est pas perdu dans une compétition entre appui, appui long et défilement.
class RepeatTap extends StatefulWidget {
  const RepeatTap({
    super.key,
    required this.onTick,
    required this.child,
    this.enabled = true,

    /// Maintien = enchaîne. Sinon un seul coup au relâchement.
    this.repeat = true,
  });

  final VoidCallback onTick;
  final Widget child;
  final bool enabled;
  final bool repeat;

  @override
  State<RepeatTap> createState() => _RepeatTapState();
}

class _RepeatTapState extends State<RepeatTap> {
  static const _slop = 28.0;
  static const _holdDelay = Duration(milliseconds: 380);
  static const _repeat = Duration(milliseconds: 110);

  Timer? _delay;
  Timer? _timer;
  Offset? _origin;
  bool _down = false;
  bool _holdFired = false;
  bool _cancelled = false;

  void _clearTimers() {
    _delay?.cancel();
    _timer?.cancel();
    _delay = null;
    _timer = null;
  }

  void _reset() {
    _clearTimers();
    _down = false;
    _origin = null;
    _holdFired = false;
    _cancelled = false;
  }

  void _tick() {
    if (!mounted || !widget.enabled) return;
    TableAudio.playTouch();
    widget.onTick();
  }

  @override
  void dispose() {
    _clearTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (!widget.enabled || _down) return;
        _down = true;
        _cancelled = false;
        _holdFired = false;
        _origin = event.position;
        if (!widget.repeat) return;
        _delay = Timer(_holdDelay, () {
          if (!_down || _cancelled || !widget.enabled) return;
          _holdFired = true;
          _tick();
          _timer = Timer.periodic(_repeat, (_) {
            if (!_down || _cancelled || !mounted || !widget.enabled) {
              _clearTimers();
              return;
            }
            _tick();
          });
        });
      },
      onPointerMove: (event) {
        final origin = _origin;
        if (!_down || origin == null || _cancelled) return;
        if ((event.position - origin).distance > _slop) {
          _cancelled = true;
          _clearTimers();
          TableAudio.playSlide();
        }
      },
      onPointerUp: (_) {
        if (_down && !_cancelled && !_holdFired && widget.enabled) {
          _tick();
        }
        _reset();
      },
      onPointerCancel: (_) => _reset(),
      child: widget.child,
    );
  }
}

void buzz(bool enabled) {
  if (!enabled) return;
  HapticFeedback.selectionClick().catchError((Object _) {});
}
