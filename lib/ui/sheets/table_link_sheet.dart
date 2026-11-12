import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/net/table_link.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/widgets/option_glyphs.dart';
import 'package:mtg_table/ui/widgets/player_panel.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> showTableLinkSheet(
  BuildContext context, {
  required TableLinkController link,
  required GameController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: _TableLinkSheet(link: link, controller: controller),
      );
    },
  );
}

class _TableLinkSheet extends StatelessWidget {
  const _TableLinkSheet({required this.link, required this.controller});

  final TableLinkController link;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([link, controller]),
      builder: (context, _) {
        final game = controller.game;
        final mine = link.mySeat;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const Text(
              'LifeStack entre téléphones',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Un seul écran suffit. Pour brancher plusieurs téléphones '
              'qui ont la même application : choisissez l’affichage, '
              'puis créez ou rejoignez la table.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Affichage de cet écran',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mon téléphone : cet écran est un siège, relié aux autres LifeStack. '
              'La table : tous les joueurs restent sur cet écran.',
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => link.setCenter(false),
              icon: const Icon(Icons.phone_android),
              label: Text(
                !link.center && (link.linked || link.centerChosen)
                    ? 'Mon téléphone LifeStack · actuel'
                    : 'Mon téléphone LifeStack',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => link.setCenter(true),
              icon: const Icon(Icons.table_restaurant),
              label: Text(
                link.center
                    ? 'La table entière · actuel'
                    : 'La table entière',
              ),
            ),
            if (!link.center && !link.linked) ...[
              const SizedBox(height: 8),
              Text(
                'Affichage choisi. Créez ou rejoignez ci-dessous : '
                'cet écran passera alors à votre siège.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
            if (link.linked) ...[
              const SizedBox(height: 8),
              Text(
                link.pathLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
            if (!link.linked) ...[
              const SizedBox(height: 16),
              const Text(
                'Même Wi-Fi',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 4),
              const Text(
                'Jusqu’à 12 joueurs. Le QR contient l’adresse : '
                'l’appareil photo peut la copier, puis collez-la.',
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: link.searching
                    ? null
                    : () => link.hostTable(controller.exportSession()),
                icon: const Icon(Icons.wifi),
                label: const Text('Créer la table'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: link.searching
                    ? null
                    : () async {
                        final code = await _askJoin(
                          context,
                          hint: 'Code, ou 192.168.1.12:port',
                        );
                        if (code == null || !context.mounted) return;
                        final ok = await link.joinTable(code);
                        if (!ok || !context.mounted) return;
                        final session = link.latestSession;
                        if (session != null) controller.adoptSession(session);
                      },
                icon: const Icon(Icons.login),
                label: Text(link.searching ? 'Recherche…' : 'Rejoindre'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Groupe isolé',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 4),
              const Text(
                'Quatre téléphones, sans le Wi-Fi du lieu. '
                'Les autres touchent ce téléphone dans la liste.',
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: link.searching
                    ? null
                    : () => link.hostDirect(controller.exportSession()),
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Ouvrir le groupe'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: link.searching ? null : () => link.seekDirect(),
                icon: const Icon(Icons.radar),
                label: const Text('Chercher un groupe'),
              ),
              for (final peer in link.nearby)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(peer.name),
                  trailing: FilledButton(
                    onPressed: () async {
                      final ok = await link.joinDirect(peer.address);
                      if (!ok || !context.mounted) return;
                      final session = link.latestSession;
                      if (session != null) controller.adoptSession(session);
                    },
                    child: const Text('Rejoindre'),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Salon en ligne',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 4),
              const Text(
                'Jusqu’à 12, avec internet. Les noms et les scores partent chiffrés. '
                'Le code est la clé : montrez-le seulement à la table.',
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: link.searching
                    ? null
                    : () => link.hostOnline(controller.exportSession()),
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('Ouvrir un salon'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: link.searching
                    ? null
                    : () async {
                        final code = await _askJoin(
                          context,
                          hint: 'Code du salon',
                        );
                        if (code == null || !context.mounted) return;
                        final ok = await link.joinOnline(code);
                        if (!ok || !context.mounted) return;
                        final session = link.latestSession;
                        if (session != null) controller.adoptSession(session);
                      },
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('Rejoindre un salon'),
              ),
            ],
            if (link.code != null) ...[
              const SizedBox(height: 16),
              Text(
                _prettyCode(link.code!),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: link.code!.length > 4 ? 28 : 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: link.code!.length > 4 ? 2 : 6,
                ),
              ),
              if (_qrPayload(link) != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: _qrPayload(link)!,
                      size: 160,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _qrPayload(link)!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: _qrPayload(link)!),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          link.path == TablePath.online
                              ? 'Code copié'
                              : 'Adresse copiée',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(
                    link.path == TablePath.online
                        ? 'Copier le code'
                        : 'Copier l’adresse',
                  ),
                ),
              ],
              Text(
                _hostHint(link),
                textAlign: TextAlign.center,
              ),
              if (link.phones > 1)
                Text(
                  '${link.phones} téléphones sur cette table',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
            ],
            if (link.status != null) ...[
              const SizedBox(height: 8),
              Text(
                link.status!,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
            const SizedBox(height: 12),
            for (final player in game.players)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: playerColor(player.color),
                  child: Text(
                    playerInitial(player.name),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(player.name),
                subtitle: Text(_seatPlace(link, player.id, player.life)),
                trailing: link.linked && !link.center
                    ? TextButton(
                        onPressed: () => link.claim(
                          mine == player.id ? null : player.id,
                        ),
                        child: Text(mine == player.id ? 'Libérer' : 'C’est moi'),
                      )
                    : null,
              ),
            if (link.linked)
              TextButton.icon(
                onPressed: link.stop,
                icon: const Icon(Icons.link_off),
                label: const Text('Couper la liaison'),
              ),
          ],
        );
      },
    );
  }
}

/// Rejoint une table depuis le salon, avant d’avoir une partie locale.
Future<Map<String, dynamic>?> promptJoinTable(
  BuildContext context,
  TableLinkController link,
) async {
  final path = await showDialog<TablePath>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rejoindre'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Le Wi-Fi du lieu si les téléphones se voient. '
            'Un groupe isolé pour quatre. '
            'Un salon en ligne si aucun réseau local ne tient.',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, TablePath.lan),
            child: const Text('Ce Wi-Fi'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, TablePath.direct),
            child: const Text('Groupe isolé'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, TablePath.online),
            child: const Text('Salon en ligne'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );
  if (path == null || !context.mounted) return null;
  switch (path) {
    case TablePath.lan:
      final code = await _askJoin(context, hint: 'Code, ou 192.168.1.12:port');
      if (code == null) return null;
      final ok = await link.joinTable(code);
      return ok ? link.latestSession : null;
    case TablePath.online:
      final code = await _askJoin(context, hint: 'Code du salon');
      if (code == null) return null;
      final ok = await link.joinOnline(code);
      return ok ? link.latestSession : null;
    case TablePath.direct:
      await link.seekDirect();
      if (!context.mounted) return null;
      final peer = await showDialog<DirectPeer>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Groupe isolé'),
          content: SizedBox(
            width: 280,
            child: ListenableBuilder(
              listenable: link,
              builder: (context, _) {
                if (link.nearby.isEmpty) {
                  return Text(link.status ?? 'Recherche…');
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final peer in link.nearby)
                      ListTile(
                        title: Text(peer.name),
                        onTap: () => Navigator.pop(context, peer),
                      ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
      if (peer == null) return null;
      final ok = await link.joinDirect(peer.address);
      return ok ? link.latestSession : null;
  }
}

String _prettyCode(String code) {
  if (code.length <= 4) return code;
  final mid = code.length ~/ 2;
  return '${code.substring(0, mid)} ${code.substring(mid)}';
}

String? _qrPayload(TableLinkController link) {
  if (link.path == TablePath.online && link.code != null) {
    return 'LSNET:${link.code}';
  }
  return link.joinAddress;
}

String _hostHint(TableLinkController link) {
  if (!link.hosting) return 'Vous êtes sur la table ${link.code}.';
  return switch (link.path) {
    TablePath.lan =>
      'Les autres saisissent le code, ou collent l’adresse lue sur le QR.',
    TablePath.direct =>
      'Quatre téléphones au plus. Les autres : Groupe isolé, puis ce téléphone.',
    TablePath.online =>
      'Les autres saisissent ce code, ou le collent depuis le QR.',
  };
}

String _seatPlace(TableLinkController link, String playerId, int life) {
  String? owner;
  for (final entry in link.seats.entries) {
    if (entry.value == playerId) owner = entry.key;
  }
  if (owner == null) {
    return link.linked ? '$life PV · à la table, sans téléphone' : '$life PV';
  }
  if (owner == link.deviceId) return '$life PV · cet appareil';
  return '$life PV · autre téléphone';
}

Future<String?> _askJoin(BuildContext context, {required String hint}) async {
  final field = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rejoindre'),
      content: TextField(
        controller: field,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          hintText: hint,
        ),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, field.text.trim()),
          child: const Text('Rejoindre'),
        ),
      ],
    ),
  );
  field.dispose();
  if (code == null || code.isEmpty) return null;
  return code;
}

/// Ce téléphone n’a pas encore de siège : on choisit, en plein écran.
class LinkedSeatPicker extends StatelessWidget {
  const LinkedSeatPicker({
    super.key,
    required this.controller,
    required this.link,
  });

  final GameController controller;
  final TableLinkController link;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        const Text(
          'Ce téléphone joue quel siège ?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Votre siège prend l’écran. Les autres restent en bandeau, '
          'avec leurs compteurs. Pour garder tout le monde sur cet écran, '
          'touchez les deux mains, puis « La table entière ».',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        ),
        const SizedBox(height: 12),
        for (final player in game.players)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: playerColor(player.color),
              child: Text(
                playerInitial(player.name),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text(player.name),
            subtitle: Text('${player.life} PV'),
            trailing: FilledButton(
              onPressed: () => link.claim(player.id),
              child: const Text('C’est moi'),
            ),
          ),
      ],
    );
  }
}

/// Mon siège prend l’espace. Les autres tiennent dans un bandeau.
class LinkedSeatView extends StatelessWidget {
  const LinkedSeatView({
    super.key,
    required this.controller,
    required this.mine,
    required this.haptic,
    required this.showTips,
  });

