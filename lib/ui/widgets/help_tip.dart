import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Sens de lecture d’un espace. 0 = bas de l’écran, 2 = joueur d’en face.
///
/// [turnsRadians] sert à la table ronde, quand le quart de tour ne suffit pas.
class SeatReading extends InheritedWidget {
  const SeatReading({
    required this.quarterTurns,
    this.turnsRadians,
    required super.child,
  });

  final int quarterTurns;
  final double? turnsRadians;

  static SeatReading? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SeatReading>();
  }

  static int turnsOf(BuildContext context) => maybeOf(context)?.quarterTurns ?? 0;

  @override
  bool updateShouldNotify(SeatReading oldWidget) =>
      oldWidget.quarterTurns != quarterTurns ||
      oldWidget.turnsRadians != turnsRadians;
}

/// Orientation à donner à une bulle, un menu ou une feuille ouverte depuis un espace.
class SeatFacing {
  const SeatFacing({required this.quarterTurns, this.radians});

  final int quarterTurns;
  final double? radians;

  static SeatFacing of(BuildContext context) {
    final scope = SeatReading.maybeOf(context);
    return SeatFacing(
      quarterTurns: scope?.quarterTurns ?? 0,
      radians: scope?.turnsRadians,
    );
  }

  bool get turned {
    if (radians != null && radians!.abs() > 0.01) return true;
    return quarterTurns % 4 != 0;
  }

  bool get swapsAxes => quarterTurns % 2 == 1 && radians == null;

  /// Tourne [child] comme l’espace qui l’a ouvert. Rien si l’espace est droit.
  Widget turn(Widget child) {
    final angle = radians;
    if (angle != null && angle.abs() > 0.01) {
      return Transform.rotate(angle: angle, child: child);
    }
    final turns = quarterTurns % 4;
    if (turns == 0) return child;
    return RotatedBox(quarterTurns: turns, child: child);
  }

  Widget inherit(Widget child) {
    return SeatReading(
      quarterTurns: quarterTurns,
      turnsRadians: radians,
      child: child,
    );
  }
}

/// Feuille ouverte depuis un espace : en bas si l’espace est droit,
/// au centre et dans son sens sinon.
Future<T?> presentForSeat<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final facing = SeatFacing.of(context);
  if (!facing.turned) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (dialogContext) {
      final media = MediaQuery.of(dialogContext);
      final boxW = (facing.swapsAxes ? media.size.height : media.size.width) - 24;
      final boxH = (facing.swapsAxes ? media.size.width : media.size.height) * 0.86;
      return facing.turn(
        Center(
          child: SizedBox(
            width: math.max(160, boxW),
            height: math.max(160, boxH),
            child: MediaQuery(
              data: media.copyWith(size: Size(math.max(160, boxW), math.max(160, boxH))),
              child: Material(
                color: Theme.of(dialogContext).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: facing.inherit(builder(dialogContext)),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Dialogue court (question, nom) dans le sens de l’espace.
Future<T?> showSeatDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color? barrierColor,
}) {
  final facing = SeatFacing.of(context);
  return showDialog<T>(
    context: context,
    barrierColor: barrierColor,
    builder: (dialogContext) {
      return facing.turn(facing.inherit(builder(dialogContext)));
    },
  );
}

/// Indication courte. Droite sur un espace droit, tournée avec les autres.
class SeatNote extends StatelessWidget {
  const SeatNote({required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (message.trim().isEmpty) return child;
    if (!SeatFacing.of(context).turned) {
      return Tooltip(message: message, child: child);
    }
    return HelpTip(message: message, longPress: false, child: child);
  }
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

  String get _namedMessage {
    final title = widget.title?.trim();
    final body = widget.message.trim();
    if (title == null || title.isEmpty) return body;
    if (body.toLowerCase().startsWith(title.toLowerCase())) return body;
    return '$title. $body';
  }

  void _hideTurnedBubble() {
    _bubble?.remove();
    _bubble = null;
  }

  void _showTurnedBubble() {
    _hideTurnedBubble();
    final facing = SeatFacing.of(context);
    if (!facing.turned) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _bubble = OverlayEntry(
      builder: (context) {
        final media = MediaQuery.of(context);
        final wide = facing.swapsAxes ? media.size.height : media.size.width;
        final tall = facing.swapsAxes ? media.size.width : media.size.height;
        return IgnorePointer(
          child: Center(
            child: facing.turn(
              ConstrainedBox(
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
                        _namedMessage,
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
    final facing = SeatFacing.of(context);
    if (facing.turned) return _showTurnedHelp(context, facing);
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
                        _namedMessage,
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

  /// Panneau centré, tourné comme l’espace qui l’a ouvert.
  Future<void> _showTurnedHelp(BuildContext context, SeatFacing facing) {
    final title = widget.title ?? 'À propos';
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (context) {
        final media = MediaQuery.of(context);
        final wide = facing.swapsAxes ? media.size.height : media.size.width;
        final tall = facing.swapsAxes ? media.size.width : media.size.height;
        return facing.turn(
          facing.inherit(
          Center(
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
                            _namedMessage,
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
          ),
        );
      },
    );
  }

  void _onHoverEnter() {
    _hoverTimer?.cancel();
    final facing = SeatFacing.of(context);
    _hoverTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (!facing.turned) {
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
    final turned = SeatFacing.of(context).turned;
    // Une bulle droite serait illisible pour le joueur d’en face ou de côté.
    final tip = !turned
        ? Tooltip(
            key: _tooltipKey,
            message: _namedMessage,
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

/// Explication du jour et de la nuit, lue dans le panneau du joueur concerné.
class SkyIntro extends InheritedWidget {
  const SkyIntro({
    super.key,
    required this.playerId,
    required this.title,
    required this.message,
    required this.onDismiss,
    required super.child,
  });

  final String? playerId;
  final String title;
  final String message;
  final VoidCallback onDismiss;

  static SkyIntro? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SkyIntro>();
  }

  @override
  bool updateShouldNotify(SkyIntro oldWidget) {
    return playerId != oldWidget.playerId ||
        title != oldWidget.title ||
        message != oldWidget.message;
  }
}
