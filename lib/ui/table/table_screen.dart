import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtg_table/domain/coach.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/seating.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/setup/first_player_draw.dart';
import 'package:mtg_table/ui/sheets/card_journal_sheet.dart';
import 'package:mtg_table/ui/sheets/dice_sheet.dart';
import 'package:mtg_table/ui/sheets/history_sheet.dart';
import 'package:mtg_table/ui/sheets/life_log_sheet.dart';
import 'package:mtg_table/ui/sheets/players_sheet.dart';
import 'package:mtg_table/ui/sheets/restart_sheet.dart';
import 'package:mtg_table/ui/sheets/settings_sheet.dart';
import 'package:mtg_table/ui/sheets/recap_sheet.dart';
import 'package:mtg_table/net/table_link.dart';
import 'package:mtg_table/ui/sheets/table_link_sheet.dart';
import 'package:mtg_table/ui/sheets/transfer_sheet.dart';
import 'package:mtg_table/ui/tools/card_search_screen.dart';
import 'package:mtg_table/ui/widgets/name_dialog.dart';
import 'package:mtg_table/ui/help/option_help.dart';
import 'package:mtg_table/ui/widgets/help_tip.dart';
import 'package:mtg_table/ui/widgets/option_glyphs.dart';
import 'package:mtg_table/ui/widgets/finale_fx.dart';
import 'package:mtg_table/ui/widgets/player_panel.dart';
import 'package:mtg_table/ui/widgets/table_audio.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({
    super.key,
    required this.controller,
    required this.settings,
    required this.onSettings,
    required this.onLeave,
    required this.onCoachDismissed,
    this.onArchiveWin,
    this.link,
  });

  final GameController controller;
  final AppSettings settings;
  final TableLinkController? link;
  final ValueChanged<AppSettings> onSettings;
  final VoidCallback onLeave;
  // Conservé : le bandeau global a été retiré, le tour s’affiche sur le siège.
  // ignore: unused_field
  final VoidCallback onCoachDismissed;
  final Future<bool> Function()? onArchiveWin;

  @override
  State<TableScreen> createState() => _TableScreenState();
}

enum _BoardLayout { auto, phone, stack, split, round, line }

enum _DisplayExtra { phone, table, names }

String _layoutName(_BoardLayout layout, int players) => switch (layout) {
  _BoardLayout.phone => players >= 5 ? 'En cercle' : 'Façon téléphone',
  _BoardLayout.stack => 'Comptes empilés',
  _BoardLayout.split => '4 écrans',
  _BoardLayout.round => 'Table ronde',
  _BoardLayout.line => 'Liste droite',
  _BoardLayout.auto => 'Automatique',
};

/// Grand écran branché : table ronde ou liste droite pour trois joueurs.
bool _roundTableRoom(Size size) {
  return size.shortestSide >= 640 && size.longestSide >= 900;
}

