import 'package:flutter/material.dart';
import 'package:mtg_table/data/safe_image.dart';
import 'package:mtg_table/data/scryfall_art.dart';
import 'package:mtg_table/domain/handicap.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/player_profile.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/sheets/profiles_sheet.dart';
import 'package:mtg_table/ui/sheets/transfer_sheet.dart';
import 'package:mtg_table/ui/widgets/handicap_picker.dart';
import 'package:mtg_table/ui/widgets/help_tip.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.settings,
    required this.group,
    required this.resumeLabel,
    required this.onStart,
    required this.onResume,
    required this.onOpenSearch,
    required this.onOpenStats,
    required this.onImportSession,
    required this.onOpenNight,
    required this.onOpenPrivacy,
    this.nightLabel,
    this.profiles = const [],
    this.onSaveProfile,
  });

  final AppSettings settings;
  final Playgroup? group;
  final String? resumeLabel;
  final String? nightLabel;
  final ValueChanged<Game> onStart;
  final VoidCallback onResume;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenNight;
  final VoidCallback onOpenPrivacy;
  final Future<bool> Function(Map<String, dynamic> session) onImportSession;
  final List<PlayerProfile> profiles;
  final Future<void> Function(PlayerProfile profile)? onSaveProfile;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _DraftCmd {
  _DraftCmd({required this.id, required this.name, this.artUrl});

  final String id;
  String name;
  String? artUrl;
}

class _DraftPlayer {
  _DraftPlayer({
    required this.id,
    required this.name,
    required this.color,
    required this.commanders,
    this.deckBracket = DeckBracket.fair,
    this.handicapLifeDelta = 0,
  });

  final String id;
  String name;
  int color;
  List<_DraftCmd> commanders;
  DeckBracket deckBracket;
  int handicapLifeDelta;
}

class _SetupScreenState extends State<SetupScreen> {
  final Map<String, TextEditingController> _fields = {};
  late MatchFormat _format;
  late int _life;
  late bool _damage;
  late bool _tax;
  late bool _shared;
  late bool _planechase;
  late bool _archenemy;
  late bool _bounty;
  late bool _handicaps;
  late int _count;
  bool _more = false;
  final List<_DraftPlayer> _drafts = [];