  final GameController controller;
  final String mine;
  final bool haptic;
  final bool showTips;

  @override
  Widget build(BuildContext context) {
    final others = [
      for (final player in controller.game.players)
        if (player.id != mine) player,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth >= constraints.maxHeight &&
            constraints.maxWidth >= 520;
        final minePanel = PlayerPanel(
          controller: controller,
          playerId: mine,
          haptic: haptic,
          showTips: showTips,
        );
        if (others.isEmpty) return minePanel;
        final rail = _OpponentRail(
          controller: controller,
          mine: mine,
          others: others,
          haptic: haptic,
          showTips: showTips,
          side: side,
        );
        if (side) {
          return Row(
            children: [
              Expanded(child: minePanel),
              const SizedBox(width: skyLane),
              Expanded(child: rail),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: minePanel),
            const SizedBox(height: skyLane),
            Expanded(child: rail),
          ],
        );
      },
    );
  }
}

class _OpponentRail extends StatelessWidget {
  const _OpponentRail({
    required this.controller,
    required this.mine,
    required this.others,
    required this.haptic,
    required this.showTips,
    required this.side,
  });

  final GameController controller;
  final String mine;
  final List<Player> others;
  final bool haptic;
  final bool showTips;
  final bool side;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final player in others)
        _OpponentCard(
          controller: controller,
          player: player,
          mine: mine,
          haptic: haptic,
          showTips: showTips,
          wide: side,
        ),
    ];
    if (side) {
      return SizedBox(
        width: 232,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          children: cards,
        ),
      );
    }
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: cards,
      ),
    );
  }
}

