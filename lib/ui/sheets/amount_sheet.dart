import 'package:flutter/material.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/widgets/help_tip.dart';
import 'package:mtg_table/ui/widgets/repeat_tap.dart';
import 'package:mtg_table/ui/widgets/table_audio.dart';

Future<void> showAmountSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Listenable listenable,
  required int Function() current,
  required void Function(int delta) onDelta,
  required void Function(int absolute) onSet,
  int? lethalAt,
}) {
  return presentForSeat<void>(
    context,
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height * 0.78;
      return SizedBox(
        height: height,
        child: AmountSheet(
          title: title,
          subtitle: subtitle,
          listenable: listenable,
          current: current,
          onDelta: onDelta,
          onSet: onSet,
          lethalAt: lethalAt,
        ),
      );
    },
  );
}

class AmountSheet extends StatefulWidget {
  const AmountSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.listenable,
    required this.current,
    required this.onDelta,
    required this.onSet,
    this.lethalAt,
  });

  final String title;
  final String subtitle;
  final Listenable listenable;
  final int Function() current;
  final void Function(int delta) onDelta;
  final void Function(int absolute) onSet;
  final int? lethalAt;

  @override
  State<AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<AmountSheet> {
  String _typed = '';

  int? get _amount => int.tryParse(_typed);

  void _push(String digit) {
    setState(() {
      if (_typed.length >= 3) return;
      _typed = '$_typed$digit';
    });
  }

  @override
  Widget build(BuildContext context) {
    final amount = _amount;
    return ListenableBuilder(
      listenable: widget.listenable,
      builder: (context, _) {
        final value = widget.current();
        final lethal = widget.lethalAt != null && value >= widget.lethalAt!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(widget.subtitle),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: lifeStyle(
                  56,
                  lethal ? const Color(0xFFFF8FA3) : Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final delta in const [-10, -5, -1, 1, 5, 10])
                    FilledButton.tonal(
                      onPressed: () {
                        TableAudio.playTouch();
                        widget.onDelta(delta);
                      },
                      child: Text(delta > 0 ? '+$delta' : '$delta'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _typed.isEmpty ? 'Montant' : _typed,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  childAspectRatio: 2.1,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final digit in [
                      '1',
                      '2',
                      '3',
                      '4',
                      '5',
                      '6',
                      '7',
                      '8',
                      '9',
                    ])
                      _PadKey(label: digit, onTap: () => _push(digit)),
                    _PadKey(
                      label: 'C',
                      onTap: () => setState(() => _typed = ''),
                    ),
                    _PadKey(label: '0', onTap: () => _push('0')),
                    _PadKey(
                      label: '⌫',
                      onTap: () => setState(() {
                        if (_typed.isNotEmpty) {
                          _typed = _typed.substring(0, _typed.length - 1);
                        }
                      }),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: amount == null
                          ? null
                          : () {
                              TableAudio.playTouch();
                              widget.onDelta(-amount);
                            },
                      child: Text(
                        amount == null ? 'Retirer' : 'Retirer $amount',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: amount == null
                          ? null
                          : () {
                              TableAudio.playTouch();
                              widget.onDelta(amount);
                            },
                      child: Text(
                        amount == null ? 'Ajouter' : 'Ajouter $amount',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: amount == null ? null : () => widget.onSet(amount),
                  child: Text(amount == null ? 'Définir' : 'Définir à $amount'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepeatTap(
      onTick: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
