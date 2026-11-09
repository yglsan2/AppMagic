import 'package:flutter/material.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/ui/widgets/help_tip.dart';

Future<void> showSettingsSheet(
  BuildContext context, {
  required AppSettings settings,
  required ValueChanged<AppSettings> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: SettingsSheet(settings: settings, onChanged: onChanged),
      );
    },
  );
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late AppSettings _settings = widget.settings;

  void _update(AppSettings next) {
    setState(() => _settings = next);
    widget.onChanged(next);
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
        const Text(
          'Affichage des points',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choix du téléphone, pour chaque joueur sans préférence à lui. '
          'Mes pertes, les deux (mixte), ou les pertes des adversaires. '
          'L’œil d’un profil, ou un pseudo enregistré plus bas, remplace ce choix.',
        ),
        const SizedBox(height: 8),
        SegmentedButton<ScorePane>(
          expandedInsets: EdgeInsets.zero,
          segments: const [
            ButtonSegment(value: ScorePane.own, label: Text('Mes pertes')),
            ButtonSegment(value: ScorePane.both, label: Text('Les deux')),
            ButtonSegment(
              value: ScorePane.foes,
              label: Text('Adversaires'),
            ),
          ],
          selected: {_settings.scorePane},
          onSelectionChanged: (selection) =>
              _update(_settings.copyWith(scorePane: selection.first)),
        ),
        const SizedBox(height: 16),
        const Text(
          'Préférences par pseudo',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          _settings.namedPanes.isEmpty
              ? 'Aucune préférence enregistrée. Ces joueurs suivent '
                  'l’affichage du téléphone. Sur un profil, l’œil '
                  'à côté de la roue crantée peut en choisir un autre, '
                  'puis « Enregistrer pour ce pseudo ».'
              : 'Au prochain passage de ce pseudo, son affichage remplace '
                  'celui du téléphone. On peut toujours le changer '
                  'pendant la partie.',
        ),
        for (final entry in _settings.namedPanes.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.key),
            subtitle: Text(scorePaneLabel(entry.value)),
            trailing: IconButton(
              tooltip: 'Oublier ${entry.key}',
              onPressed: () => _update(_settings.forgettingPane(entry.key)),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        const SizedBox(height: 8),
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
            'Chaque joueur a une banque. Elle diminue pendant son tour.',
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
