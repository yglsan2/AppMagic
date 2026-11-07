import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/night_session.dart';
import 'package:mtg_table/domain/night_transfer.dart';
import 'package:mtg_table/domain/player_profile.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/night/night_stats_sheet.dart';
import 'package:mtg_table/ui/widgets/name_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Hub central de la soirée multi-tables.
class NightHubScreen extends StatefulWidget {
  const NightHubScreen({
    super.key,
    required this.night,
    required this.profiles,
    required this.settings,
    required this.onChanged,
    required this.onStartPod,
    required this.onResumePod,
    required this.onEndNight,
    required this.onClearNight,
    required this.onImportNight,
  });

  final NightSession night;
  final List<PlayerProfile> profiles;
  final AppSettings settings;
  final Future<void> Function(void Function(NightSession n) edit) onChanged;
  final Future<void> Function(String podId, Game game) onStartPod;
  final Future<void> Function(String podId) onResumePod;
  final Future<void> Function() onEndNight;
  final Future<void> Function() onClearNight;
  final Future<bool> Function(NightSession night) onImportNight;

  @override
  State<NightHubScreen> createState() => _NightHubScreenState();
}

class _NightHubScreenState extends State<NightHubScreen> {
  NightSession get night => widget.night;

  Future<void> _share() async {
    final text = night.buildRecap();
    final code = encodeNightTransfer(night);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Partager la soirée',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Code ${night.code} · fusionnez sur un autre téléphone '
                  'pour cumuler les résultats des tables.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                ),
                const SizedBox(height: 14),
                if (code != null && nightTransferFitsQr(code))
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: code,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final payload = code ?? text;
                    await Clipboard.setData(ClipboardData(text: payload));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code / récap copié')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copier code MTGN1'),
                ),
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Récap texte copié')),
                    );
                  },
                  child: const Text('Copier le récap texte'),
                ),
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: night.buildCsv()),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('CSV copié — collez dans Excel / Sheets'),
                      ),
                    );
                  },
                  child: const Text('Copier le CSV classement'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addPlayer() async {
    final name = await askName(
      context,
      title: 'Joueur de la soirée',
      hint: 'Prénom',
    );
    if (name == null) return;
    await widget.onChanged((n) => n.addPlayer(name));
  }

  Future<void> _configurePod(NightPod pod) async {
    final selected = {...pod.playerNames};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    pod.label,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cochez 1 à 8 joueurs pour cette table.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final player in night.roster)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: selected.contains(player.name),
                            title: Text(player.name),
                            onChanged: (v) {
                              setModal(() {
                                if (v == true) {
                                  if (selected.length < 8) {
                                    selected.add(player.name);
                                  }
                                } else {
                                  selected.remove(player.name);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () async {
                      await widget.onChanged(
                        (n) => n.setPodPlayers(pod.id, selected.toList()),
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Enregistrer la table'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _launchPod(NightPod pod) async {
    if (pod.session != null) {
      await widget.onResumePod(pod.id);
      return;
    }
    if (pod.playerNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignez des joueurs à cette table.')),
      );
      await _configurePod(pod);
      return;
    }
    final info = formatInfo(MatchFormat.commander);
    final colors = <int>[];
    final commanderNames = <List<String>>[];
    for (final name in pod.playerNames) {
      NightPlayer? fromRoster;
      for (final p in night.roster) {
        if (p.name == name) {
          fromRoster = p;
          break;
        }
      }
      PlayerProfile? fromProfile;
      for (final p in widget.profiles) {
        if (p.name.toLowerCase() == name.toLowerCase()) {
          fromProfile = p;
          break;
        }
      }
      colors.add(fromRoster?.color ?? fromProfile?.color ?? colors.length);
      commanderNames.add(
        fromProfile == null || fromProfile.commanders.isEmpty
            ? ['Commandant']
            : fromProfile.commanders,
      );
    }
    final game = Game.start(
      format: MatchFormat.commander,
      playerCount: pod.playerNames.length,
      names: pod.playerNames,
      colors: colors,
      commanderNames: commanderNames,
      trackCommanderDamage: info.commanderDamage,
      trackCommanderTax: info.commanderTax,
      startingLife: info.startingLife,
      turnAlertSeconds: widget.settings.turnAlertSeconds,
      timerMode: widget.settings.timerMode,
      timersEnabled: widget.settings.timersEnabled,
      chessBankSeconds: widget.settings.chessBankSeconds,
      handicapsEnabled: widget.settings.handicapsEnabled,
      resetManaOnTurn: widget.settings.resetManaOnTurn,
      resetStormOnTurn: widget.settings.resetStormOnTurn,
      commanderThreshold: widget.settings.commanderThreshold,
      poisonThreshold: widget.settings.poisonThreshold,
    );
    await widget.onStartPod(pod.id, game);
  }

  @override
  Widget build(BuildContext context) {
    final board = night.standings();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          night.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Stats & export',
            visualDensity: VisualDensity.compact,
            onPressed: () => showNightStatsSheet(context, night),
            icon: const Icon(Icons.bar_chart),
          ),
          IconButton(
            tooltip: 'Partager',
            visualDensity: VisualDensity.compact,
            onPressed: _share,
            icon: const Icon(Icons.ios_share),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'end':
                  await widget.onEndNight();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Soirée close.')),
                    );
                  }
                case 'clear':
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Effacer la soirée ?'),
                      content: const Text(
                        'Supprime le hub local (l’historique global reste).',
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
                  if (ok == true) {
                    await widget.onClearNight();
                    if (context.mounted) Navigator.pop(context);
                  }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'end', child: Text('Clore la soirée')),
              PopupMenuItem(value: 'clear', child: Text('Effacer le hub')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.22),
                  surface,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  night.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  night.isOpen
                      ? 'Soirée ouverte · ${night.games.length} partie'
                            '${night.games.length > 1 ? 's' : ''} · '
                            '${night.pods.length} table'
                            '${night.pods.length > 1 ? 's' : ''}'
                      : 'Soirée close · ${night.games.length} parties',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Classement',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () => showNightStatsSheet(context, night),
                child: const Text('Détail'),
              ),
            ],
          ),
          Text(
            '3 pts victoire · 2 équipe · 1 présence',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 8),
          if (board.isEmpty)
            Text(
              'Aucune partie encore. Lancez une table ci-dessous.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            )
          else
            for (var i = 0; i < board.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => showNightStatsSheet(context, night),
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
                  '${board[i].wins}V · ${board[i].games} parties · '
                  '${(board[i].winRate * 100).round()} %',
                ),
                trailing: Text(
                  '${board[i].points} pts',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tables',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              if (night.pods.length < 6 && night.isOpen)
                TextButton.icon(
                  onPressed: () => widget.onChanged((n) => n.addPod()),
                  icon: const Icon(Icons.add),
                  label: const Text('Table'),
                ),
            ],
          ),
          for (final pod in night.pods)
            Card(
              color: const Color(0xFF141A24),
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pod.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        _PodBadge(status: pod.status),
                        if (night.isOpen)
                          IconButton(
                            tooltip: 'Joueurs',
                            onPressed: () => _configurePod(pod),
                            icon: const Icon(Icons.group_outlined),
                          ),
                        if (night.isOpen && night.pods.length > 1)
                          IconButton(
                            tooltip: 'Retirer',
                            onPressed: () =>
                                widget.onChanged((n) => n.removePod(pod.id)),
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                    Text(
                      pod.playerNames.isEmpty
                          ? 'Aucun joueur assigné'
                          : pod.playerNames.join(' · '),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    if (pod.gamesPlayed > 0)
                      Text(
                        '${pod.gamesPlayed} partie'
                        '${pod.gamesPlayed > 1 ? 's' : ''} ce soir',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (night.isOpen)
                      FilledButton.tonal(
                        onPressed: () => _launchPod(pod),
                        child: Text(
                          pod.session != null
                              ? 'Reprendre la table'
                              : pod.status == PodStatus.playing
                              ? 'Revenir à la table'
                              : 'Lancer la table',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Joueurs de la soirée',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              if (night.isOpen)
                TextButton.icon(
                  onPressed: _addPlayer,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Joueur'),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final player in night.roster)
                InputChip(
                  avatar: CircleAvatar(
                    backgroundColor: playerColor(player.color),
                    radius: 10,
                  ),
                  label: Text(player.name),
                  onDeleted: night.isOpen
                      ? () => widget.onChanged(
                          (n) => n.removePlayer(player.id),
                        )
                      : null,
                ),
              if (night.roster.isEmpty)
                Text(
                  'Ajoutez les joueurs de la soirée, puis assignez-les aux tables.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
          if (night.games.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Parties de la soirée',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final game in night.games.take(15))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(game.winner ?? 'Sans vainqueur'),
                subtitle: Text(
                  '${game.format} · ${game.players.join(', ')}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PodBadge extends StatelessWidget {
  const _PodBadge({required this.status});

  final PodStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PodStatus.idle => ('Libre', Colors.white54),
      PodStatus.playing => ('En cours', accent),
      PodStatus.paused => ('En pause', accentGold),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