class _CombatCrownAsk extends StatelessWidget {
  const _CombatCrownAsk({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final ask = controller.combatAsk;
    if (ask == null) return const SizedBox.shrink();
    final monarch = controller.playerById(ask.monarchId);
    final attacker = ask.attackerId == null
        ? null
        : controller.playerById(ask.attackerId!);
    final opponents = [
      for (final player in controller.game.players)
        if (player.id != monarch.id && !controller.game.isDefeated(player))
          player,
    ];
    return Material(
      elevation: 8,
      color: const Color(0xFF2A2418),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              attacker == null
                  ? '${monarch.name} perd des points. Une créature adverse '
                        'a-t-elle infligé une blessure de combat ?'
                  : '${attacker.name} retire des points à ${monarch.name}. '
                        'C’est une blessure de combat ?',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (attacker != null)
                  FilledButton(
                    onPressed: () => controller.answerCombat(attacker.id),
                    child: Text('${attacker.name} prend la couronne'),
                  )
                else
                  for (final player in opponents)
                    FilledButton(
                      onPressed: () => controller.answerCombat(player.id),
                      child: Text(player.name),
                    ),
                TextButton(
                  onPressed: () => controller.answerCombat(null),
                  child: const Text('Pas du combat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TableScreenState extends State<TableScreen> {
  Timer? _toastTimer;
  String? _toast;
  int _seenFlash = 0;
  int _seenCrown = 0;
  int _coachTurn = -1;
  int _coachPoison = -1;
  List<String> _coachLines = const [];
  DayState _trackedDay = DayState.unset;
  String? _skyHelpFor;
  bool _skyHelpOnce = false;
  _BoardLayout _layout = _BoardLayout.auto;

  /// Siège affiché en mode Focus (indépendant du tour actif).
  String? _focusPlayerId;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onGame);
    widget.link?.addListener(_onLink);
    widget.link?.onSession = _onRemoteSession;
    _coachTurn = widget.controller.game.turnCount;
    _trackedDay = widget.controller.game.dayState;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final link = widget.link;
    if (link == null || !link.hosting || link.centerChosen) return;
    final size = MediaQuery.sizeOf(context);
    link.centerChosen = true;
    if (size.width >= 1000 && size.height >= 680) {
      link.setCenter(true);
    }
  }

  @override
  void didUpdateWidget(TableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onGame);
      widget.controller.addListener(_onGame);
    }
    if (!widget.settings.beginnerTips) {
      _coachLines = const [];
      if (_skyHelpOnce) {
        _skyHelpFor = null;
        _skyHelpOnce = false;
      }
    }
  }

  List<_BoardLayout> _layoutChoices(int players, {required bool roundRoom}) {
    if (players < 2) return const [];
    if (players == 3 && roundRoom) {
      return const [
        _BoardLayout.phone,
        _BoardLayout.stack,
        _BoardLayout.round,
        _BoardLayout.line,
      ];
    }
    if (players == 4) {
      return const [
        _BoardLayout.phone,
        _BoardLayout.stack,
        _BoardLayout.split,
      ];
    }
    return const [_BoardLayout.phone, _BoardLayout.stack];
  }

  _BoardLayout _shownLayout(int players, {required bool roundRoom}) {
    if (_layout == _BoardLayout.split && players != 4) return _BoardLayout.phone;
    if (_layout == _BoardLayout.round && (players != 3 || !roundRoom)) {
      return _BoardLayout.phone;
    }
    if (_layout == _BoardLayout.line && (players != 3 || !roundRoom)) {
      return _BoardLayout.phone;
    }
    if (_layout != _BoardLayout.auto) return _layout;
    if (players >= 5) return _BoardLayout.stack;
    return _BoardLayout.phone;
  }

  void _setLayout(_BoardLayout layout) {
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _toast = null);
    });
    setState(() {
      _layout = layout;
      _toast = switch (layout) {
        _BoardLayout.phone =>
          'Répartis autour de l’écran : chacun lit son côté.',
        _BoardLayout.stack =>
          'Comptes empilés, tous dans le même sens. Pratique sur un tactile ou un projecteur.',
        _BoardLayout.split =>
          'Quatre écrans, tous dans le même sens : haut gauche, haut droite, bas gauche, bas droite.',
        _BoardLayout.round =>
          'Table ronde : les trois places à égale distance autour du centre.',
        _BoardLayout.line =>
          'Liste droite : les trois places dans le même sens, en colonne ou côte à côte selon l’écran.',
        _BoardLayout.auto => 'Disposition automatique.',
      };
    });
  }

  void _onGame() {
    if (!mounted) return;
    _syncSkyHelp();
    final link = widget.link;
    if (link != null && link.linked && !widget.controller.applyingRemote) {
      link.publishLocal(widget.controller.exportSession());
    }
    final crown = widget.controller.crownChange;
    final fresh = crown != null &&
        widget.controller.crownAt != null &&
        DateTime.now().difference(widget.controller.crownAt!) <
            const Duration(seconds: 5);
    final mine = link?.mySeat;
    final privateSeat =
        link != null && link.linked && !link.center && mine != null;
    if (privateSeat && fresh && crown.id != _seenCrown) {
      _seenCrown = crown.id;
      _seenFlash = widget.controller.flashId;
      if (crown.gainedId == mine) {
        _showToast(
          'Vous êtes monarque. Au début de votre étape de fin, piochez une carte.',
          const Duration(seconds: 5),
        );
        return;
      }
    } else if (widget.settings.beginnerTips && fresh && crown.id != _seenCrown) {
      _seenCrown = crown.id;
      _seenFlash = widget.controller.flashId;
      final name = widget.controller.playerById(crown.gainedId).name;
      _toastTimer?.cancel();
      _toastTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _toast = null);
      });
      setState(() {
        _toast = '$name, vous êtes maintenant monarque. '
            'Pensez à piocher une carte au début de votre étape de fin. '
            'Personne n’est indétrônable !';
      });
      return;
    }
    if (widget.settings.beginnerTips && fresh && crown.id == _seenCrown) {
      _seenFlash = widget.controller.flashId;
      setState(() {});
      return;
    }
    final id = widget.controller.flashId;
    if (id != _seenFlash) {
      _seenFlash = id;
      _showToast(widget.controller.flashText, const Duration(seconds: 2));
      return;
    }
    _coachPrivate(mine);
    setState(() {});
  }

  void _showToast(String text, Duration duration) {
    _toastTimer?.cancel();
    _toastTimer = Timer(duration, () {
      if (mounted) setState(() => _toast = null);
    });
    setState(() => _toast = text);
  }

  void _syncSkyHelp() {
    final game = widget.controller.game;
    final day = game.dayState;
    final activated = day != DayState.unset && day != _trackedDay;
    _trackedDay = day;
    if (!widget.settings.beginnerTips) {
      if (_skyHelpOnce) {
        _skyHelpFor = null;
        _skyHelpOnce = false;
      }
      return;
    }
    if (activated &&
        !widget.settings.dayNightIntroSeen &&
        _skyHelpFor == null &&
        game.players.isNotEmpty) {
      _skyHelpFor = game.players[game.activeIndex].id;
      _skyHelpOnce = true;
    }
  }

  void _explainSky() {
    final game = widget.controller.game;
    if (game.players.isEmpty) return;
    setState(() {
      _skyHelpFor = game.players[game.activeIndex].id;
      _skyHelpOnce = false;
    });
  }

  void _dismissSkyHelp() {
    final once = _skyHelpOnce;
    setState(() {
      _skyHelpFor = null;
      _skyHelpOnce = false;
    });
    if (once && !widget.settings.dayNightIntroSeen) {
      widget.onSettings(
        widget.settings.copyWith(dayNightIntroSeen: true),
      );
    }
  }

  void _coachPrivate(String? mine) {
    final link = widget.link;
    final game = widget.controller.game;
    if (!widget.settings.beginnerTips || game.tournament || game.players.isEmpty) {
      _coachLines = const [];
      return;
    }
    final personal =
        link != null && link.linked && !link.center && mine != null;
    if (personal && !game.players.any((player) => player.id == mine)) return;
    final active = game.players[game.activeIndex].id;
    if (personal && mine != active) {
      _coachLines = const [];
      return;
    }
    final me = widget.controller.playerById(personal ? mine : active);
    if (personal) {
      if (_coachPoison < 0) _coachPoison = me.poison;
      if (me.poison > _coachPoison) {
        final reached = me.poison;
        _coachPoison = reached;
        if (reached >= game.poisonThreshold - 2) {
          _showToast(
            'Poison $reached. Le seuil est ${game.poisonThreshold}.',
            const Duration(seconds: 4),
          );
          return;
        }
      } else {
        _coachPoison = me.poison;
      }
    }
    if (_coachTurn != game.turnCount) {
      _coachTurn = game.turnCount;
      _coachLines = turnReminders(game, me);
    }
  }

  final Map<String, ScorePane> _sessionPane = {};

  Map<String, ScorePane> _panes() {
    return {
      for (final player in widget.controller.game.players)
        player.id:
            _sessionPane[player.id] ?? widget.settings.paneNamed(player.name),
    };
  }

  void _toastPane(String text) {
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _toast = null);
    });
    setState(() => _toast = text);
  }

  void _choosePane(String playerId, ScorePane pane) {
    final player = widget.controller.game.playerById(playerId);
    setState(() => _sessionPane[playerId] = pane);
    _toastPane('${player.name} : ${scorePaneLabel(pane)}');
  }

  void _savePane(String playerId) {
    final player = widget.controller.game.playerById(playerId);
    final pane = _sessionPane[playerId] ?? widget.settings.paneNamed(player.name);
    widget.onSettings(widget.settings.savingPane(player.name, pane));
    setState(() => _sessionPane[playerId] = pane);
    _toastPane(
      'Préférence enregistrée pour ${player.name} : ${scorePaneLabel(pane)}.',
    );
  }

  var _landscapeHeld = false;

  void _holdLandscape(bool hold) {
    if (_landscapeHeld == hold) return;
    _landscapeHeld = hold;
    SystemChrome.setPreferredOrientations(
      hold
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : DeviceOrientation.values,
    );
  }

  @override
  void dispose() {
    if (_landscapeHeld) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    _toastTimer?.cancel();
    widget.controller.removeListener(_onGame);
    widget.link?.removeListener(_onLink);
    if (widget.link?.onSession == _onRemoteSession) {
      widget.link?.onSession = null;
    }
    super.dispose();
  }

  void _onLink() {
    if (mounted) setState(() {});
  }

  void _onRemoteSession(Map<String, dynamic> session) {
    if (!mounted) return;
    widget.controller.adoptSession(session);
  }

  Future<void> _leave() async {
    final ok = await confirmAction(
      context,
      title: 'Retour au salon',
      message: 'La partie reste enregistrée sur cet appareil.',
      confirmLabel: 'Quitter la table',
    );
    if (!ok || !mounted) return;
    widget.onLeave();
  }

  Future<void> _restart({RestartKind initial = RestartKind.rematch}) async {
    if (initial == RestartKind.rematch) {
      await widget.onArchiveWin?.call();
    }
    if (!mounted) return;
    await showRestartSheet(
      context,
      controller: widget.controller,
      initial: initial,
    );
  }

  Future<void> _redrawFirst() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => FirstPlayerDraw(
          players: widget.controller.game.players,
          onPicked: (index) {
            widget.controller.setActive(index);
            Navigator.of(context).pop();
          },
          onSkip: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _about() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('LifeStack'),
        content: const SingleChildScrollView(
          child: Text(
            'Compteur de partie, écrit par DesertYGL. On pose l’écran '
            'au milieu, chacun lit son côté, et on joue. Les dégâts de '
            'chaque commandant se comptent d’un geste, partenaires compris.\n\n'
            'Le journal de cartes, en option, passe par Scryfall et reste '
            'sur l’appareil. Il propose les effets simples, et attend une '
            'confirmation avant de toucher aux points de vie. Ce n’est pas '
            'un moteur de règles, ni un juge.\n\n'
            'Licence\n'
            'LifeStack est un logiciel libre, publié par DesertYGL sous la '
            'GNU General Public License version 3. Tu peux le copier, le '
            'modifier et le partager, à condition de garder cette licence '
            'et de dire ce que tu as changé. Le texte complet est le fichier '
            'LICENSE du projet. Il est fourni tel quel, sans garantie '
            'd’aucune sorte.\n\n'
            'Magic\n'
            'Magic: The Gathering, les noms de cartes, les images et les '
            'règles appartiennent à Wizards of the Coast LLC. LifeStack est '
            'un projet de fan, non officiel. Wizards ne le fabrique pas, '
            'ne le vérifie pas, ne l’approuve pas et ne le sponsorise pas. '
            'DesertYGL n’est pas Wizards, et n’est pas responsable de ce '
            'qu’un juge, un magasin, Wizards ou un autre joueur décide.\n\n'
            'Responsabilité\n'
            'DesertYGL ne répond pas des points mal comptés, d’une partie '
            'perdue, d’un tournoi, d’une coupure réseau, d’un relais tiers '
            '(HiveMQ, EMQX), de Scryfall, ni de ce que tu choisis d’envoyer '
            'ou d’effacer. Tu utilises LifeStack à tes risques.\n\n'
            'Vie privée et accessibilité\n'
            'Avant la partie : Vie privée. La partie locale reste sur '
            'l’appareil. Le salon en ligne, si tu l’ouvres, envoie la table '
            'chiffrée le temps de la partie. L’écran est en français, le '
            'texte suit la taille du système, le fond est sombre et les '
            'boutons ont un nom. Ce n’est pas un audit RGAA officiel.\n\n'
            'Effets dessinés\n'
            'Les gouttes, les étincelles grises et les cinq signes du pentagone sont dessinés pour LifeStack. '
            'Le reste des animations vient de packs séparés (Aura, lames et éclairs de Dolkyns, '
            'crânes de Viktor Hahn, Ember Flipbooks d’Inkharbor, Crisp Juice, Elemental Spellcraft, '
            'Elemental Magic, Magic VFX, feux de Spiney, fumée de Beast, '
            'PVFX Foundry, Slash Effect, verts de ParticleFX Studio). Les sons viennent de '
            'Fantasy SFX et de Kenney. Le clic des touches vient d’ElevenLabs, '
            'le son des + d’un notify Pixabay raccourci. Les packs et ces sons ne sont pas de DesertYGL '
            'et ne sont pas couverts par la GPL. On ne les redistribue pas '
            'toutes seules.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    widget.controller.rememberCommanderLog =
        widget.settings.rememberCommanderLog;
    widget.controller.noEndTurn = widget.settings.noEndTurn;
    _holdLandscape(widget.controller.game.players.length == 4);
    TableAudio.master = widget.settings.sounds;
    TableAudio.effects = widget.settings.effectSounds;
    TableAudio.touches = widget.settings.touchSounds;
    GameController.lifeSound = (cast, delta) {
      if (widget.settings.finaleStyle == FinaleStyle.still) return;
      if (cast == CastTone.aucune) return;
      TableAudio.playWound(delta);
    };
    final game = widget.controller.game;
    final personalPhone = widget.link != null &&
        widget.link!.linked &&
        !widget.link!.center;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: FinaleScope(
        style: widget.settings.finaleStyle,
        saltLines: widget.settings.saltLines,
        epitaphLife: widget.settings.epitaphLife,
        epitaphPoison: widget.settings.epitaphPoison,
        epitaphCommander: widget.settings.epitaphCommander,
        epitaphLeave: widget.settings.epitaphLeave,
        epitaphWin: widget.settings.epitaphWin,
        onArchiveWin: widget.onArchiveWin,
        child: OptionCaption(
        names: widget.settings.optionNames,
        child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: pageGradient),
          child: SafeArea(
            child: SeatPanes(
              byId: _panes(),
              onChoose: _choosePane,
              onSave: _savePane,
              child: SkyIntro(
                playerId: _skyHelpFor,
                title: tipDayNight.title,
                message: tipDayNight.message,
                onDismiss: _dismissSkyHelp,
                child: TableDay(
                state: game.dayState,
                child: Stack(
              children: [
                Column(
                  children: [
                    _Bar(
                      controller: widget.controller,
                      canUndo: widget.controller.canUndo,
                      canRedo: widget.controller.canRedo,
                      onLeave: _leave,
                      onUndo: widget.controller.undo,
                      onRedo: widget.controller.redo,
                      onDice: () => showDiceSheet(context, widget.controller),
                      onHistory: () =>
                          showHistorySheet(context, widget.controller),
                      onMenu: (action) {
                        switch (action) {
                          case _Menu.players:
                            showPlayersSheet(context, widget.controller);
                          case _Menu.link:
                            final link = widget.link;
                            if (link == null) break;
                            link.setCenter(false);
                            showTableLinkSheet(
                              context,
                              link: link,
                              controller: widget.controller,
                            );
                          case _Menu.first:
                            _redrawFirst();
                          case _Menu.cardJournal:
                            showCardJournalSheet(context, widget.controller);
                          case _Menu.history:
                            showHistorySheet(context, widget.controller);
                          case _Menu.dayNight:
                            final next = switch (game.dayState) {
                              DayState.unset || DayState.night => DayState.day,
                              DayState.day => DayState.night,
                            };
                            widget.controller.setDay(next);
                          case _Menu.tips:
                            final tipsOn = !widget.settings.beginnerTips;
                            widget.onSettings(
                              widget.settings.copyWith(beginnerTips: tipsOn),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  tipsOn
                                      ? 'Bulles d’aide activées. Survole ou '
                                            'maintiens Mes PV, un adversaire '
                                            'ou un commandant reçu.'
                                      : 'Bulles d’aide désactivées.',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          case _Menu.transfer:
                            showExportTransferSheet(context, widget.controller);
                          case _Menu.search:
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const CardSearchScreen(),
                              ),
                            );
                          case _Menu.settings:
                            showSettingsSheet(
                              context,
                              settings: widget.settings,
                              onChanged: widget.onSettings,
                              cast: sharedCast(game.players),
                              onCast: (cast) {
                                widget.controller.setCastAll(cast);
                                widget.onSettings(
                                  widget.settings.copyWith(
                                    finaleStyle: finaleForCast(cast),
                                  ),
                                );
                              },
                            );
                          case _Menu.layoutPhone:
                            _setLayout(_BoardLayout.phone);
                          case _Menu.layoutStack:
                            _setLayout(_BoardLayout.stack);
                          case _Menu.layoutSplit:
                            _setLayout(_BoardLayout.split);
                          case _Menu.layoutRound:
                            _setLayout(_BoardLayout.round);
                          case _Menu.layoutLine:
                            _setLayout(_BoardLayout.line);
                          case _Menu.rotate:
                            widget.controller.rotateSeats();
                          case _Menu.shuffle:
                            widget.controller.shuffleSeats();
                          case _Menu.treacheryDeal:
                            widget.controller.dealTreacheryRoles();
                          case _Menu.rematch:
                            _restart(initial: RestartKind.rematch);
                          case _Menu.reset:
                            _restart(initial: RestartKind.zero);
                          case _Menu.recap:
                            showGameRecapSheet(context, widget.controller);
                          case _Menu.about:
                            _about();
                        }
                      },
                      showCardJournal: widget.settings.cardJournalAssist &&
                          !game.tournament,
                      showTreachery: game.format == MatchFormat.treachery,
                      beginnerTips: widget.settings.beginnerTips,
                      layouts: personalPhone
                          ? const []
                          : _layoutChoices(
                              game.players.length,
                              roundRoom: _roundTableRoom(MediaQuery.sizeOf(context)),
                            ),
                      currentLayout: _shownLayout(
                        game.players.length,
                        roundRoom: _roundTableRoom(MediaQuery.sizeOf(context)),
                      ),
                      onLayout: _setLayout,
                      phoneMode: personalPhone,
                      onPhoneMode: widget.link == null
                          ? null
                          : () {
                              widget.link!.setCenter(false);
                              showTableLinkSheet(
                                context,
                                link: widget.link!,
                                controller: widget.controller,
                              );
                            },
                      onTableMode: widget.link == null
                          ? null
                          : () => widget.link!.setCenter(true),
                      optionNames: widget.settings.optionNames,
                      onCast: (cast) {
                        widget.controller.setCastAll(cast);
                        widget.onSettings(
                          widget.settings.copyWith(
                            finaleStyle: finaleForCast(cast),
                          ),
                        );
                      },
                      onOptionNames: () => widget.onSettings(
                        widget.settings.copyWith(
                          optionNames: !widget.settings.optionNames,
                        ),
                      ),
                    ),
                    if (game.victoryBanner() != null)
                      _VictoryBanner(
                        text: FinaleScope.epitaphVictory(
                              context,
                              name: game.winnerLabel() ?? '',
                              winner: game.winnerLabel() ?? '',
                            ) ??
                            game.victoryBanner()!,
                        onRematch: () => _restart(initial: RestartKind.rematch),
                        onZero: () => _restart(initial: RestartKind.zero),
                        onRecap: () =>
                            showGameRecapSheet(context, widget.controller),
                      ),
                    if (widget.settings.showLifeFeed &&
                        widget.controller.lifeLog.isNotEmpty)
                      _LifeFeedStrip(controller: widget.controller),
                    if (game.timersEnabled)
                      _TurnTimerBar(controller: widget.controller),
                    _TableExtras(
                      controller: widget.controller,
                      showTips: widget.settings.beginnerTips,
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          LayoutBuilder(
                        builder: (context, constraints) {
                          final tablet = useFourSides(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            players: game.players.length,
                          );
                          final landscape = useLandscapeEdges(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            players: game.players.length,
                          );
                          final fourSides = tablet || landscape;
                          final plan = (landscape
                                  ? landscapePlan(game.players.length)
                                  : planFor(
                                      players: game.players.length,
                                      fourSides: fourSides,
                                    ))
                              .oriented(game.seatShift, game.players.length);
                          final list = preferList(
                            mode: widget.settings.viewMode,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            plan: plan,
                          );
                          final explicitList =
                              widget.settings.viewMode == ViewMode.list ||
                              widget.settings.viewMode == ViewMode.focus;
                          final count = game.players.length;
                          if (personalPhone) {
                            final mine = widget.link!.mySeat;
                            final known = mine != null &&
                                game.players.any((player) => player.id == mine);
                            if (!known) {
                              return LinkedSeatPicker(
                                controller: widget.controller,
                                link: widget.link!,
                              );
                            }
                            return LinkedSeatView(
                              controller: widget.controller,
                              mine: mine!,
                              haptic: widget.settings.haptic,
                              showTips: widget.settings.beginnerTips,
                            );
                          }
                          if (widget.link?.center == true && count >= 5) {
                            return _FourSides(
                              plan: pokerPlan(count).oriented(
                                game.seatShift,
                                count,
                              ),
                              controller: widget.controller,
                              haptic: widget.settings.haptic,
                              showTips: widget.settings.beginnerTips,
                            );
                          }
                          final choice = _layout == _BoardLayout.split && count != 4
                              ? _BoardLayout.phone
                              : _layout;
                          final forced = choice != _BoardLayout.auto;
                          Widget stacked() => _HorizontalBands(
                            plan: SeatingPlan(
                              south: [for (var i = 0; i < count; i++) i],
                              north: const [],
                              fourSides: false,
                            ).oriented(game.seatShift, count),
                            controller: widget.controller,
                            haptic: widget.settings.haptic,
                            showTips: widget.settings.beginnerTips,
                          );
                          if (choice == _BoardLayout.line &&
                              count == 3 &&
                              constraints.maxWidth >= 720 &&
                              constraints.maxHeight >= 480) {
                            return _StraightThree(
                              shift: game.seatShift,
                              controller: widget.controller,
                              haptic: widget.settings.haptic,
                              showTips: widget.settings.beginnerTips,
                            );
                          }
                          if (choice == _BoardLayout.round &&
                              count == 3 &&
                              constraints.maxWidth >= 720 &&
                              constraints.maxHeight >= 480) {
                            return _RoundThree(
                              shift: game.seatShift,
                              controller: widget.controller,
                              haptic: widget.settings.haptic,
                              showTips: widget.settings.beginnerTips,
                            );
                          }
                          if (count == 3 &&
                              choice != _BoardLayout.stack &&
                              choice != _BoardLayout.round &&
                              choice != _BoardLayout.line &&
                              !explicitList) {
                            return _FacingThree(
                              shift: game.seatShift,
                              controller: widget.controller,
                              haptic: widget.settings.haptic,
                              showTips: widget.settings.beginnerTips,
                            );
                          }
                          if (choice == _BoardLayout.split) {
                            return _SplitQuarters(
                              shift: game.seatShift,
                              controller: widget.controller,
                              haptic: widget.settings.haptic,
                              showTips: widget.settings.beginnerTips,
                            );
                          }
                          final autoStack =
                              choice == _BoardLayout.auto && count >= 5;
                          if ((choice == _BoardLayout.stack || autoStack) &&
                              count >= 2 &&
                              count <= maxTablePlayers &&
                              (forced || !explicitList)) {
                            return stacked();
                          }
                          if (choice == _BoardLayout.phone &&
                              count >= 5 &&
                              count <= maxTablePlayers) {
                            return _FourSides(
                              plan: pokerPlan(count).oriented(
                                game.seatShift,
                                count,
                              ),
                              controller: widget.controller,
                              haptic: widget.settings.haptic,
                              showTips: widget.settings.beginnerTips,
                            );
                          }
                          if (choice == _BoardLayout.phone && count <= 2) {
                            return _TwoSides(
                              plan: plan,
                              controller: widget.controller,
                              haptic: widget.settings.haptic,
                              showTips: widget.settings.beginnerTips,
                            );
                          }
                          if (count == 4 &&
                              !explicitList &&
                              choice != _BoardLayout.stack &&
                              choice != _BoardLayout.split) {
                            return _SplitQuarters(
                              shift: game.seatShift,
                              controller: widget.controller,
                              haptic: widget.settings.haptic,
                              showTips: widget.settings.beginnerTips,
                            );
                          }
                          if (!explicitList &&
                              !fourSides &&
                              count == 3 &&
                              choice != _BoardLayout.stack) {
                            return _HorizontalBands(
                              plan: plan,
                              controller: widget.controller,
                              haptic: widget.settings.haptic,
                              showTips: widget.settings.beginnerTips,
                            );
                          }
                          if (list) {
                            final focusMode =
                                widget.settings.viewMode == ViewMode.focus;
                            final focusId =
                                _focusPlayerId ??
                                game.players[game.activeIndex].id;
                            return _ListTable(
                              controller: widget.controller,
                              haptic: widget.settings.haptic,
                              showTips: widget.settings.beginnerTips,
                              focusMode: focusMode,
                              focusPlayerId: focusId,
                              onFocusPlayer: focusMode
                                  ? (id) => setState(() => _focusPlayerId = id)
                                  : null,
                            );
                          }
                          if (plan.fourSides) {
                            return _FourSides(
                              plan: plan,
                              controller: widget.controller,
                              haptic: widget.settings.haptic,
                              showTips: widget.settings.beginnerTips,
                            );
                          }
                          return _TwoSides(
                            plan: plan,
                            controller: widget.controller,
                            haptic: widget.settings.haptic,
                            showTips: widget.settings.beginnerTips,
                          );
                        },
                      ),
                          Positioned.fill(
                            child: Center(
                              child: buildTableSky(
                                context,
                                controller: widget.controller,
                                onExplain: _explainSky,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.controller.combatAsk != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _CombatCrownAsk(controller: widget.controller),
                  ),
                if (_coachLines.isNotEmpty)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 64,
                    child: Material(
                      elevation: 8,
                      color: const Color(0xFF1C2430),
                      borderRadius: BorderRadius.circular(16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                          children: [
                            const Text(
                              'À vous',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            for (final line in _coachLines)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(line),
                              ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => _coachLines = const []),
                                child: const Text('Vu'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_toast != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 112,
                    child: Material(
                      elevation: 8,
                      color: accent,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _toast!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
              ),
              ),
            ),
          ),
        ),
      ),
      ),
      ),
    );
  }
}

enum _Menu {
  players,
  first,
  cardJournal,
  history,
  dayNight,
  tips,
  link,
  transfer,
  search,
  settings,
  rotate,
  shuffle,
  treacheryDeal,
  layoutPhone,
  layoutStack,
  layoutSplit,
  layoutRound,
  layoutLine,
  recap,
  rematch,
  reset,
  about,
}

class _LifeFeedStrip extends StatelessWidget {
  const _LifeFeedStrip({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final log = controller.lifeLog;
    if (log.isEmpty) return const SizedBox.shrink();
    final latest = log.first;
    final preview = log
        .take(3)
        .map((e) {
          if (e.delta == 0) return e.line;
          return '${e.playerName} ${e.deltaLabel}';
        })
        .join(' · ');
    final extra = log.length > 3 ? log.length - 3 : 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Material(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showLifeLogSheet(context, controller),
          child: Semantics(
            button: true,
            label: 'Voir tous les décomptes de points de vie',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      extra > 0
                          ? '$preview · +$extra'
                          : '$preview · ${latest.from}→${latest.to}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  Text(
                    'Tout',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
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

class _Bar extends StatelessWidget {
  const _Bar({
    required this.controller,
    required this.canUndo,
    required this.canRedo,
    required this.onLeave,
    required this.onUndo,
    required this.onRedo,
    required this.onDice,
    required this.onHistory,
    required this.onMenu,
    this.showCardJournal = true,
    this.showTreachery = false,
    this.beginnerTips = true,
    this.layouts = const [],
    this.currentLayout = _BoardLayout.auto,
    this.onLayout,
    this.onPhoneMode,
    this.onTableMode,
    this.phoneMode = false,
    this.optionNames = false,
    this.onOptionNames,
    this.onCast,
  });

  final GameController controller;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onLeave;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onDice;
  final VoidCallback onHistory;
  final ValueChanged<_Menu> onMenu;
  final bool showCardJournal;
  final bool showTreachery;
  final bool beginnerTips;
  final List<_BoardLayout> layouts;
  final _BoardLayout currentLayout;
  final ValueChanged<_BoardLayout>? onLayout;
  final VoidCallback? onPhoneMode;
  final VoidCallback? onTableMode;
  final bool phoneMode;
  final bool optionNames;
  final VoidCallback? onOptionNames;
  final ValueChanged<CastTone>? onCast;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        final slot = wide ? 44.0 : (onPhoneMode != null ? 30.0 : 34.0);
        return SizedBox(
          height: 52,
          child: Row(
            children: [
              _BarIcon(
            slot: slot,
                icon: Icons.arrow_back,
                tooltip: 'Salon',
                help: beginnerTips ? tipSalon : null,
                onPressed: onLeave,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manche ${game.roundNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: wide ? 15 : 13,
                      ),
                    ),
                    if (game.timersEnabled) ...[
                      _LiveClocks(controller: controller),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            if (controller.clockPaused) {
                              controller.resumeClock();
                            } else {
                              controller.pauseClock();
                            }
                          },
                          child: Text(
                            controller.clockPaused ? 'Reprendre' : 'Pause',
                          ),
                        ),
                      ),
                    ],
                    if (game.tournament)
                      const Text(
                        'Tournoi · compteur visible, sans conseil',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
          _BarIcon(
            slot: slot,
            icon: Icons.undo,
            tooltip: 'Annuler',
            help: beginnerTips ? tipUndo : null,
            onPressed: canUndo ? onUndo : null,
            emphasize: true,
          ),
          _BarIcon(
            slot: slot,
            icon: Icons.redo,
            tooltip: 'Rétablir',
            help: beginnerTips ? tipRedo : null,
            onPressed: canRedo ? onRedo : null,
          ),
          _BarIcon(
            slot: slot,
            icon: Icons.history,
            tooltip: 'Historique',
            help: beginnerTips ? tipHistory : null,
            onPressed: onHistory,
          ),
          _BarIcon(
            slot: slot,
            icon: Icons.casino,
            tooltip: 'Dés',
            help: beginnerTips ? tipDice : null,
            onPressed: onDice,
          ),
          PopupMenuButton<CastTone>(
            tooltip: 'Animations',
            padding: EdgeInsets.zero,
            onSelected: onCast,
            itemBuilder: (context) {
              final current = sharedCast(controller.game.players);
              return [
                for (final choice in CastTone.values)
                  PopupMenuItem(
                    value: choice,
                    child: Text(
                      choice == current
                          ? '${castToneLabel(choice)}  · actuel'
                          : castToneLabel(choice),
                    ),
                  ),
              ];
            },
            child: SizedBox(
              width: slot,
              height: 48,
              child: Center(
                child: CinemaCameraIcon(
                  color: IconTheme.of(context).color ?? Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          if (layouts.isNotEmpty || onPhoneMode != null || onOptionNames != null)
            HelpTip(
              enabled: beginnerTips,
              longPress: false,
              title: tipLayout.title,
              message: tipLayout.message,
              child: PopupMenuButton<Object>(
              tooltip: 'Disposition de l’écran',
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value is _BoardLayout) {
                  onLayout?.call(value);
                } else if (value == _DisplayExtra.phone) {
                  onPhoneMode?.call();
                } else if (value == _DisplayExtra.table) {
                  onTableMode?.call();
                } else if (value == _DisplayExtra.names) {
                  onOptionNames?.call();
                }
              },
              itemBuilder: (context) => [
                if (onOptionNames != null)
                  PopupMenuItem(
                    value: _DisplayExtra.names,
                    child: Text(optionNames ? 'Logos seuls' : 'Logos et noms'),
                  ),
                if (onTableMode != null && phoneMode)
                  const PopupMenuItem(
                    value: _DisplayExtra.table,
                    child: Text('La table entière'),
                  ),
                for (final layout in layouts)
                  PopupMenuItem(
                    value: layout,
                    child: Text(
                      layout == currentLayout
                          ? '${_layoutName(layout, controller.game.players.length)}  · actuel'
                          : _layoutName(layout, controller.game.players.length),
                    ),
                  ),
              ],
              child: SizedBox(
                width: slot,
                height: 48,
                child: const Icon(Icons.touch_app, size: 22),
              ),
            ),
            ),
          _BarIcon(
            slot: slot,
            icon: beginnerTips ? Icons.help : Icons.help_outline,
            tooltip: beginnerTips
                ? 'Désactiver les bulles d’aide'
                : 'Activer les bulles d’aide',
            onPressed: () => onMenu(_Menu.tips),
            emphasize: beginnerTips,
          ),
          if (onPhoneMode != null)
            _BarIcon(
              slot: slot,
              icon: Icons.handshake,
              tooltip: 'Relier les téléphones',
              help: beginnerTips ? tipShare : null,
              onPressed: onPhoneMode,
              emphasize: phoneMode,
            ),
          HelpTip(
            enabled: beginnerTips,
            longPress: false,
            title: tipMenu.title,
            message: tipMenu.message,
            child: PopupMenuButton<_Menu>(
            tooltip: 'Menu',
            padding: EdgeInsets.zero,
            onSelected: onMenu,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _Menu.players,
                child: Text('Joueurs / places'),
              ),
              const PopupMenuItem(
                value: _Menu.first,
                child: Text('Tirage : qui commence'),
              ),
              if (showCardJournal)
                const PopupMenuItem(
                  value: _Menu.cardJournal,
                  child: Text('Noter une carte'),
                ),
              const PopupMenuItem(
                value: _Menu.dayNight,
                child: Text('Jour / nuit'),
              ),
              PopupMenuItem(
                value: _Menu.tips,
                child: Text(
                  beginnerTips
                      ? 'Désactiver les bulles d’aide'
                      : 'Activer les bulles d’aide',
                ),
              ),
              const PopupMenuItem(
                value: _Menu.history,
                child: Text('Historique & journal'),
              ),
              const PopupMenuItem(
                value: _Menu.transfer,
                child: Text('Transférer (QR)'),
              ),
              if (!controller.game.tournament)
                const PopupMenuItem(
                  value: _Menu.search,
                  child: Text('Recherche de carte'),
                ),
              const PopupMenuItem(
                value: _Menu.settings,
                child: Text('Réglages'),
              ),
              for (final layout in layouts)
                PopupMenuItem(
                  value: switch (layout) {
                    _BoardLayout.stack => _Menu.layoutStack,
                    _BoardLayout.split => _Menu.layoutSplit,
                    _BoardLayout.round => _Menu.layoutRound,
                    _BoardLayout.line => _Menu.layoutLine,
                    _ => _Menu.layoutPhone,
                  },
                  child: Text(
                    layout == currentLayout
                        ? '${_layoutName(layout, controller.game.players.length)}  · actuel'
                        : _layoutName(layout, controller.game.players.length),
                  ),
                ),
              const PopupMenuItem(
                value: _Menu.rotate,
                child: Text('Tourner les places'),
              ),
              const PopupMenuItem(
                value: _Menu.shuffle,
                child: Text('Mélanger les places'),
              ),
              if (showTreachery)
                const PopupMenuItem(
                  value: _Menu.treacheryDeal,
                  child: Text('Distribuer rôles Traîtrise'),
                ),
              const PopupMenuItem(
                value: _Menu.recap,
                child: Text('Récap partageable'),
              ),
              const PopupMenuItem(
                value: _Menu.rematch,
                child: Text('Revanche'),
              ),
              const PopupMenuItem(
                value: _Menu.reset,
                child: Text('Remise à zéro'),
              ),
              const PopupMenuItem(value: _Menu.about, child: Text('À propos')),
            ],
            child: SizedBox(
              width: slot,
              height: 48,
              child: const Icon(Icons.more_vert, size: 22),
            ),
          ),
          ),
        ],
      ),
    );
      },
    );
  }
}

Widget buildTableSky(
  BuildContext context, {
  required GameController controller,
  VoidCallback? onExplain,
}) {
  final names = OptionCaption.of(context);
  return LayoutBuilder(
    builder: (context, constraints) {
      final maxH = constraints.maxHeight;
      final tight = maxH.isFinite && maxH < 64;
      final sky = GestureDetector(
        onLongPress: onExplain,
        child: TableSky(
          state: controller.game.dayState,
          names: names && !tight,
          disc: tight ? 24 : 30,
          onSun: () => _toggleSky(controller, DayState.day),
          onMoon: () => _toggleSky(controller, DayState.night),
        ),
      );
      if (!maxH.isFinite) return sky;
      return FittedBox(fit: BoxFit.scaleDown, child: sky);
    },
  );
}

const _skyLane = skyLane;

/// Deux moitiés de même hauteur, le trou du soleil et de la lune au milieu.
/// Le nombre de joueurs change ce qu’il y a au-dessus et en dessous, pas le centre.
Widget centerSplit(List<Widget> seats) {
  final mid = seats.length ~/ 2;
  final above = seats.sublist(0, mid);
  final below = seats.sublist(mid);
  Widget pile(List<Widget> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [for (final item in items) Expanded(child: item)],
    );
  }

  return Column(
    children: [
      Expanded(child: pile(above)),
      const SizedBox(height: _skyLane),
      Expanded(child: pile(below)),
    ],
  );
}

void _toggleSky(GameController controller, DayState next) {
  controller.setDay(
    controller.game.dayState == next ? DayState.unset : next,
  );
}

String _formatClock(Duration d) {
  final negative = d.isNegative;
  final total = d.inSeconds.abs().clamp(0, 99 * 3600);
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  final text = total >= 3600
      ? '${total ~/ 3600}:${((total % 3600) ~/ 60).toString().padLeft(2, '0')}:$s'
      : '$m:$s';
  return negative ? '-$text' : text;
}

class _LiveClocks extends StatefulWidget {
  const _LiveClocks({required this.controller});

  final GameController controller;

  @override
  State<_LiveClocks> createState() => _LiveClocksState();
}

class _LiveClocksState extends State<_LiveClocks> {
  Timer? _tick;
  bool _alerted = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final over = widget.controller.turnOverAlert;
      if (over && !_alerted) {
        _alerted = true;
        final chess = widget.controller.game.timerMode == TimerMode.chess;
        widget.controller.flash(
          chess
              ? 'Banque épuisée — passez la main ?'
              : 'Tour trop long — passez ?',
        );
      }
      if (!over) _alerted = false;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.controller.game;
    final over = widget.controller.turnOverAlert;
    final turn = _formatClock(widget.controller.turnElapsed);
    final match = _formatClock(widget.controller.matchElapsed);
    final limit = game.turnAlertSeconds;
    final active = game.players[game.activeIndex];
    final chess = game.timerMode == TimerMode.chess;
    final bank = widget.controller.activeBankRemaining;
    final label = chess
        ? '${active.name} ${_formatClock(bank)} · tour $turn · $match'
        : over
        ? 'Tour $turn · alerte ${limit}s · partie $match'
        : 'Tour $turn · partie $match';
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: (over || (chess && bank.inSeconds < 60))
            ? loss
            : Colors.white.withValues(alpha: 0.55),
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.slot = 34,
    this.emphasize = false,
    this.help,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double slot;
  final bool emphasize;
  final OptionTip? help;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        minimumSize: Size(slot, slot),
        fixedSize: Size(slot, 48),
      ),
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: emphasize ? 24 : 20,
        color: emphasize && enabled ? accentGold : null,
      ),
    );
    final tip = help;
    if (tip == null) return button;
    return HelpTip(
      title: tip.title,
      message: tip.message,
      longPress: false,
      child: button,
    );
  }
}

class _VictoryBanner extends StatefulWidget {
  const _VictoryBanner({
    required this.text,
    required this.onRematch,
    required this.onZero,
    required this.onRecap,
  });

  final String text;
  final VoidCallback onRematch;
  final VoidCallback onZero;
  final VoidCallback onRecap;

  @override
  State<_VictoryBanner> createState() => _VictoryBannerState();
}

class _VictoryBannerState extends State<_VictoryBanner>
    with TickerProviderStateMixin {
  late final AnimationController _arrive;
  late final AnimationController _glow;
  var _style = FinaleStyle.mythic;
  var _bound = false;
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _arrive = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = FinaleScope.styleOf(context);
    if (_bound && next == _style) return;
    _style = next;
    _bound = true;
    _hold?.cancel();
    _glow.stop();
    _glow.value = 0;
    if (next == FinaleStyle.still ||
        next == FinaleStyle.lean ||
        next == FinaleStyle.carbon ||
        next == FinaleStyle.seal) {
      _arrive.value = 1;
      return;
    }
    if (next == FinaleStyle.mythic) {
      _arrive.value = 0;
      _hold = Timer(const Duration(milliseconds: 120), () {
        if (!mounted || _style != FinaleStyle.mythic) return;
        _arrive.forward();
        _glow.forward();
      });
      return;
    }
    _arrive.duration = next == FinaleStyle.lotus
        ? const Duration(milliseconds: 420)
        : const Duration(milliseconds: 560);
    if (!_arrive.isCompleted) _arrive.forward();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _arrive.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_arrive, _glow]),
      builder: (context, child) {
        final glow = _glow.value;
        final arrive = _style == FinaleStyle.mythic
            ? Curves.easeOutBack.transform(_arrive.value)
            : _style == FinaleStyle.lotus
            ? Curves.easeInOutCubic.transform(_arrive.value)
            : Curves.easeOut.transform(_arrive.value);
        final flash = _style == FinaleStyle.mythic
            ? (1 - Curves.easeOut.transform(_arrive.value)) * 0.22
            : 0.0;
        final (Color wash, Color line, List<BoxShadow> shade) = switch (_style) {
          FinaleStyle.mythic => (
            accentGold.withValues(alpha: 0.28 + 0.22 * glow + flash),
            sacreGoldLight.withValues(alpha: 0.55 + 0.35 * glow),
            [
              BoxShadow(
                color: sacreGoldDeep.withValues(alpha: 0.35 + 0.2 * glow),
                blurRadius: 16,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          FinaleStyle.lotus => (
            epitaphWarm.withValues(alpha: 0.08),
            epitaphWarm.withValues(alpha: 0.7),
            const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          FinaleStyle.carbon => (
            chiselEdge.withValues(alpha: 0.06),
            chiselEdge.withValues(alpha: 0.7),
            const <BoxShadow>[],
          ),
          _ => (
            accentGold.withValues(alpha: 0.08),
            accentGold.withValues(alpha: 0.45),
            const <BoxShadow>[],
          ),
        };
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Color.alphaBlend(wash, surface),
            border: Border(bottom: BorderSide(color: line, width: 1.5)),
            boxShadow: shade,
          ),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Stack(
            children: [
              if (_style == FinaleStyle.mythic)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: VictorySweepPainter(travel: _glow.value),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Transform.scale(
                    scale: _style == FinaleStyle.mythic
                        ? 1 + (1 - arrive) * 0.16
                        : 1,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                      widget.text,
                      textAlign: TextAlign.center,
                      softWrap: false,
                      style: switch (_style) {
                        FinaleStyle.mythic => const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          height: 1.1,
                          letterSpacing: 0.6,
                          color: sacreGoldLight,
                          shadows: [
                            Shadow(color: sacreGoldDeep, offset: Offset(0, 2)),
                            Shadow(color: sacreGoldLight, blurRadius: 8),
                          ],
                        ),
                        FinaleStyle.lotus => const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 22,
                          height: 1.1,
                          letterSpacing: 0.2,
                          color: epitaphPaper,
                          shadows: [
                            Shadow(
                              color: Color(0xCC000000),
                              offset: Offset(0, 1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        FinaleStyle.carbon => const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          height: 1.1,
                          letterSpacing: 1.1,
                          color: chiselSteel,
                          shadows: [
                            Shadow(color: Color(0xFF000000), offset: Offset(0, 1)),
                          ],
                        ),
                        _ => const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          height: 1.1,
                          color: Color(0xFFFFF6E8),
                        ),
                      },
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  child!,
                ],
              ),
            ],
          ),
        );
      },
      child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: widget.onRecap,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Récap'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: widget.onRematch,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Revanche'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: widget.onZero,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('À zéro'),
                  ),
                ),
              ),
            ],
      ),
    );
  }
}

