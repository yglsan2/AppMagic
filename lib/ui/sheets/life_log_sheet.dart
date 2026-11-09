import 'package:flutter/material.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';

enum LifeLogTab { life, commander }

Future<void> showLifeLogSheet(
  BuildContext context,
  GameController controller, {
  String? playerId,
  LifeLogTab initialTab = LifeLogTab.life,
  String? commanderId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: LifeLogSheet(
          controller: controller,
          initialPlayerId: playerId,
          initialTab: initialTab,
          initialCommanderId: commanderId,
        ),
      );
    },
  );
}

class LifeLogSheet extends StatefulWidget {
  const LifeLogSheet({
    super.key,
    required this.controller,
    this.initialPlayerId,
    this.initialTab = LifeLogTab.life,
    this.initialCommanderId,
  });

  final GameController controller;
  final String? initialPlayerId;
  final LifeLogTab initialTab;
  final String? initialCommanderId;

  @override
  State<LifeLogSheet> createState() => _LifeLogSheetState();
}

class _LifeLogSheetState extends State<LifeLogSheet>
    with SingleTickerProviderStateMixin {
  late String? _filterId = widget.initialPlayerId;
  late LifeLogTab _tab = widget.initialTab;
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab == LifeLogTab.commander ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() {
        _tab = _tabs.index == 0 ? LifeLogTab.life : LifeLogTab.commander;
      });
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final game = widget.controller.game;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Décomptes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Points de vie'),
                Tab(text: 'Commandant'),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Tous'),
                    selected: _filterId == null,
                    onSelected: (_) => setState(() => _filterId = null),
                  ),
                  for (final player in game.players) ...[
                    const SizedBox(width: 6),
                    FilterChip(
                      avatar: CircleAvatar(
                        backgroundColor: playerColor(player.color),
                        radius: 8,
                      ),
                      label: Text(player.name),
                      selected: _filterId == player.id,
                      onSelected: (_) =>
                          setState(() => _filterId = player.id),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _tab == LifeLogTab.life
                  ? _LifeEntries(
                      controller: widget.controller,
                      filterId: _filterId,
                    )
                  : _CmdEntries(
                      controller: widget.controller,
                      filterId: _filterId,
                      commanderId: widget.initialCommanderId,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _LifeEntries extends StatelessWidget {
  const _LifeEntries({
    required this.controller,
    required this.filterId,
  });

  final GameController controller;
  final String? filterId;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final all = controller.lifeLog;
    final entries = filterId == null
        ? all
        : [for (final e in all) if (e.playerId == filterId) e];
    if (entries.isEmpty) {
      return const Center(child: Text('Aucun décompte PV pour l’instant.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            '${entries.length} changement${entries.length > 1 ? 's' : ''} '
            '(récent → ancien · taps rapides fusionnés)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final loss = entry.delta < 0;
              final gain = entry.delta > 0;
              final tint = loss
                  ? const Color(0xFFFF8A95)
                  : gain
                  ? const Color(0xFF7DFFB2)
                  : Colors.white70;
              Player? owner;
              for (final p in game.players) {
                if (p.id == entry.playerId) {
                  owner = p;
                  break;
                }
              }
              return _LogTile(
                avatarColor: owner == null
                    ? Colors.white24
                    : playerColor(owner.color),
                initial: owner == null ? '?' : playerInitial(owner.name),
                title: entry.summary,
                subtitle:
                    'Manche ${entry.roundNumber} · tour ${entry.turnCount}'
                    '${entry.reason == null ? '' : ' · ${entry.reason}'}',
                trailing: entry.deltaLabel,
                trailingColor: tint,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CmdEntries extends StatelessWidget {
  const _CmdEntries({
    required this.controller,
    required this.filterId,
    this.commanderId,
  });

  final GameController controller;
  final String? filterId;
  final String? commanderId;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final all = controller.cmdDamageLog;
    final entries = [
      for (final e in all)
        if ((filterId == null || e.defenderId == filterId) &&
            (commanderId == null || e.commanderId == commanderId))
          e,
    ];
    if (entries.isEmpty) {
      return const Center(child: Text('Aucun décompte Cdt pour l’instant.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            '${entries.length} changement${entries.length > 1 ? 's' : ''} '
            '(récent → ancien · taps rapides fusionnés)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final entry = entries[index];
              // +Cdt = dégât infligé (rouge) ; − = annulation (vert).
              final tint = entry.delta > 0
                  ? const Color(0xFFFF8A95)
                  : const Color(0xFF7DFFB2);
              Player? owner;
              for (final p in game.players) {
                if (p.id == entry.defenderId) {
                  owner = p;
                  break;
                }
              }
              final lifeBit =
                  entry.lifeFrom != null && entry.lifeTo != null
                  ? ' · PV ${entry.lifeFrom}→${entry.lifeTo}'
                  : '';
              final remain = (game.commanderThreshold - entry.toTaken).clamp(
                0,
                game.commanderThreshold,
              );
              return _LogTile(
                avatarColor: owner == null
                    ? Colors.white24
                    : playerColor(owner.color),
                initial: owner == null ? '?' : playerInitial(owner.name),
                title: entry.summary,
                subtitle:
                    'Manche ${entry.roundNumber} · tour ${entry.turnCount}'
                    ' · pris ${entry.toTaken} · reste $remain'
                    '$lifeBit',
                trailing: entry.deltaLabel,
                trailingColor: tint,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({
    required this.avatarColor,
    required this.initial,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.trailingColor,
  });

  final Color avatarColor;
  final String initial;
  final String title;
  final String subtitle;
  final String trailing;
  final Color trailingColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: avatarColor,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              trailing,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: trailingColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
