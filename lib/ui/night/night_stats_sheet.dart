import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtg_table/domain/night_session.dart';
import 'package:mtg_table/theme/app_theme.dart';

Future<void> showNightStatsSheet(BuildContext context, NightSession night) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: NightStatsSheet(night: night),
      );
    },
  );
}

class NightStatsSheet extends StatelessWidget {
  const NightStatsSheet({super.key, required this.night});

  final NightSession night;

  Future<void> _copy(BuildContext context, String text, String ok) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok)));
  }

  @override
  Widget build(BuildContext context) {
    final board = night.standings();
    final duels = night.headToHeads();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Stats de la soirée',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Fermer',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            '${night.title} · ${night.code} · ${night.games.length} partie'
            '${night.games.length > 1 ? 's' : ''}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _copy(
                  context,
                  night.buildCsv(),
                  'CSV copié — collez dans Excel / Sheets.',
                ),
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: const Text('Copier CSV'),
              ),
              OutlinedButton.icon(
                onPressed: () => _copy(
                  context,
                  night.buildRecap(),
                  'Récap texte copié.',
                ),
                icon: const Icon(Icons.copy_all, size: 18),
                label: const Text('Copier texte'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                const Text(
                  'Classement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '3 pts victoire · 2 équipe · 1 présence',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 8),
                if (board.isEmpty)
                  Text(
                    'Aucune partie archivée pour l’instant.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  )
                else
                  for (var i = 0; i < board.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: i == 0
                            ? accentGold
                            : Colors.white.withValues(alpha: 0.12),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: i == 0 ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      title: Text(
                        board[i].name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${board[i].wins}V (${board[i].soloWins} solo · '
                        '${board[i].teamWins} équipe) · '
                        '${board[i].games} parties'
                        '${board[i].avgDurationSec > 0 ? ' · '
                            '~${(board[i].avgDurationSec / 60).round()} min' : ''}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${board[i].points} pts',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${(board[i].winRate * 100).round()} %',
                            style: TextStyle(
                              color: accent.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                if (duels.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Face à face',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  for (final d in duels)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${d.a}  vs  ${d.b}'),
                      trailing: Text(
                        '${d.aWins} – ${d.bWins}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
                if (night.games.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Parties',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  for (final game in night.games.take(24))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        game.winner == null
                            ? 'Sans vainqueur clair'
                            : 'Victoire · ${game.winner}',
                      ),
                      subtitle: Text(
                        [
                          game.format,
                          if (game.podId != null)
                            night.podById(game.podId!)?.label ?? 'Table',
                          '${(game.durationSec / 60).ceil()} min',
                          if (game.commanders.isNotEmpty)
                            game.commanders.take(2).join(' · '),
                        ].join(' · '),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
