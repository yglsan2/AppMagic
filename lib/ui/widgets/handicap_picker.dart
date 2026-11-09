import 'package:flutter/material.dart';
import 'package:mtg_table/domain/handicap.dart';
import 'package:mtg_table/ui/widgets/help_tip.dart';

/// Sélecteur de handicap : paliers + valeur PV libre (−30…+30).
class HandicapPicker extends StatelessWidget {
  const HandicapPicker({
    super.key,
    required this.bracket,
    required this.lifeDelta,
    required this.baseLife,
    required this.onChanged,
    this.compact = false,
    this.tips = false,
  });

  final DeckBracket bracket;
  final int lifeDelta;
  final int baseLife;
  final void Function(DeckBracket bracket, int lifeDelta) onChanged;
  final bool compact;
  final bool tips;

  int get _start => effectiveStartingLife(
    baseLife: baseLife,
    handicapsEnabled: true,
    lifeDelta: lifeDelta,
  );

  void _pickPreset(DeckBracket next) {
    if (next == DeckBracket.custom) {
      onChanged(DeckBracket.custom, lifeDelta);
      return;
    }
    onChanged(next, next.suggestedLifeDelta);
  }

  void _nudge(int step) {
    final next = clampHandicapLife(lifeDelta + step);
    onChanged(bracketMatchingLifeDelta(next), next);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, compact ? 8 : 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Niveau du deck · départ $_start PV',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Choisissez un palier, ou réglez un bonus/malus exact.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final b in DeckBracket.values)
                  HelpTip(
                    enabled: tips,
                    title: b.label,
                    message: b.help,
                    child: FilterChip(
                      label: Text(b.chipLabel(lifeDelta)),
                      selected: bracket == b,
                      onSelected: (_) => _pickPreset(b),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Personnaliser les PV',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _StepBtn(
                  label: '−5',
                  onPressed: lifeDelta > handicapLifeMin
                      ? () => _nudge(-5)
                      : null,
                ),
                _StepBtn(
                  label: '−1',
                  onPressed: lifeDelta > handicapLifeMin
                      ? () => _nudge(-1)
                      : null,
                ),
                Expanded(
                  child: Text(
                    formatLifeDelta(lifeDelta),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                ),
                _StepBtn(
                  label: '+1',
                  onPressed: lifeDelta < handicapLifeMax
                      ? () => _nudge(1)
                      : null,
                ),
                _StepBtn(
                  label: '+5',
                  onPressed: lifeDelta < handicapLifeMax
                      ? () => _nudge(5)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}