class _TurnTimerBar extends StatefulWidget {
  const _TurnTimerBar({required this.controller});

  final GameController controller;

  @override
  State<_TurnTimerBar> createState() => _TurnTimerBarState();
}

class _TurnTimerBarState extends State<_TurnTimerBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.controller.game;
    if (game.timerMode == TimerMode.chess) {
      final active = game.players[game.activeIndex];
      final bank = widget.controller.activeBankRemaining;
      final bankSec = bank.inSeconds;
      final total = game.chessBankSeconds.clamp(1, 6 * 3600);
      final remaining = (bankSec / total).clamp(0.0, 1.0);
      final low = bankSec < 60;
      final empty = widget.controller.turnOverAlert;
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: remaining,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: empty || low
                    ? dangerCrit
                    : (remaining < 0.25 ? dangerWarn : accent),
              ),
            ),
            const SizedBox(height: 2),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final player in game.players)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        '${player.name} ${_formatClock(player.id == active.id ? bank : Duration(milliseconds: player.clockBankMs))}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: player.id == active.id
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: player.id == active.id
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (empty)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  'Banque épuisée — le dépassement reste compté',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: dangerCrit,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    final limit = game.turnAlertSeconds;
    if (limit <= 0) return const SizedBox.shrink();
    final elapsed = widget.controller.turnElapsed.inSeconds.clamp(0, limit * 2);
    final progress = (elapsed / limit).clamp(0.0, 1.0);
    final over = widget.controller.turnOverAlert;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: over
                  ? dangerCrit
                  : (progress > 0.75 ? dangerWarn : accent),
            ),
          ),
          if (over)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Tour dépassé — passez la main ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: dangerCrit,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _ExtraKind { plane, scheme, bounty }

