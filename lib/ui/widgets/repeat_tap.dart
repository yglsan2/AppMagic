import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class RepeatTap extends StatefulWidget {
  const RepeatTap({
    super.key,
    required this.onTick,
    required this.child,
    this.enabled = true,
  });

  final VoidCallback onTick;
  final Widget child;
  final bool enabled;

  @override
  State<RepeatTap> createState() => _RepeatTapState();
}

class _RepeatTapState extends State<RepeatTap> {
  Timer? _timer;

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _start() {
    _stop();
    widget.onTick();
    var steps = 0;
    var fast = false;
    _timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted || !widget.enabled) {
        timer.cancel();
        return;
      }
      steps++;
      widget.onTick();
      if (!fast && steps >= 5) {
        fast = true;
        timer.cancel();
        _timer = Timer.periodic(const Duration(milliseconds: 70), (fastTimer) {
          if (!mounted || !widget.enabled) {
            fastTimer.cancel();
            return;
          }
          widget.onTick();
        });
      }
    });
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTick : null,
      onLongPressStart: widget.enabled ? (_) => _start() : null,
      onLongPressEnd: (_) => _stop(),
      onLongPressCancel: _stop,
      child: widget.child,
    );
  }
}

void buzz(bool enabled) {
  if (!enabled) return;
  HapticFeedback.selectionClick().catchError((Object _) {});
}
