import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtg_table/domain/stats.dart';
import 'package:mtg_table/theme/app_theme.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({
    super.key,
    required this.ledger,
    required this.onClear,
  });

  final LocalLedger ledger;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    final records = ledger.playerRecords();
    final duels = ledger.headToHeads();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parties & stats'),
        actions: [
          if (ledger.games.isNotEmpty)
            IconButton(
              tooltip: 'Exporter CSV',
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: ledger.buildCsv()),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('CSV copié — collez dans Excel / Sheets'),
                  ),
                );
              },
              icon: const Icon(Icons.table_chart_outlined),
            ),
          if (ledger.games.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Effacer l’historique ?'),
                    content: const Text(
                      'Supprime les parties enregistrées sur cet appareil.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuler'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Effacer'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await onClear();
              },
              child: const Text('Effacer'),
            ),
        ],
      ),
      body: ledger.games.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucune partie enregistrée pour l’instant.\n'
                  'Quand quelqu’un gagne, la table propose d’archiver '
                  'avant une revanche — ou au retour au salon.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                const Text(
                  'Victoires',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final record in records)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(record.name),
                    subtitle: Text(
                      '${record.wins} victoire${record.wins > 1 ? 's' : ''} '
                      '· ${record.games} partie${record.games > 1 ? 's' : ''}',
                    ),
                    trailing: Text(
                      '${(record.winRate * 100).round()} %',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: accent,
                      ),
                    ),
                  ),
                if (duels.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Face à face',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final duel in duels)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${duel.a}  vs  ${duel.b}'),
                      trailing: Text(
                        '${duel.aWins} – ${duel.bWins}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Dernières parties',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final game in ledger.games.take(20))
                  Card(
                    color: const Color(0xFF12151C),
                    child: ListTile(
                      title: Text(
                        game.winner == null
                            ? 'Sans vainqueur clair'
                            : '${game.winner} gagne',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${game.players.join(' · ')}\n'
                        '${_formatDay(game.endedAt)}'
                        '${game.planechase ? ' · Planechase' : ''}'
                        '${game.durationSec > 0 ? ' · ${_formatDur(game.durationSec)}' : ''}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
              ],
            ),
    );
  }

  String _formatDay(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$d/$m/${date.year} · $h:$min';
  }

  String _formatDur(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      return '${h}h ${m % 60}min';
    }
    return '${m}min ${s.toString().padLeft(2, '0')}s';
  }
}