/// Plans / schémas / primes : chips repliables pour garder le pad de vie grand.
class _TableExtras extends StatefulWidget {
  const _TableExtras({required this.controller, required this.showTips});

  final GameController controller;
  final bool showTips;

  @override
  State<_TableExtras> createState() => _TableExtrasState();
}

class _TableExtrasState extends State<_TableExtras> {
  _ExtraKind? _open;

  void _toggle(_ExtraKind kind) {
    setState(() => _open = _open == kind ? null : kind);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.controller.game;
    final hasPlane = game.planechase;
    final hasScheme = game.archenemy;
    final hasBounty = game.bounty;
    if (!hasPlane && !hasScheme && !hasBounty) {
      return const SizedBox.shrink();
    }

    // Si le mode actif disparaît, refermer le panneau.
    final open = _open;
    final effectiveOpen = switch (open) {
      _ExtraKind.plane when !hasPlane => null,
      _ExtraKind.scheme when !hasScheme => null,
      _ExtraKind.bounty when !hasBounty => null,
      _ => open,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (hasPlane)
                  HelpTip(
                    enabled: widget.showTips,
                    title: tipPlane.title,
                    message: tipPlane.message,
                    child: _ExtraChip(
                    selected: effectiveOpen == _ExtraKind.plane,
                    icon: Icons.public,
                    color: const Color(0xFF7EB6FF),
                    label: game.currentPlane,
                    onTap: () => _toggle(_ExtraKind.plane),
                  ),
                  ),
                if (hasScheme) ...[
                  if (hasPlane) const SizedBox(width: 6),
                  HelpTip(
                    enabled: widget.showTips,
                    title: tipScheme.title,
                    message: tipScheme.message,
                    child: _ExtraChip(
                    selected: effectiveOpen == _ExtraKind.scheme,
                    icon: Icons.whatshot,
                    color: const Color(0xFFFF7A6E),
                    label: game.currentScheme,
                    onTap: () => _toggle(_ExtraKind.scheme),
                  ),
                  ),
                ],
                if (hasBounty) ...[
                  if (hasPlane || hasScheme) const SizedBox(width: 6),
                  HelpTip(
                    enabled: widget.showTips,
                    title: tipBounty.title,
                    message: tipBounty.message,
                    child: _ExtraChip(
                    selected: effectiveOpen == _ExtraKind.bounty,
                    icon: Icons.military_tech,
                    color: accentGold,
                    label: 'Prime ${game.bountyLevel + 1}',
                    onTap: () => _toggle(_ExtraKind.bounty),
                  ),
                  ),
                ],
              ],
            ),
          ),
          if (effectiveOpen != null) ...[
            const SizedBox(height: 4),
            switch (effectiveOpen) {
              _ExtraKind.plane => _PlanePanel(controller: widget.controller),
              _ExtraKind.scheme => _SchemePanel(controller: widget.controller),
              _ExtraKind.bounty => _BountyPanel(controller: widget.controller),
            },
          ],
        ],
      ),
    );
  }
}

