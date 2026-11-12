import 'package:flutter/material.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/ui/widgets/help_tip.dart';

/// Couronne du rectangle : un ou deux commandants, avec un nom.
Future<void> showMyCommander(
  BuildContext context,
  GameController controller,
  String playerId,
) async {
  final player = controller.playerById(playerId);
  final names = await showSeatDialog<List<String>>(
    context,
    builder: (dialogContext) => _MyCommanderDialog(player: player),
  );
  if (names == null) return;
  controller.setMyCommanders(playerId, names: names);
}

class _MyCommanderDialog extends StatefulWidget {
  const _MyCommanderDialog({required this.player});

  final Player player;

  @override
  State<_MyCommanderDialog> createState() => _MyCommanderDialogState();
}

class _MyCommanderDialogState extends State<_MyCommanderDialog> {
  late int _count;
  late final TextEditingController _first;
  late final TextEditingController _second;

  @override
  void initState() {
    super.initState();
    final commanders = widget.player.commanders;
    _count = commanders.length >= 2 ? 2 : 1;
    _first = TextEditingController(text: _shown(commanders, 0));
    _second = TextEditingController(text: _shown(commanders, 1));
  }

  String _shown(List<Commander> commanders, int index) {
    if (index >= commanders.length) return '';
    final name = commanders[index].name;
    return isGenericCommanderName(name) ? '' : name;
  }

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _save() {
    final names = _count == 1
        ? [_first.text]
        : [_first.text, _second.text];
    Navigator.pop(context, names);
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    return AlertDialog(
      title: const Text('Mon commandant'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Chacun garde ses 21 points. Ils ne s’additionnent pas.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _countButton(1, 'Un')),
              const SizedBox(width: 8),
              Expanded(child: _countButton(2, 'Deux')),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _first,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: _count == 1 ? 'Nom' : 'Cdt 1',
              hintText: _count == 1 ? 'Vide : Cdt ${player.name}' : 'Vide : Cdt 1',
              isDense: true,
            ),
          ),
          if (_count == 2) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _second,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Cdt 2',
                hintText: 'Vide : Cdt 2',
                isDense: true,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  Widget _countButton(int count, String label) {
    final selected = _count == count;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: selected
            ? const Color(0xFFE7C98A)
            : const Color(0xFF2A2418),
        foregroundColor: selected ? const Color(0xFF1A1408) : Colors.white,
      ),
      onPressed: () => setState(() => _count = count),
      child: Text(label),
    );
  }

}

/// Couronne dorée, à la place de l’ancien œil, sur chaque rectangle.
class CommanderEmblem extends StatelessWidget {
  const CommanderEmblem({
    this.size = 22,
    this.color = const Color(0xFFE7C98A),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _CommanderEmblemPainter(color),
    );
  }
}

class _CommanderEmblemPainter extends CustomPainter {
  const _CommanderEmblemPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.scale(s);
    final gold = Paint()..color = color;
    final crown = Path()
      ..moveTo(3, 17.4)
      ..lineTo(5.4, 8.6)
      ..lineTo(8.4, 12.8)
      ..lineTo(12, 3.6)
      ..lineTo(15.6, 12.8)
      ..lineTo(18.6, 8.6)
      ..lineTo(21, 17.4)
      ..close();
    canvas.drawPath(crown, gold);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 16.6, 18, 3.6),
        const Radius.circular(0.9),
      ),
      gold,
    );
    final gem = Paint()..color = const Color(0xFF8E2A2A);
    canvas.drawCircle(const Offset(12, 8.2), 1.35, gem);
    canvas.drawCircle(const Offset(6.4, 11.4), 0.85, gem);
    canvas.drawCircle(const Offset(17.6, 11.4), 0.85, gem);
  }

  @override
  bool shouldRepaint(covariant _CommanderEmblemPainter oldDelegate) =>
      oldDelegate.color != color;
}

class MyCommanderButton extends StatelessWidget {
  const MyCommanderButton({
    required this.controller,
    required this.player,
    required this.showTips,
    this.size = 44,
  });

  final GameController controller;
  final Player player;
  final bool showTips;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      key: ValueKey('my-cmd-${player.id}'),
      width: size,
      height: size,
      child: Center(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0x33E7C98A),
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: size * 0.72,
            height: size * 0.72,
            child: Center(
              child: CommanderEmblem(size: size * 0.46),
            ),
          ),
        ),
      ),
    );
    final button = InkWell(
      onTap: () => showMyCommander(context, controller, player.id),
      child: showTips
          ? mark
          : SeatNote(message: 'Mon commandant', child: mark),
    );
    return HelpTip(
      enabled: showTips,
      longPress: false,
      title: 'Mon commandant',
      message:
          'Un ou deux commandants, avec un nom si tu veux. '
          'Un champ vide laisse Cdt et ton nom, ou Cdt 1 et Cdt 2.',
      child: button,
    );
  }
}
