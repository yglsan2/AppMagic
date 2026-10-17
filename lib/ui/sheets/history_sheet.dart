import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtg_table/data/safe_image.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/journal_event.dart';
import 'package:mtg_table/domain/recap.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/sheets/card_journal_sheet.dart';

Future<void> showHistorySheet(BuildContext context, GameController controller) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: HistorySheet(controller: controller),
      );
    },
  );
}

enum _HistoryFilter { all, life, cards, notes }

class HistorySheet extends StatefulWidget {
  const HistorySheet({super.key, required this.controller});

  final GameController controller;

  @override
  State<HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<HistorySheet> {
  _HistoryFilter _filter = _HistoryFilter.all;

  Future<void> _copyExport() async {
    final text = buildJournalExport(widget.controller);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Journal copié — collez-le où vous voulez.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final game = controller.game;
        final journal = _filteredJournal(controller.journal);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Historique & journal',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Exporter',
                  onPressed: _copyExport,
                  icon: const Icon(Icons.copy_all),
                ),
                TextButton.icon(
                  onPressed: () =>
                      showCardJournalSheet(context, controller),
                  icon: const Icon(Icons.style_outlined, size: 18),
                  label: const Text('Carte'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Les PV se recalculent via Annuler. Touchez une action pour '
              'revenir à cet état.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final entry in const [
                  (_HistoryFilter.all, 'Tout'),
                  (_HistoryFilter.life, 'PV'),
                  (_HistoryFilter.cards, 'Cartes'),
                  (_HistoryFilter.notes, 'Notes'),
                ])
                  FilterChip(
                    label: Text(entry.$2),
                    selected: _filter == entry.$1,
                    onSelected: (_) => setState(() => _filter = entry.$1),
                  ),
              ],
            ),
            if (_filter == _HistoryFilter.all ||
                _filter == _HistoryFilter.life) ...[
              const SizedBox(height: 12),
              for (final player in game.players) ...[
                Text(
                  player.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 42,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _SparkPainter(
                      controller.lifeSeries(player.id),
                      playerColor(player.color),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
            if (journal.isNotEmpty &&
                (_filter == _HistoryFilter.all ||
                    _filter == _HistoryFilter.cards ||
                    _filter == _HistoryFilter.notes)) ...[
              const Divider(),
              const Text(
                'Journal de cartes',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 8),
              for (final event in journal) _JournalTile(event: event),
            ],
            if (_filter == _HistoryFilter.all ||
                _filter == _HistoryFilter.life) ...[
              const Divider(),
              const Text(
                'Actions',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 8),
              if (controller.historyLength == 0)
                const Text('Aucune action pour le moment.'),
              for (var index = controller.historyLength - 1; index >= 0; index--)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(controller.historyLabel(index)),
                  trailing: const Icon(Icons.undo),
                  onTap: () {
                    controller.undoSteps(controller.historyLength - index);
                  },
                ),
            ],
            const SizedBox(height: 12),
            Text(
              'Cartes : Scryfall · images © Wizards of the Coast',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        );
      },
    );
  }

  List<JournalEvent> _filteredJournal(List<JournalEvent> journal) {
    return switch (_filter) {
      _HistoryFilter.all => journal,
      _HistoryFilter.life => const [],
      _HistoryFilter.cards => [
        for (final e in journal)
          if (e.kind == JournalKind.cardPlayed ||
              e.kind == JournalKind.landPlayed ||
              e.kind == JournalKind.assistedEffect)
            e,
      ],
      _HistoryFilter.notes => [
        for (final e in journal)
          if (e.kind == JournalKind.manualNote) e,
      ],
    };
  }
}

class _JournalTile extends StatelessWidget {
  const _JournalTile({required this.event});

  final JournalEvent event;

  @override
  Widget build(BuildContext context) {
    final kindLabel = switch (event.kind) {
      JournalKind.landPlayed => 'Terrain',
      JournalKind.cardPlayed => 'Carte',
      JournalKind.assistedEffect => 'Effet',
      JournalKind.manualNote => 'Note',
    };
    final time = _formatClock(event.createdAt);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: event.artUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SafeNetworkImage(
                url: event.artUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.style_outlined),
              ),
            )
          : const Icon(Icons.notes),
      title: Text(event.label),
      subtitle: Text(
        '$time · $kindLabel · manche ${event.roundNumber} · tour '
        '${event.turnCount}'
        '${event.note == null ? '' : ' · ${event.note}'}',
      ),
    );
  }
}

String _formatClock(DateTime at) {
  final h = at.hour.toString().padLeft(2, '0');
  final m = at.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    var minValue = values.first;
    var maxValue = values.first;
    for (final value in values) {
      if (value < minValue) minValue = value;
      if (value > maxValue) maxValue = value;
    }
    final span = (maxValue - minValue).abs();
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width
          : size.width * i / (values.length - 1);
      final t = span == 0 ? 0.5 : (values[i] - minValue) / span;
      final y = size.height - (t * (size.height - 4)) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