class _ExtraChip extends StatelessWidget {
  const _ExtraChip({
    required this.selected,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? color.withValues(alpha: 0.28)
          : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                selected ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanePanel extends StatelessWidget {
  const _PlanePanel({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    return Material(
      color: const Color(0xFF1A2434),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(game.currentPlane),
                      content: Text(game.currentPlaneChaos),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.currentPlane,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      game.currentPlaneChaos,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: controller.rollPlanarDie,
              child: Text('Dé ${game.planarRolls}'),
            ),
            TextButton(
              onPressed: controller.planeswalk,
              child: Text(game.currentIsPhenomenon ? 'Résoudre' : 'Marcher'),
            ),
            TextButton(
              onPressed: () => controller.flash(game.currentPlaneChaos),
              child: const Text('Chaos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchemePanel extends StatelessWidget {
  const _SchemePanel({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final villain = game.archenemyId == null
        ? 'Archennemi'
        : game.playerById(game.archenemyId!).name;
    return Material(
      color: const Color(0xFF2A1A22),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(game.currentScheme),
                      content: Text('$villain\n\n${game.currentSchemeEffect}'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$villain · ${game.currentScheme}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      game.currentSchemeEffect,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: controller.nextScheme,
              child: const Text('Suivant'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BountyPanel extends StatelessWidget {
  const _BountyPanel({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final active = game.players[game.activeIndex];
    final card = game.bountyFor(active);
    return Material(
      color: const Color(0xFF2A2418),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${active.name} · ${card.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    card.reward,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                final active = game.players[game.activeIndex];
                controller.claimBounty(active.id);
              },
              child: const Text('Réclamer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListTable extends StatelessWidget {
  const _ListTable({
    required this.controller,
    required this.haptic,
    required this.showTips,
    this.focusMode = false,
    this.focusPlayerId,
    this.onFocusPlayer,
  });

  final GameController controller;
  final bool haptic;
  final bool showTips;
  final bool focusMode;
  final String? focusPlayerId;
  final ValueChanged<String>? onFocusPlayer;

  @override
  Widget build(BuildContext context) {
    final players = controller.game.players;
    if (focusMode && players.isNotEmpty) {
      final focusId = focusPlayerId ?? players[controller.game.activeIndex].id;
      final focused = players.firstWhere(
        (p) => p.id == focusId,
        orElse: () => players[controller.game.activeIndex],
      );
      return Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: players.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final player = players[index];
                final selected = player.id == focused.id;
                final isTurn = index == controller.game.activeIndex;
                return ActionChip(
                  avatar: CircleAvatar(
                    backgroundColor: playerColor(player.color),
                    radius: 10,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  label: Text(
                    '${player.name} · ${player.life}${isTurn ? ' · tour' : ''}',
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                  onPressed: () => onFocusPlayer?.call(player.id),
                );
              },
            ),
          ),
          Expanded(child: _seat(focused.id)),
        ],
      );
    }
    return centerSplit([
      for (final player in players) _seat(player.id),
    ]);
  }

  Widget _seat(String id) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: PlayerPanel(
        controller: controller,
        playerId: id,
        haptic: haptic,
        showTips: showTips,
      ),
    );
  }
}

class _HorizontalBands extends StatelessWidget {
  const _HorizontalBands({
    required this.plan,
    required this.controller,
    required this.haptic,
    required this.showTips,
  });

  final SeatingPlan plan;
  final GameController controller;
  final bool haptic;
  final bool showTips;

  @override
  Widget build(BuildContext context) {
    final seats = <(int, int)>[
      for (final index in plan.north) (index, 2),
      for (final index in plan.south) (index, 0),
    ];
    return centerSplit([
      for (final seat in seats) _band(seat.$1, seat.$2),
    ]);
  }

  Widget _band(int index, int turns) {
    final players = controller.game.players;
    return _RotatedSeat(
      quarterTurns: turns,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: PlayerPanel(
          controller: controller,
          playerId: players[index].id,
          haptic: haptic,
          showTips: showTips,
          band: true,
        ),
      ),
    );
  }
}

class _SplitQuarters extends StatelessWidget {
  const _SplitQuarters({
    required this.shift,
    required this.controller,
    required this.haptic,
    required this.showTips,
  });

  final int shift;
  final GameController controller;
  final bool haptic;
  final bool showTips;

  @override
  Widget build(BuildContext context) {
    final players = controller.game.players;
    Widget cell(int slot, int turns) {
      final index = (slot + shift) % players.length;
      return _RotatedSeat(
        quarterTurns: turns,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: PlayerPanel(
            controller: controller,
            playerId: players[index].id,
            haptic: haptic,
            showTips: showTips,
            band: true,
          ),
        ),
      );
    }

    // Sens des aiguilles d’une montre, comme le tour en Magic :
    // haut gauche, haut droite, bas droite, bas gauche.
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: cell(0, 2)),
              Expanded(child: cell(1, 2)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: cell(3, 0)),
              Expanded(child: cell(2, 0)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Trois joueurs qui se font face : un en haut, deux collés en bas.
class _FacingThree extends StatelessWidget {
  const _FacingThree({
    required this.shift,
    required this.controller,
    required this.haptic,
    required this.showTips,
  });

  final int shift;
  final GameController controller;
  final bool haptic;
  final bool showTips;

  @override
  Widget build(BuildContext context) {
    final plan = phonePlan(3).oriented(shift, 3);
    return Column(
      children: [
        Expanded(
          child: _seat(
            plan.north.first,
            2,
            const EdgeInsets.fromLTRB(2, 2, 2, 0),
          ),
        ),
        const SizedBox(height: _skyLane),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _seat(
                  plan.south[0],
                  0,
                  const EdgeInsets.fromLTRB(2, 0, 0, 2),
                ),
              ),
              Expanded(
                child: _seat(
                  plan.south[1],
                  0,
                  const EdgeInsets.fromLTRB(0, 0, 2, 2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seat(int index, int turns, EdgeInsets padding) {
    final players = controller.game.players;
    return _RotatedSeat(
      quarterTurns: turns,
      child: Padding(
        padding: padding,
        child: PlayerPanel(
          controller: controller,
          playerId: players[index].id,
          haptic: haptic,
          showTips: showTips,
          band: true,
        ),
      ),
    );
  }
}

/// Trois places dans le même sens : colonne si l’écran est haut, ligne s’il est large.
class _StraightThree extends StatelessWidget {
  const _StraightThree({
    required this.shift,
    required this.controller,
    required this.haptic,
    required this.showTips,
  });

  final int shift;
  final GameController controller;
  final bool haptic;
  final bool showTips;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final across = constraints.maxWidth >= constraints.maxHeight;
        final seats = [
          for (var slot = 0; slot < 3; slot++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _seat(slot, across, constraints),
              ),
            ),
        ];
        return across
            ? Row(children: seats)
            : Column(children: seats);
      },
    );
  }

  Widget _seat(int slot, bool across, BoxConstraints constraints) {
    final players = controller.game.players;
    final seatW = across ? constraints.maxWidth / 3 : constraints.maxWidth;
    final seatH = across ? constraints.maxHeight : constraints.maxHeight / 3;
    final panel = PlayerPanel(
      controller: controller,
      playerId: players[(slot + shift) % 3].id,
      haptic: haptic,
      showTips: showTips,
      band: seatW < 280 || seatH < 300,
    );
    if (slot != 1) return panel;
    return LifeBelowCenter(child: panel);
  }
}

/// Trois places sur un cercle, à 120 degrés, le centre libre pour le jour et la nuit.
class _RoundThree extends StatelessWidget {
  const _RoundThree({
    required this.shift,
    required this.controller,
    required this.haptic,
    required this.showTips,
  });

  final int shift;
  final GameController controller;
  final bool haptic;
  final bool showTips;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardW = constraints.maxWidth;
        final boardH = constraints.maxHeight;
        final box = _roundSeatBox(boardW, boardH);
        final cx = boardW / 2;
        final cy = boardH / 2;
        // Sens horaire : bas, haut gauche, haut droite.
        const sin60 = 0.866025403784;
        const cos60 = 0.5;
        final seats = <(double, double, double)>[
          (0, box.radius, 0),
          (-box.radius * sin60, -box.radius * cos60, 2 * math.pi / 3),
          (box.radius * sin60, -box.radius * cos60, -2 * math.pi / 3),
        ];
        final cosA = math.cos(2 * math.pi / 3).abs();
        final sinA = math.sin(2 * math.pi / 3).abs();
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var slot = 0; slot < seats.length; slot++)
              _placedSeat(
                cx: cx,
                cy: cy,
                dx: seats[slot].$1,
                dy: seats[slot].$2,
                angle: seats[slot].$3,
                seatW: box.width,
                seatH: box.height,
                boundsW: seats[slot].$3 == 0
                    ? box.width
                    : box.width * cosA + box.height * sinA,
                boundsH: seats[slot].$3 == 0
                    ? box.height
                    : box.width * sinA + box.height * cosA,
                playerIndex: (slot + shift) % 3,
              ),
          ],
        );
      },
    );
  }

  Widget _placedSeat({
    required double cx,
    required double cy,
    required double dx,
    required double dy,
    required double angle,
    required double seatW,
    required double seatH,
    required double boundsW,
    required double boundsH,
    required int playerIndex,
  }) {
    final players = controller.game.players;
    final panel = PlayerPanel(
      controller: controller,
      playerId: players[playerIndex].id,
      haptic: haptic,
      showTips: showTips,
      band: true,
    );
    return Positioned(
      left: cx + dx - boundsW / 2,
      top: cy + dy - boundsH / 2,
      width: boundsW,
      height: boundsH,
      child: Center(
        child: SeatReading(
          quarterTurns: 0,
          turnsRadians: angle.abs() < 0.01 ? null : angle,
          child: Transform.rotate(
            angle: angle,
            child: SizedBox(width: seatW, height: seatH, child: panel),
          ),
        ),
      ),
    );
  }
}

class _RoundSeatBox {
  const _RoundSeatBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;
}

_RoundSeatBox _roundSeatBox(double boardW, double boardH) {
  const pad = 10.0;
  const gap = 16.0;
  const sin60 = 0.866025403784;
  const cos60 = 0.5;

  for (var step = 0; step <= 36; step++) {
    final scale = 1 - step * 0.025;
    final sw = math.min(boardW * 0.30, 460.0) * scale;
    final sh = math.min(boardH * 0.34, 280.0) * scale;
    final hole = math.max(84.0, (0.433 * sw + gap) / 1.5 + 4);
    final radius = sh / 2 + hole;
    final boundsW = sw * cos60 + sh * sin60;
    final boundsH = sw * sin60 + sh * cos60;
    final upperBottom = -radius * cos60 + boundsH / 2;
    final onBoard = sw / 2 + pad <= boardW / 2 &&
        radius + sh / 2 + pad <= boardH / 2 &&
        radius * sin60 + boundsW / 2 + pad <= boardW / 2 &&
        radius * cos60 + boundsH / 2 + pad <= boardH / 2;
    final apart = 2 * radius * sin60 >= boundsW + gap;
    final above = upperBottom <= hole - gap;
    if (onBoard && apart && above && sw >= 140 && sh >= 110) {
      return _RoundSeatBox(width: sw, height: sh, radius: radius);
    }
  }
  return _RoundSeatBox(
    width: math.max(140.0, boardW * 0.2),
    height: math.max(110.0, boardH * 0.22),
    radius: math.min(boardH, boardW) * 0.28,
  );
}

class _TwoSides extends StatelessWidget {
  const _TwoSides({
    required this.plan,
    required this.controller,
    required this.haptic,
    required this.showTips,
  });

  final SeatingPlan plan;
  final GameController controller;
  final bool haptic;
  final bool showTips;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: plan.north.isEmpty
              ? const SizedBox.shrink()
              : Row(
                  children: [
                    for (final index in plan.north)
                      Expanded(child: _turned(context, index, 2)),
                  ],
                ),
        ),
        const SizedBox(height: _skyLane),
        Expanded(
          child: plan.south.isEmpty
              ? const SizedBox.shrink()
              : Row(
                  children: [
                    for (final index in plan.south)
                      Expanded(child: _turned(context, index, 0)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _turned(BuildContext context, int index, int turns) {
    final players = controller.game.players;
    final multi = players.length >= 3;
    final face =
        multi ||
            SeatPanes.paneOf(context, players[index].id) == ScorePane.own
        ? null
        : facingSeatIndex(plan, index);
    return _RotatedSeat(
      quarterTurns: turns,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: PlayerPanel(
          controller: controller,
          playerId: players[index].id,
          haptic: haptic,
          lifeTargetId: face == null ? null : players[face].id,
          showTips: showTips,
          band: multi,
        ),
      ),
    );
  }
}

class _FourSides extends StatelessWidget {
  const _FourSides({
    required this.plan,
    required this.controller,
    required this.haptic,
    required this.showTips,
  });

  final SeatingPlan plan;
  final GameController controller;
  final bool haptic;
  final bool showTips;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final single =
            plan.north.length <= 1 &&
            plan.south.length <= 1 &&
            plan.westTopToBottom.length <= 1 &&
            plan.eastTopToBottom.length <= 1;
        if (single) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          var band = math.min(height * 0.28, 150.0);
          var side = math.min(width * 0.24, 220.0);
          if (band * 2 + 88 > height) {
            band = math.max(48.0, (height - 88) / 2);
          }
          if (side * 2 + 72 > width) {
            side = math.max(56.0, (width - 72) / 2);
          }
          return Column(
            children: [
              if (plan.north.isNotEmpty)
                SizedBox(
                  height: band,
                  child: Row(
                    children: [
                      for (final index in plan.north)
                        Expanded(child: _seat(index, 2)),
                    ],
                  ),
                ),
              Expanded(
                child: Row(
                  children: [
                    if (plan.westTopToBottom.isNotEmpty)
                      SizedBox(
                        width: side,
                        child: _sideColumn(plan.westTopToBottom, 1),
                      ),
                    const Expanded(child: SizedBox.expand()),
                    if (plan.eastTopToBottom.isNotEmpty)
                      SizedBox(
                        width: side,
                        child: _sideColumn(plan.eastTopToBottom, 3),
                      ),
                  ],
                ),
              ),
              if (plan.south.isNotEmpty)
                SizedBox(
                  height: band,
                  child: Row(
                    children: [
                      for (final index in plan.south)
                        Expanded(child: _seat(index, 0)),
                    ],
                  ),
                ),
            ],
          );
        }
        // En paysage, la hauteur du milieu devient la largeur du joueur tourné.
        // On la garde assez grande, et on élargit les colonnes pour sa hauteur.
        final tight = constraints.maxHeight < 520;
        final roomForCenter = (constraints.maxWidth - 88) / 2;
        final side = (constraints.maxWidth * 0.3)
            .clamp(72.0, roomForCenter > 72 ? roomForCenter : 72.0)
            .clamp(72.0, 320.0);
        return Column(
          children: [
            if (plan.north.isNotEmpty)
              Expanded(
                flex: tight ? 3 : 5,
                child: Row(
                  children: [
                    for (final index in plan.north)
                      Expanded(child: _seat(index, 2)),
                  ],
                ),
              ),
            Expanded(
              flex: tight ? 10 : 6,
              child: Row(
                children: [
                  if (tight)
                    SizedBox(width: side, child: _sideColumn(plan.westTopToBottom, 1))
                  else
                    Expanded(flex: 5, child: _sideColumn(plan.westTopToBottom, 1)),
                  const Expanded(
                    flex: 3,
                    child: SizedBox.expand(),
                  ),
                  if (tight)
                    SizedBox(width: side, child: _sideColumn(plan.eastTopToBottom, 3))
                  else
                    Expanded(flex: 5, child: _sideColumn(plan.eastTopToBottom, 3)),
                ],
              ),
            ),
            Expanded(
              flex: tight ? 3 : 5,
              child: Row(
                children: [
                  for (final index in plan.south)
                    Expanded(child: _seat(index, 0)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sideColumn(List<int> indexes, int turns) {
    return Column(
      children: [
        for (final index in indexes) Expanded(child: _seat(index, turns)),
      ],
    );
  }

  Widget _seat(int index, int turns) {
    final players = controller.game.players;
    return _RotatedSeat(
      quarterTurns: turns,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: PlayerPanel(
          controller: controller,
          playerId: players[index].id,
          haptic: haptic,
          showTips: showTips,
          band: true,
        ),
      ),
    );
  }
}

class _RotatedSeat extends StatelessWidget {
  const _RotatedSeat({required this.quarterTurns, required this.child});

  final int quarterTurns;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final turns = quarterTurns % 4;
    final body = turns == 0
        ? child
        : RotatedBox(quarterTurns: turns, child: child);
    return SeatReading(quarterTurns: turns, child: body);
  }
}
