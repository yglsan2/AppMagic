import 'package:flutter/material.dart';
import 'package:mtg_table/domain/models.dart';

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
            'Toujours liés : un dégât de combat de commandant retire aussi '
            '1 PV (règles Magic). Corriger ne rend que les PV vraiment retirés.',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Vider le mana en fin de tour'),
          value: _settings.resetManaOnTurn,
          onChanged: (value) =>
              _update(_settings.copyWith(resetManaOnTurn: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Remettre le storm (enchaînement) à zéro en fin de tour',
          ),
          value: _settings.resetStormOnTurn,
          onChanged: (value) =>
              _update(_settings.copyWith(resetStormOnTurn: value)),
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
            'Survol ou appui long sur Monarque, Initiative, poison… '
            'Utile pour les débutants — désactivez quand vous maîtrisez.',
          ),
          value: _settings.beginnerTips,
          onChanged: (value) =>
              _update(_settings.copyWith(beginnerTips: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fil des décomptes de vie'),
          subtitle: const Text(
            'Bandeau des ±PV · toucher pour tout l’historique',
          ),
          value: _settings.showLifeFeed,
          onChanged: (value) =>
              _update(_settings.copyWith(showLifeFeed: value)),
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
          title: const Text('Proposer les handicaps au salon'),
          subtitle: const Text(
            'Mémorise l’option : paliers ou PV libres (−30…+30). '
            'À activer aussi sur la fiche partie.',
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
            ButtonSegment(value: ViewMode.focus, label: Text('Focus')),
          ],
          selected: {_settings.viewMode},
          onSelectionChanged: (selection) =>
              _update(_settings.copyWith(viewMode: selection.first)),
        ),
        const SizedBox(height: 6),
        Text(
          'Focus : un siège en grand (bandeau pour changer sans passer le tour).',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        _StepperTile(
          label: 'Seuil de commandant (officiel : 21)',
          value: _settings.commanderThreshold,
          onChanged: (value) =>
              _update(_settings.copyWith(commanderThreshold: value)),
        ),
        _StepperTile(
          label: 'Seuil de poison',
          value: _settings.poisonThreshold,
          min: 1,
          max: 20,
          onChanged: (value) =>
              _update(_settings.copyWith(poisonThreshold: value)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Chronométrage',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
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
                  label: Text(seconds == 0 ? 'Off' : '${seconds}s'),
                  selected: _settings.turnAlertSeconds == seconds,
                  onSelected: (_) =>
                      _update(_settings.copyWith(turnAlertSeconds: seconds)),
                ),
            ],
          ),
          _StepperTile(
            label: 'Personnaliser (0 = off)',
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
