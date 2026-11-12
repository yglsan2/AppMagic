import 'package:flutter/material.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/ui/widgets/finale_fx.dart';
import 'package:mtg_table/ui/widgets/help_tip.dart';

Future<void> showSettingsSheet(
  BuildContext context, {
  required AppSettings settings,
  required ValueChanged<AppSettings> onChanged,
  required CastTone? cast,
  required ValueChanged<CastTone> onCast,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: SettingsSheet(
          settings: settings,
          onChanged: onChanged,
          cast: cast,
          onCast: onCast,
        ),
      );
    },
  );
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.cast,
    required this.onCast,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  final CastTone? cast;
  final ValueChanged<CastTone> onCast;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late AppSettings _settings = widget.settings;
  late CastTone? _cast = widget.cast;
  late final TextEditingController _lifeLine = TextEditingController(
    text: _shownLife(widget.settings),
  );
  late final TextEditingController _poisonLine = TextEditingController(
    text: widget.settings.epitaphPoison,
  );
  late final TextEditingController _commanderLine = TextEditingController(
    text: widget.settings.epitaphCommander,
  );
  late final TextEditingController _leaveLine = TextEditingController(
    text: widget.settings.epitaphLeave,
  );
  late final TextEditingController _winLine = TextEditingController(
    text: widget.settings.epitaphWin,
  );

  static String _shownLife(AppSettings settings) {
    if (settings.epitaphLife.isNotEmpty) return settings.epitaphLife;
    if (settings.saltLines.isEmpty) return '';
    return settings.saltLines.first;
  }

  @override
  void dispose() {
    _lifeLine.dispose();
    _poisonLine.dispose();
    _commanderLine.dispose();
    _leaveLine.dispose();
    _winLine.dispose();
    super.dispose();
  }

  void _update(AppSettings next) {
    setState(() => _settings = next);
    widget.onChanged(next);
  }

  Widget _epitaphField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        onChanged: (value) {
          final line = value.trim();
          onChanged(line.length > 90 ? line.substring(0, 90) : line);
        },
      ),
    );
  }

  Widget _help(String title, String message, Widget child) {
    return HelpTip(
      enabled: _settings.beginnerTips,
      showIcon: _settings.beginnerTips,
      title: title,
      message: message,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const Text(
          'Réglages',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Dégâts de commandant et vie'),
          subtitle: Text(
            'Un point de dégâts de combat d’un commandant retire aussi '
            '1 point de vie. Si vous corrigez, seuls les points vraiment '
            'retirés reviennent.',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sans fin de tour'),
          subtitle: const Text(
            'Le bouton disparaît. Un retrait de points met en évidence '
            'le compte de celui qui les perd.',
          ),
          value: _settings.noEndTurn,
          onChanged: (value) =>
              _update(_settings.copyWith(noEndTurn: value)),
        ),
        _help(
          'Mana en fin de tour',
          'Le mana flottant disparaît à l’étape de nettoyage. Activé, '
              'Fin de tour remet à zéro le mana du joueur qui vient de jouer.',
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vider le mana en fin de tour'),
            value: _settings.resetManaOnTurn,
            onChanged: (value) =>
                _update(_settings.copyWith(resetManaOnTurn: value)),
          ),
        ),
        _help(
          'Tempête',
          'Le compteur de tempête de chaque joueur note ses sorts ce tour-ci. '
              'Activé, il revient à zéro quand ce joueur termine son tour.',
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Remettre la tempête à zéro en fin de tour',
            ),
            value: _settings.resetStormOnTurn,
            onChanged: (value) =>
                _update(_settings.copyWith(resetStormOnTurn: value)),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tous les sons'),
          value: _settings.sounds,
          onChanged: (value) => _update(
            _settings.copyWith(
              sounds: value,
              effectSounds: value,
              touchSounds: value,
            ),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Bruitages'),
          subtitle: const Text('Coups, sorts, défaite et victoire'),
          value: _settings.sounds && _settings.effectSounds,
          onChanged: (value) => _update(
            _settings.copyWith(
              effectSounds: value,
              sounds: value || _settings.touchSounds,
            ),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Touches et glissements'),
          value: _settings.sounds && _settings.touchSounds,
          onChanged: (value) => _update(
            _settings.copyWith(
              touchSounds: value,
              sounds: value || _settings.effectSounds,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Animations',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 4),
        for (final choice in CastTone.values)
          ListTile(
            contentPadding: EdgeInsets.zero,
            selected: _cast == choice,
            title: Text(
              _cast == choice
                  ? '${castToneLabel(choice)}  · actuel'
                  : castToneLabel(choice),
            ),
            subtitle: Text(castToneHint(choice)),
            onTap: () {
              setState(() => _cast = choice);
              widget.onCast(choice);
            },
          ),
        if (_settings.finaleStyle == FinaleStyle.lotus) ...[
          const SizedBox(height: 8),
          const Text(
            '{nom}, {vainqueur}, {perte} et {cause} se remplissent tout seuls.',
          ),
          const SizedBox(height: 8),
          _epitaphField(
            controller: _lifeLine,
            label: 'Phrase de vie',
            onChanged: (value) => _update(
              _settings.copyWith(epitaphLife: value, saltLines: const []),
            ),
          ),
          _epitaphField(
            controller: _poisonLine,
            label: 'Phrase de poison',
            onChanged: (value) =>
                _update(_settings.copyWith(epitaphPoison: value)),
          ),
          _epitaphField(
            controller: _commanderLine,
            label: 'Phrase de commandant',
            onChanged: (value) =>
                _update(_settings.copyWith(epitaphCommander: value)),
          ),
          _epitaphField(
            controller: _leaveLine,
            label: 'Phrase de départ',
            onChanged: (value) =>
                _update(_settings.copyWith(epitaphLeave: value)),
          ),
          _epitaphField(
            controller: _winLine,
            label: 'Phrase du vainqueur',
            onChanged: (value) => _update(_settings.copyWith(epitaphWin: value)),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Vibrations'),
          value: _settings.haptic,
          onChanged: (value) => _update(_settings.copyWith(haptic: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Bulles d’aide'),
          subtitle: const Text(
            'Éteintes, la table reste nette. Allumées, un maintien ou le i '
            'explique chaque option : vies, commandants, poison, monarque, '
            'mana, et le reste. Le bouton ? en haut de la table fait pareil.',
          ),
          value: _settings.beginnerTips,
          onChanged: (value) =>
              _update(_settings.copyWith(beginnerTips: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fil des décomptes de vie'),
          subtitle: const Text(
            'Bandeau des derniers points. Touchez-le pour tout l’historique.',
          ),
          value: _settings.showLifeFeed,
          onChanged: (value) =>
              _update(_settings.copyWith(showLifeFeed: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mémoire des commandants'),
          subtitle: const Text(
            'Garde sur cet appareil chaque coup de commandant. '
            'Touchez un commandant reçu pour voir les points pris '
            'et ce qu’il reste avant la défaite.',
          ),
          value: _settings.rememberCommanderLog,
          onChanged: (value) =>
              _update(_settings.copyWith(rememberCommanderLog: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Journal de cartes (Scryfall)'),
          subtitle: const Text(
            'Enregistrer une carte / terrain, suggestions d’effets, '
            'confirmation avant d’appliquer les PV',
          ),
          value: _settings.cardJournalAssist,
          onChanged: (value) =>
              _update(_settings.copyWith(cardJournalAssist: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Proposer les handicaps avant la partie'),
          subtitle: const Text(
            'Paliers, ou points de vie libres de −30 à +30. '
            'À cocher aussi sur l’écran de départ.',
          ),
          value: _settings.handicapsEnabled,
          onChanged: (value) =>
              _update(_settings.copyWith(handicapsEnabled: value)),
        ),
        const SizedBox(height: 8),
        const Text('Affichage', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SegmentedButton<ViewMode>(
          segments: const [
            ButtonSegment(value: ViewMode.auto, label: Text('Auto')),
            ButtonSegment(value: ViewMode.table, label: Text('Table')),
            ButtonSegment(value: ViewMode.list, label: Text('Liste')),
            ButtonSegment(value: ViewMode.focus, label: Text('Gros plan')),
          ],
          selected: {_settings.viewMode},
          onSelectionChanged: (selection) =>
              _update(_settings.copyWith(viewMode: selection.first)),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Noms sous les logos'),
          subtitle: const Text(
            'Sans nom, les symboles seuls, y compris le soleil et la lune '
            'au centre. Avec le nom, chaque logo est légendé.',
          ),
          value: _settings.optionNames,
          onChanged: (value) =>
              _update(_settings.copyWith(optionNames: value)),
        ),
        const SizedBox(height: 6),
        Text(
          'Gros plan : un joueur en grand. Le bandeau change de joueur sans passer le tour.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        _help(
          'Seuil de commandant',
          'Vingt-et-un points de dégâts de combat du même commandant '
              'éliminent. − et + changent ce seuil pour la partie. '
              'Le Duel Commander ne compte pas cette règle.',
          _StepperTile(
            label: 'Seuil de commandant (officiel : 21)',
            value: _settings.commanderThreshold,
            onChanged: (value) =>
                _update(_settings.copyWith(commanderThreshold: value)),
          ),
        ),
        _help(
          'Seuil de poison',
          'Dix marqueurs poison font perdre. En Géant à deux têtes, '
              'laisser 10 ici applique le seuil officiel de 15. '
              'Un autre nombre est respecté tel quel.',
          _StepperTile(
          label: 'Seuil de poison',
          value: _settings.poisonThreshold,
          min: 1,
          max: 20,
          onChanged: (value) =>
              _update(_settings.copyWith(poisonThreshold: value)),
        ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mode tournoi'),
          subtitle: const Text(
            'Le compteur et l’horloge, si elle est allumée, restent visibles. '
            'Le journal, la recherche de carte et les conseils de deck sont fermés '
            'pendant le match. L’arbitre peut interdire les appareils.',
          ),
          value: _settings.tournament,
          onChanged: (value) => _update(_settings.copyWith(tournament: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Chronomètre'),
          subtitle: Text(
            _settings.timersEnabled
                ? 'Activé. Le temps du tour et de la partie s’affiche.'
                : 'Désactivé. Aucun temps n’est affiché ni imposé.',
          ),
          value: _settings.timersEnabled,
          onChanged: (value) =>
              _update(_settings.copyWith(timersEnabled: value)),
        ),
        if (_settings.timersEnabled) ...[
        const SizedBox(height: 4),
        SegmentedButton<TimerMode>(
          segments: const [
            ButtonSegment(
              value: TimerMode.alert,
              label: Text('Alerte tour'),
            ),
            ButtonSegment(
              value: TimerMode.chess,
              label: Text('Horloge'),
            ),
          ],
          selected: {_settings.timerMode},
          onSelectionChanged: (selection) =>
              _update(_settings.copyWith(timerMode: selection.first)),
        ),
        const SizedBox(height: 8),
        if (_settings.timerMode == TimerMode.alert) ...[
          Text(
            'Barre sous le menu · alerte quand le tour dépasse la limite.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final seconds in const [0, 60, 90, 120, 180, 300])
                ChoiceChip(
                  label: Text(seconds == 0 ? 'Sans alerte' : '${seconds}s'),
                  selected: _settings.turnAlertSeconds == seconds,
                  onSelected: (_) =>
                      _update(_settings.copyWith(turnAlertSeconds: seconds)),
                ),
            ],
          ),
          _StepperTile(
            label: 'Limite en secondes (0 = sans alerte)',
            value: _settings.turnAlertSeconds,
            min: 0,
            max: 600,
            step: 15,
            onChanged: (value) =>
                _update(_settings.copyWith(turnAlertSeconds: value)),
          ),
        ] else ...[
          Text(
            'Chaque joueur a une banque pour ses tours. '
            'Le dépassement reste en négatif. Les secondes bonus reviennent en fin de tour.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final seconds in const [600, 900, 1200, 1800, 2700])
                ChoiceChip(
                  label: Text('${seconds ~/ 60} min'),
                  selected: _settings.chessBankSeconds == seconds,
                  onSelected: (_) =>
                      _update(_settings.copyWith(chessBankSeconds: seconds)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Secondes rendues à chaque fin de tour'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final seconds in const [0, 10, 15, 30])
                ChoiceChip(
                  label: Text(seconds == 0 ? 'Aucune' : '+$seconds s'),
                  selected: _settings.chessBonusSeconds == seconds,
                  onSelected: (_) =>
                      _update(_settings.copyWith(chessBonusSeconds: seconds)),
                ),
            ],
          ),
        ],
        ],
      ],
    );
  }
}

class _StepperTile extends StatelessWidget {
  const _StepperTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.step = 1,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value - step >= min ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove),
        ),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
        IconButton(
          onPressed: value + step <= max ? () => onChanged(value + step) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
