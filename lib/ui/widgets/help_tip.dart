import 'dart:async';

import 'package:flutter/material.dart';

/// Sens de lecture d’un siège. 0 = bas de l’écran, 2 = joueur d’en face.
class SeatReading extends InheritedWidget {
  const SeatReading({required this.quarterTurns, required super.child});

  final int quarterTurns;

  static int turnsOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SeatReading>();
    return scope?.quarterTurns ?? 0;
  }

  @override
  bool updateShouldNotify(SeatReading oldWidget) =>
      oldWidget.quarterTurns != quarterTurns;
}

/// Aide contextuelle.
///
/// Souris : bulle limitée à la largeur de l’écran, le texte passe à la ligne.
/// Téléphone : pas de bulle flottante. Un appui long, ou l’icône i, ouvre
/// un panneau bas qui reste dans l’écran et défile si le texte est long.
class HelpTip extends StatefulWidget {
  const HelpTip({
    super.key,
    required this.message,
    required this.child,
    this.title,
    this.showIcon = false,
    this.enabled = true,
    this.longPress = true,
  });

  final String message;
  final String? title;
  final Widget child;
  final bool showIcon;
  final bool enabled;

  /// Maintien = explication. Désactivé sur les boutons qui s’enchaînent au maintien.
  final bool longPress;

  @override
  State<HelpTip> createState() => _HelpTipState();
}

class _HelpTipState extends State<HelpTip> {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();
  Timer? _hoverTimer;
  OverlayEntry? _bubble;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _bubble?.remove();
    _bubble = null;
    super.dispose();
  }

  void _hideTurnedBubble() {
    _bubble?.remove();
    _bubble = null;
  }

  void _showTurnedBubble() {
    _hideTurnedBubble();
    final turns = SeatReading.turnsOf(context) % 4;
    if (turns == 0) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _bubble = OverlayEntry(
      builder: (context) {
        final media = MediaQuery.of(context);
        final wide = turns.isOdd ? media.size.height : media.size.width;
        final tall = turns.isOdd ? media.size.width : media.size.height;
        return IgnorePointer(
          child: Center(
            child: RotatedBox(
              quarterTurns: turns,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (wide - 48).clamp(160.0, 340.0),
                  maxHeight: tall * 0.7,
                ),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: SingleChildScrollView(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_bubble!);
  }

  Future<void> _showHelp(BuildContext context) {
    final turns = SeatReading.turnsOf(context) % 4;
    if (turns != 0) return _showTurnedHelp(context, turns);
    final title = widget.title ?? 'À propos';
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        final bottom = media.viewPadding.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Compris'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Panneau centré, tourné comme le siège qui l’a ouvert.
  Future<void> _showTurnedHelp(BuildContext context, int turns) {
    final title = widget.title ?? 'À propos';
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (context) {
        final media = MediaQuery.of(context);
        final wide = turns.isOdd ? media.size.height : media.size.width;
        final tall = turns.isOdd ? media.size.width : media.size.height;
        return RotatedBox(
          quarterTurns: turns,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: wide - 28,
                maxHeight: tall * 0.8,
              ),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        fit: FlexFit.loose,
                        child: SingleChildScrollView(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Compris'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onHoverEnter() {
    _hoverTimer?.cancel();
    final turns = SeatReading.turnsOf(context) % 4;
    _hoverTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (turns == 0) {
        _tooltipKey.currentState?.ensureTooltipVisible();
      } else {
        _showTurnedBubble();
      }
    });
  }

  void _onHoverExit() {
    _hoverTimer?.cancel();
    _hideTurnedBubble();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.message.trim().isEmpty) {
      return widget.child;
    }

    final help = widget.longPress
        ? GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: () => _showHelp(context),
            child: widget.child,
          )
        : widget.child;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final turned = SeatReading.turnsOf(context) % 4 != 0;
    // Une bulle droite serait illisible pour le joueur d’en face ou de côté.
    final tip = !turned
        ? Tooltip(
            key: _tooltipKey,
            message: widget.message,
            waitDuration: const Duration(milliseconds: 350),
            showDuration: const Duration(seconds: 8),
            preferBelow: true,
            triggerMode: TooltipTriggerMode.manual,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            constraints: BoxConstraints(
              maxWidth: (screenWidth - 32).clamp(160.0, 340.0),
            ),
            child: MouseRegion(
              onEnter: (_) => _onHoverEnter(),
              onExit: (_) => _onHoverExit(),
              child: help,
            ),
          )
        : MouseRegion(
            onEnter: (_) => _onHoverEnter(),
            onExit: (_) => _onHoverExit(),
            child: help,
          );

    if (!widget.showIcon) return tip;
    return Row(
      children: [
        Flexible(child: tip),
        IconButton(
          tooltip: turned ? null : 'Explication',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: () => _showHelp(context),
          icon: Icon(
            Icons.info_outline,
            size: 18,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