class _OpponentCard extends StatelessWidget {
  const _OpponentCard({
    required this.controller,
    required this.player,
    required this.mine,
    required this.haptic,
    required this.showTips,
    required this.wide,
  });

  final GameController controller;
  final Player player;
  final String mine;
  final bool haptic;
  final bool showTips;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final active = game.players[game.activeIndex].id == player.id;
    final marks = [
      player.name,
      if (active) '· tour',
      if (player.poison > 0) '· poison ${player.poison}',
      if (game.monarchId == player.id) '· monarque',
    ].join(' ');
    return Padding(
      key: ValueKey('rail-${player.id}'),
      padding: EdgeInsets.only(right: wide ? 0 : 8, bottom: wide ? 8 : 0),
      child: SizedBox(
        width: wide ? null : 210,
        height: wide ? null : 88,
        child: Material(
          color: panelInk,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openLinkedSeat(
              context,
              controller: controller,
              playerId: player.id,
              haptic: haptic,
              showTips: showTips,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 2, 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label: 'Compteurs de ${player.name}',
                    excludeSemantics: true,
                    child: Row(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: playerColor(player.color),
                        child: Text(
                          playerInitial(player.name),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          marks,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ),
                  Row(
                    children: [
                      _LifeStep(
                        tooltip: 'Retirer 1 PV à ${player.name}',
                        icon: Icons.remove,
                        onPressed: () => controller.addLife(
                          player.id,
                          -1,
                          dealtBy: mine,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${player.life}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                      _LifeStep(
                        tooltip: 'Ajouter 1 PV à ${player.name}',
                        icon: Icons.add,
                        onPressed: () => controller.addLife(player.id, 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LifeStep extends StatelessWidget {
  const _LifeStep({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

void _openLinkedSeat(
  BuildContext context, {
  required GameController controller,
  required String playerId,
  required bool haptic,
  required bool showTips,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: surface,
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height * 0.82;
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return SizedBox(
            height: height,
            child: PlayerPanel(
              controller: controller,
              playerId: playerId,
              haptic: haptic,
              showTips: showTips,
            ),
          );
        },
      );
    },
  );
}