  @override
  void initState() {
    super.initState();
    final group = widget.group;
    final info = formatInfo(group?.format ?? MatchFormat.commander);
    _format = group?.format ?? MatchFormat.commander;
    _life = group?.startingLife ?? info.startingLife;
    _damage = group?.trackCommanderDamage ?? info.commanderDamage;
    _tax = group?.trackCommanderTax ?? info.commanderTax;
    _shared = group?.sharedLife ?? info.sharedLife;
    _planechase = group?.planechase ?? false;
    _archenemy = group?.archenemy ?? false;
    _bounty = group?.bounty ?? false;
    // Préférence réglages, sauf vie partagée (2HG) où les handicaps n’ont pas de sens.
    _handicaps = widget.settings.handicapsEnabled && !_shared;
    final source = group?.players ?? const <PlaygroupPlayer>[];
    _count = source.isEmpty ? info.defaultPlayers : source.length.clamp(1, 8);
    for (final player in source) {
      _drafts.add(
        _DraftPlayer(
          id: newId('draft'),
          name: player.name,
          color: player.color,
          deckBracket: player.deckBracket,
          handicapLifeDelta: player.handicapLifeDelta,
          commanders: [
            for (var i = 0; i < player.commanders.length; i++)
              _DraftCmd(
                id: newId('dcmd'),
                name: player.commanders[i],
                artUrl: i < player.commanderArts.length
                    ? player.commanderArts[i]
                    : null,
              ),
          ],
        ),
      );
    }
    while (_drafts.length < 8) {
      final index = _drafts.length;
      _drafts.add(
        _DraftPlayer(
          id: newId('draft'),
          name: 'Joueur ${index + 1}',
          color: index,
          commanders: _damage || _tax
              ? [_DraftCmd(id: newId('dcmd'), name: 'Commandant')]
              : [],
        ),
      );
    }
    _ensureCommanders();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _field(String id, String text) {
    return _fields.putIfAbsent(id, () => TextEditingController(text: text));
  }

  void _ensureCommanders() {
    if (!_damage && !_tax) return;
    for (final player in _drafts) {
      if (player.commanders.isEmpty) {
        player.commanders.add(_DraftCmd(id: newId('dcmd'), name: 'Commandant'));
      }
    }
  }

  void _applyFormat(FormatInfo info) {
    setState(() {
      _format = info.format;
      if (info.format != MatchFormat.custom) {
        _life = info.startingLife;
        _damage = info.commanderDamage;
        _tax = info.commanderTax;
        _shared = info.sharedLife;
        _count = info.defaultPlayers;
      }
      if (_shared && _count.isOdd) _count += 1;
      if (_shared && _count < 2) _count = 2;
      if (_format == MatchFormat.commander || _format == MatchFormat.treachery) {
        _count = _count.clamp(3, 8);
      } else {
        _count = _count.clamp(1, 8);
      }
      _ensureCommanders();
    });
  }

  void _setCount(int value) {
    setState(() {
      var next = value;
      if (_shared && next.isOdd) next += 1;
      if (_shared && next < 2) next = 2;
      if (_format == MatchFormat.commander || _format == MatchFormat.treachery) {
        next = next.clamp(3, 8);
      } else {
        next = next.clamp(1, 8);
      }
      _count = next;
      _ensureCommanders();
    });
  }

  Future<void> _lookupArt(_DraftCmd commander) async {
    final name = _field(commander.id, commander.name).text.trim();
    if (name.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indiquez un nom de commandant.')),
      );
      return;
    }
    final result = await fetchCommanderArtUrlResult(name);
    if (!mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage!)),
      );
      return;
    }
    setState(() {
      commander.name = name;
      commander.artUrl = result.value;
    });
    if (result.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Carte trouvée sans illustration, ou nom inconnu.'),
        ),
      );
    }
  }

  void _start() {
    final used = _drafts.take(_count).toList();
    final game = Game.start(
      format: _format,
      playerCount: _count,
      startingLife: _life,
      trackCommanderDamage: _damage,
      trackCommanderTax: _tax,
      sharedLife: _shared,
      resetManaOnTurn: widget.settings.resetManaOnTurn,
      resetStormOnTurn: widget.settings.resetStormOnTurn,
      commanderThreshold: widget.settings.commanderThreshold,
      poisonThreshold: widget.settings.poisonThreshold,
      turnAlertSeconds: widget.settings.turnAlertSeconds,
      timerMode: widget.settings.timerMode,
      chessBankSeconds: widget.settings.chessBankSeconds,
      planechase: _planechase,
      archenemy: _archenemy,
      bounty: _bounty,
      handicapsEnabled: _handicaps && !_shared,
      names: [for (final player in used) _field(player.id, player.name).text],
      colors: [for (final player in used) player.color],
      deckBrackets: [for (final player in used) player.deckBracket],
      handicapLifeDeltas: [
        for (final player in used) player.handicapLifeDelta,
      ],
      commanderNames: [
        for (final player in used)
          if (_damage || _tax)
            [
              for (final commander in player.commanders)
                _field(commander.id, commander.name).text,
            ]
          else
            <String>[],
      ],
      commanderArts: [
        for (final player in used)
          if (_damage || _tax)
            [for (final commander in player.commanders) commander.artUrl]
          else
            <String?>[],
      ],
    );
    widget.onStart(game);
  }

  @override
  Widget build(BuildContext context) {
    final used = _drafts.take(_count).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0C1420),
              Color(0xFF07090E),
              Color(0xFF0A1612),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) {
              final contentWidth = (viewport.maxWidth - 40).clamp(280.0, 720.0);
              return SingleChildScrollView(
                key: const Key('setup-form'),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFF2F5FA), Color(0xFFC9E8D4)],
                ).createShader(bounds),
                child: const Text(
                  'Table MTG',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sans pub, sans compte · tout reste sur cet appareil.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _damage
                    ? 'Chaque commandant adverse a ${widget.settings.commanderThreshold} points séparés. Touchez pour baisser.'
                    : 'La vie au centre. Les extras restent derrière « ⋯ ».',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
              ),
              if (_damage) ...[
                const SizedBox(height: 4),
                Text(
                  'Règle officielle : 21 dégâts de combat du même commandant éliminent. '
                  'Chaque partenaire est suivi à part. La vie baisse aussi.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (widget.resumeLabel != null) ...[
                FilledButton.tonalIcon(
                  onPressed: widget.onResume,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(widget.resumeLabel!),
                ),
                const SizedBox(height: 12),
              ],
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: const Text(
                    'Outils & soirée',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  subtitle: Text(
                    'Soirée multi-tables, import, stats, cartes…',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: widget.onOpenNight,
                            icon: const Icon(Icons.nightlife),
                            label: Text(
                              widget.nightLabel ?? 'Soirée multi-tables',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final session =
                                  await showImportTransferSheet(context);
                              if (session == null || !context.mounted) return;
                              final messenger = ScaffoldMessenger.of(context);
                              final ok = await widget.onImportSession(session);
                              if (!ok && context.mounted) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Import impossible : partie invalide ou corrompue.',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.qr_code_2),
                            label: const Text('Importer'),
                          ),
                          OutlinedButton.icon(
                            onPressed: widget.onOpenStats,
                            icon: const Icon(Icons.emoji_events_outlined),
                            label: const Text('Historique'),
                          ),
                          TextButton(
                            onPressed: widget.onOpenSearch,
                            child: const Text('Cartes'),
                          ),
                          TextButton(
                            onPressed: widget.onOpenPrivacy,
                            child: const Text('Vie privée'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              HelpTip(
                title: 'Formats',
                message:
                    'Appui long sur un format (ou l’icône i) pour lire '
                    'l’explication. Les noms anglais restent entre parenthèses.',
                showIcon: true,
                child: const Text(
                  'Format',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final info in formatCatalog)
                    HelpTip(
                      title: info.label,
                      message: info.help,
                      child: ChoiceChip(
                        label: Text(info.label),
                        selected: _format == info.format,
                        onSelected: (_) => _applyFormat(info),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              HelpTip(
                title: formatInfo(_format).label,
                message: formatInfo(_format).help,
                showIcon: true,
                child: Text(
                  formatInfo(_format).detail,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _format == MatchFormat.commander ||
                        _format == MatchFormat.treachery
                    ? 'Joueurs (3–8)'
                    : 'Joueurs',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var n = 1; n <= 8; n++)
                    if ((!_shared || n.isEven) &&
                        ((_format != MatchFormat.commander &&
                                _format != MatchFormat.treachery) ||
                            n >= 3))
                      _CountPick(
                        value: n,
                        selected: _count == n,
                        onTap: () => _setCount(n),
                      ),
                ],
              ),
              const SizedBox(height: 18),
              for (final player in used) ...[
                Row(
                  children: [
                    Tooltip(
                      message: 'Couleur du siège',
                      child: InkWell(
                        onTap: () => setState(() {
                          player.color =
                              (player.color + 1) % playerPalette.length;
                        }),
                        customBorder: const CircleBorder(),
                        child: CircleAvatar(
                          backgroundColor: playerColor(player.color),
                          child: Text(
                            '${used.indexOf(player) + 1}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _field(player.id, player.name),
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nom',
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_handicaps && !_shared)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '${effectiveStartingLife(baseLife: _life, handicapsEnabled: true, lifeDelta: player.handicapLifeDelta)} PV',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFC4A46A),
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Charger un profil',
                      onPressed: () async {
                        final picked = await showPickProfileSheet(
                          context,
                          widget.profiles,
                        );
                        if (picked == null || !mounted) return;
                        setState(() {
                          _field(player.id, player.name).text = picked.name;
                          player.name = picked.name;
                          player.color = picked.color;
                          player.commanders = [
                            for (var i = 0; i < picked.commanders.length; i++)
                              _DraftCmd(
                                id: newId('dcmd'),
                                name: picked.commanders[i],
                                artUrl: i < picked.commanderArts.length
                                    ? picked.commanderArts[i]
                                    : null,
                              ),
                          ];
                          if (player.commanders.isEmpty && (_damage || _tax)) {
                            player.commanders.add(
                              _DraftCmd(id: newId('dcmd'), name: 'Commandant'),
                            );
                          }
                        });
                      },
                      icon: const Icon(Icons.person_search, size: 20),
                    ),
                    IconButton(
                      tooltip: 'Sauver le profil',
                      onPressed: widget.onSaveProfile == null
                          ? null
                          : () async {
                              final name = _field(
                                player.id,
                                player.name,
                              ).text.trim();
                              final ok = await confirmSaveProfile(
                                context,
                                name: name.isEmpty ? player.name : name,
                              );
                              if (!ok || !context.mounted) return;
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await widget.onSaveProfile!(
                                  PlayerProfile.fromDraft(
                                    name: name.isEmpty ? player.name : name,
                                    color: player.color,
                                    commanders: [
                                      for (final c in player.commanders)
                                        _field(c.id, c.name)
                                                .text
                                                .trim()
                                                .isEmpty
                                            ? c.name
                                            : _field(c.id, c.name).text.trim(),
                                    ],
                                    arts: [
                                      for (final c in player.commanders)
                                        c.artUrl,
                                    ],
                                  ),
                                );
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Profil enregistré.'),
                                  ),
                                );
                              } on Object {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Enregistrement du profil impossible.',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.person_add_alt_1, size: 20),
                    ),
                  ],
                ),
                if (_damage || _tax)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 50,
                      top: 6,
                      bottom: 10,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < player.commanders.length; i++)
                          Row(
                            children: [
                              if (player.commanders[i].artUrl != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SafeNetworkImage(
                                      url: player.commanders[i].artUrl,
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const SizedBox(
                                            width: 36,
                                            height: 36,
                                          ),
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: TextField(
                                  controller: _field(
                                    player.commanders[i].id,
                                    player.commanders[i].name,
                                  ),
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    labelText: player.commanders.length == 1
                                        ? 'Commandant'
                                        : 'Commandant ${i + 1}',
                                    isDense: true,
                                  ),
                                  onEditingComplete: () =>
                                      _lookupArt(player.commanders[i]),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Illustration Scryfall',
                                onPressed: () =>
                                    _lookupArt(player.commanders[i]),
                                icon: const Icon(Icons.image_search, size: 20),
                              ),
                              if (player.commanders.length > 1)
                                IconButton(
                                  onPressed: () => setState(() {
                                    final removed = player.commanders.removeAt(
                                      i,
                                    );
                                    _fields.remove(removed.id)?.dispose();
                                  }),
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                            ],
                          ),
                        if (player.commanders.length < 4)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setState(() {
                                player.commanders.add(
                                  _DraftCmd(
                                    id: newId('dcmd'),
                                    name: 'Commandant',
                                  ),
                                );
                              }),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Partenaire / 2e commandant'),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 10),
              ],
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: const Text(
                    'Équilibrer les decks (optionnel)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  subtitle: Text(
                    _shared
                        ? 'Indisponible en Géant à deux têtes'
                        : _handicaps
                        ? 'Handicaps actifs · PV −30…+30'
                        : 'Précon vs cEDH, bonus / malus de PV',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Handicaps de deck'),
                      subtitle: const Text(
                        'Un préconstruit peut partir à 50 PV, un cEDH à 30.',
                      ),
                      value: _handicaps && !_shared,
                      onChanged: _shared
                          ? null
                          : (value) => setState(() => _handicaps = value),
                    ),
                    if (_handicaps && !_shared)
                      for (final player in used) ...[
                        const SizedBox(height: 8),
                        Text(
                          _field(player.id, player.name).text.trim().isEmpty
                              ? player.name
                              : _field(player.id, player.name).text.trim(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        HandicapPicker(
                          compact: true,
                          bracket: player.deckBracket,
                          lifeDelta: player.handicapLifeDelta,
                          baseLife: _life,
                          onChanged: (bracket, delta) => setState(() {
                            player.deckBracket = bracket;
                            player.handicapLifeDelta = delta;
                          }),
                        ),
                      ],
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _more = !_more),
                child: Text(_more ? 'Moins d’options' : 'Plus d’options'),
              ),
              if (_more) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dégâts de commandant'),
                  value: _damage,
                  onChanged: (value) => setState(() {
                    _damage = value;
                    _ensureCommanders();
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Taxe de commandant'),
                  value: _tax,
                  onChanged: (value) => setState(() {
                    _tax = value;
                    _ensureCommanders();
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Course planaire (Planechase)'),
                  subtitle: const Text(
                    'Dé planaire et cartes de plans (chaos, planeswalk…).',
                  ),
                  value: _planechase,
                  onChanged: (value) => setState(() => _planechase = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Archennemi (Archenemy)'),
                  subtitle: const Text(
                    'Un joueur face au reste de la table, avec des schémas.',
                  ),
                  value: _archenemy,
                  onChanged: (value) => setState(() => _archenemy = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Primes (Bounty · OTJ)'),
                  subtitle: const Text(
                    'Cartes de prime Outlaws of Thunder Junction, niveaux 1–12.',
                  ),
                  value: _bounty,
                  onChanged: (value) => setState(() => _bounty = value),
                ),
                Row(
                  children: [
                    const Expanded(child: Text('Points de vie de départ')),
                    IconButton(
                      onPressed: _life > 1
                          ? () => setState(() => _life--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text(
                      '$_life',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      onPressed: _life < 200
                          ? () => setState(() => _life++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Semantics(
                button: true,
                label: 'Lancer la partie',
                child: FilledButton(
                  onPressed: _start,
                  child: Text(
                    _format == MatchFormat.treachery
                        ? 'Lancer · tirage + rôles Traîtrise'
                        : 'Lancer · tirage du premier',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Astuce : transférez une partie en cours via Menu → Transférer (QR).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CountPick extends StatelessWidget {
  const _CountPick({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFC4A46A) : const Color(0xFF1C212B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
