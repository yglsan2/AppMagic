import 'dart:async';

import 'package:flutter/material.dart';

/// Aide contextuelle : survol souris (bulle) + appui long tactile (dialogue).
///
/// Les puces [InkWell] capturent souvent le long-press du Tooltip Material ;
/// l’appui long ouvre donc un dialogue lisible, fiable sur tablette.
class HelpTip extends StatefulWidget {
  const HelpTip({
    super.key,
    required this.message,
    required this.child,
    this.title,
    this.showIcon = false,
    this.enabled = true,
  });

  final String message;
  final String? title;
  final Widget child;
  final bool showIcon;
  final bool enabled;

  @override
  State<HelpTip> createState() => _HelpTipState();
}

class _HelpTipState extends State<HelpTip> {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();
  Timer? _hoverTimer;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  Future<void> _showDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.title ?? 'À propos'),
        content: SingleChildScrollView(child: Text(widget.message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  void _onHoverEnter() {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 350), () {
      _tooltipKey.currentState?.ensureTooltipVisible();
    });
  }

  void _onHoverExit() {
    _hoverTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.message.trim().isEmpty) {
      return widget.child;
    }

    final tip = Tooltip(
      key: _tooltipKey,
      message: widget.message,
      waitDuration: const Duration(milliseconds: 350),
      showDuration: const Duration(seconds: 8),
      preferBelow: true,
      // Évite la compétition avec les InkWell ; survol géré ci-dessous.
      triggerMode: TooltipTriggerMode.manual,
      child: MouseRegion(
        onEnter: (_) => _onHoverEnter(),
        onExit: (_) => _onHoverExit(),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPress: () => _showDialog(context),
          child: widget.child,
        ),
      ),
    );

    if (!widget.showIcon) return tip;
    return Row(
      children: [
        Flexible(child: tip),
        IconButton(
          tooltip: 'Explication',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => _showDialog(context),
          icon: Icon(
            Icons.info_outline,
            size: 18,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}
