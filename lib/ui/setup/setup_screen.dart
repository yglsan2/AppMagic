import 'package:flutter/material.dart';
import 'package:mtg_table/data/safe_image.dart';
import 'package:mtg_table/data/scryfall_art.dart';
import 'package:mtg_table/domain/handicap.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/player_profile.dart';
import 'package:mtg_table/domain/table_panels.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/sheets/profiles_sheet.dart';
import 'package:mtg_table/ui/sheets/transfer_sheet.dart';
import 'package:mtg_table/ui/widgets/handicap_picker.dart';
import 'package:mtg_table/ui/widgets/help_tip.dart';
import 'package:mtg_table/ui/widgets/language_button.dart';
import 'package:mtg_table/l10n/app_lang.dart';
import 'package:mtg_table/l10n/l10n.dart';
import 'package:mtg_table/l10n/format_l10n.dart';

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
    this.onJoinTable,
    required this.onOpenNight,
    required this.onOpenPrivacy,
    this.nightLabel,
    this.profiles = const [],
    this.onSaveProfile,
    this.onLang,
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
  final Future<void> Function()? onJoinTable;
  final List<PlayerProfile> profiles;
  final Future<void> Function(PlayerProfile profile)? onSaveProfile;
  final ValueChanged<AppLang>? onLang;

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
  final GlobalKey _playerSetupKey = GlobalKey();
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
  /// 1 = compact ; 2 = deux téléphones ; 3 = trois (9–10).
  int _phonePanels = 1;
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
    _count = _normalizedCount(
      source.isEmpty ? info.defaultPlayers : source.length,
      info,
    );
    _syncPhonePanels();
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
    while (_drafts.length < maxTablePlayers) {
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

  int _normalizedCount(int value, FormatInfo info) {
    var next = value;
    if (info.sharedLife) {
      if (next.isOdd) next += 1;
      if (next < 2) next = 2;
    }
    next = next.clamp(info.minPlayers, info.maxPlayers);
    if (info.sharedLife && next.isOdd) {
      final lower = next - 1;
      next = lower >= info.minPlayers ? lower : next + 1;
      next = next.clamp(info.minPlayers, info.maxPlayers);
    }
    return next;
  }

  void _revealPlayerSetup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _playerSetupKey.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 280),
        alignment: 0.05,
      );
    });
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
      _count = _normalizedCount(_count, info);
      _syncPhonePanels();
      _ensureCommanders();
    });
    _revealPlayerSetup();
  }

  void _setCount(int value) {
    setState(() {
      _count = _normalizedCount(value, formatInfo(_format));
      _syncPhonePanels();
      _ensureCommanders();
    });
    _revealPlayerSetup();
  }

  void _syncPhonePanels() {
    switch (phoneNeedFor(_count)) {
      case TablePhoneNeed.one:
        _phonePanels = 1;
      case TablePhoneNeed.oneOrTwo:
        if (_phonePanels < 1 || _phonePanels > 2) _phonePanels = 1;
      case TablePhoneNeed.three:
        _phonePanels = 3;
    }
  }

  Future<void> _lookupArt(_DraftCmd commander) async {
    final name = _field(commander.id, commander.name).text.trim();
    if (name.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('setup_commander_name_required'))),
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
        SnackBar(
          content: Text(context.t('setup_card_found_no_art')),
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
      poisonThreshold: poisonThresholdFor(
        _format,
        widget.settings.poisonThreshold,
      ),
      turnAlertSeconds: widget.settings.turnAlertSeconds,
      timerMode: widget.settings.timerMode,
      timersEnabled: widget.settings.timersEnabled,
      tournament: widget.settings.tournament,
      chessBankSeconds: widget.settings.chessBankSeconds,
      chessBonusSeconds: widget.settings.chessBonusSeconds,
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
      phonePanels: suggestedPhoneCount(
        _count,
        preferMulti: _phonePanels > 1,
      ),
    );
    widget.onStart(game);
  }

  @override
  Widget build(BuildContext context) {
    final used = _drafts.take(_count).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: pageGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) {
              final pad = viewport.maxWidth < 400 ? 16.0 : 20.0;
              final contentWidth = (viewport.maxWidth - pad * 2).clamp(
                260.0,
                720.0,
              );
              final titleSize = viewport.maxWidth < 400 ? 30.0 : 36.0;
              return SingleChildScrollView(
                key: const Key('setup-form'),
                padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
              Center(
                child: Image.asset(
                  'assets/brand/lifestack.png',
                  width: viewport.maxWidth < 400 ? 88 : 108,
                  height: viewport.maxWidth < 400 ? 88 : 108,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'LifeStack',
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1.05,
                        color: const Color(0xFFF4F7FB),
                      ),
                    ),
                  ),
                  LanguageButton(
                    lang: widget.settings.lang,
                    onChanged: (lang) => widget.onLang?.call(lang),
                    compact: true,
                  ),
                ],
              ),
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
                            label: Text(context.t('setup_import')),
                          ),
                          OutlinedButton.icon(
                            onPressed: widget.onOpenStats,
                            icon: const Icon(Icons.emoji_events_outlined),
                            label: Text(context.t('setup_history')),
                          ),
                          TextButton(
                            onPressed: widget.onOpenSearch,
                            child: Text(context.t('setup_cards')),
                          ),
                          TextButton(
                            onPressed: widget.onOpenPrivacy,
                            child: Text(context.t('setup_privacy')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              HelpTip(
                enabled: widget.settings.beginnerTips,
                title: context.t('setup_formats'),
                message:
                    'Maintenez un format, ou touchez le i, pour lire '
                    'l’explication. Le nom anglais reste entre parenthèses.',
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
                      enabled: widget.settings.beginnerTips,
                      title: context.t(formatL10nLabel(info.format)),
                      message: context.t(formatL10nHelp(info.format)),
                      child: ChoiceChip(
                        label: Text(context.t(formatL10nLabel(info.format))),
                        selected: _format == info.format,
                        onSelected: (_) => _applyFormat(info),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              HelpTip(
                enabled: widget.settings.beginnerTips,
                title: context.t(formatL10nLabel(_format)),
                message: context.t(formatL10nHelp(_format)),
                showIcon: true,
                child: Text(
                  context.t(formatL10nDetail(_format)),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                ),
              ),
              if (_format == MatchFormat.duel)
                _FormatNote(
                  title: context.t('setup_duel_note_title'),
                  body: context.t('setup_duel_note_body'),
                )
              else if (_format == MatchFormat.commander && _count == 2)
                _FormatNote(
                  title: context.t('setup_commander_2p_title'),
                  body: context.t('setup_commander_2p_body'),
                ),
              const SizedBox(height: 8),
              Text(
                key: _playerSetupKey,
                formatInfo(_format).fixedPlayerCount
                    ? context.t('setup_players_fixed', {'n': '${formatInfo(_format).minPlayers}'})
                    : context.t('setup_players_range', {
                        'min': '${formatInfo(_format).minPlayers}',
                        'max': '${formatInfo(_format).maxPlayers}',
                      }),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final values = [
                    for (
                      var n = formatInfo(_format).minPlayers;
                      n <= formatInfo(_format).maxPlayers;
                      n++
                    )
                      if (!_shared || n.isEven) n,
                  ];
                  const gap = 8.0;
                  final size = values.isEmpty
                      ? 48.0
                      : ((contentWidth - gap * (values.length - 1)) /
                              values.length)
                          .clamp(40.0, 52.0);
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final n in values)
                        _CountPick(
                          key: ValueKey('player-count-$n'),
                          value: n,
                          selected: _count == n,
                          size: size,
                          onTap: () => _setCount(n),
                        ),
                    ],
                  );
                },
              ),
              if (phoneNeedFor(_count) == TablePhoneNeed.oneOrTwo) ...[
                const SizedBox(height: 14),
                Text(
                  context.t('setup_table_phones_title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t('setup_table_phones_hint_68'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _PhoneModePick(
                        selected: _phonePanels == 1,
                        title: context.t('setup_table_one_phone'),
                        subtitle: context.t('setup_table_one_phone_sub'),
                        onTap: () => setState(() => _phonePanels = 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PhoneModePick(
                        selected: _phonePanels == 2,
                        title: context.t('setup_table_two_phones'),
                        subtitle: context.t('setup_table_two_phones_sub'),
                        onTap: () => setState(() => _phonePanels = 2),
                      ),
                    ),
                  ],
                ),
              ],
              if (phoneNeedFor(_count) == TablePhoneNeed.three) ...[
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('setup_table_three_phones'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.t('setup_table_three_phones_sub'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              for (final player in used) ...[
                Row(
                  children: [
                    Tooltip(
                      message: context.t('setup_color_seat'),
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
                        decoration: InputDecoration(
                          labelText: context.t('setup_name_label'),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_handicaps && !_shared)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 64),
                          child: Text(
                            '${effectiveStartingLife(baseLife: _life, handicapsEnabled: true, lifeDelta: player.handicapLifeDelta)} PV',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: accentGold,
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: context.t('setup_load_profile_tooltip'),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
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
                      tooltip: context.t('setup_save_profile_tooltip'),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
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
                              final savedMsg = context.t('setup_profile_saved');
                              final failMsg = context.t('setup_profile_save_failed');
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
                                  SnackBar(
                                    content: Text(savedMsg),
                                  ),
                                );
                              } on Object {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(failMsg)),
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
                                tooltip: context.t('setup_scryfall_art_tooltip'),
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                onPressed: () =>
                                    _lookupArt(player.commanders[i]),
                                icon: const Icon(Icons.image_search, size: 20),
                              ),
                              if (player.commanders.length > 1)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
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
                              label: Text(context.t('setup_partner_commander')),
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
                        : 'Préconstruit ou deck compétitif, points de vie en plus ou en moins',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.t('setup_handicaps_title')),
                      subtitle: const Text(
                        'Un préconstruit peut commencer à 50 points de vie, '
                        'un deck compétitif à 30.',
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
                          tips: widget.settings.beginnerTips,
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
                child: Text(_more ? context.t('setup_fewer_options') : context.t('setup_more_options')),
              ),
              if (_more) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('setup_commander_damage')),
                  value: _damage,
                  onChanged: (value) => setState(() {
                    _damage = value;
                    _ensureCommanders();
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('setup_commander_tax')),
                  value: _tax,
                  onChanged: (value) => setState(() {
                    _tax = value;
                    _ensureCommanders();
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('setup_planechase')),
                  subtitle: const Text(
                    'Cartes de plan, et un dé : quatre faces blanches, une planeswalk, une chaos.',
                  ),
                  value: _planechase,
                  onChanged: (value) => setState(() => _planechase = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('setup_archenemy')),
                  subtitle: const Text(
                    'Un joueur contre le reste de la table, avec des stratagèmes.',
                  ),
                  value: _archenemy,
                  onChanged: (value) => setState(() => _archenemy = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('setup_bounty')),
                  subtitle: const Text(
                    'Cartes Prime de Hors-la-loi de Croisetonnerre, du niveau 1 au 12.',
                  ),
                  value: _bounty,
                  onChanged: (value) => setState(() => _bounty = value),
                ),
                Row(
                  children: [
                    Expanded(child: Text(context.t('setup_starting_life'))),
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
                label: context.t('setup_start_game'),
                child: FilledButton(
                  onPressed: _start,
                  child: Text(
                    _format == MatchFormat.treachery
                        ? 'Lancer · tirage + rôles Traîtrise'
                        : 'Lancer · tirage du premier',
                  ),
                ),
              ),
              if (widget.onJoinTable != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: widget.onJoinTable,
                  icon: const Icon(Icons.wifi_tethering),
                  label: Text(context.t('setup_join_table')),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Un seul écran suffit. Pour brancher d’autres téléphones '
                'avec LifeStack : lancez la partie, puis les deux mains '
                'qui se serrent, en haut. '
                'Ou rejoignez une table déjà ouverte.',
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

class _FormatNote extends StatelessWidget {
  const _FormatNote({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPick extends StatelessWidget {
  const _CountPick({
    super.key,
    required this.value,
    required this.selected,
    required this.onTap,
    this.size = 48,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent : surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? accent : line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: selected ? onAccent : const Color(0xFFF4F7FB),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneModePick extends StatelessWidget {
  const _PhoneModePick({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent.withValues(alpha: 0.22) : surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? accent : line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? accent : const Color(0xFFF4F7FB),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
