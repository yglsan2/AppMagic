import 'package:flutter/material.dart';
import 'package:mtg_table/domain/play_structure.dart';

class StructureNotes extends StatelessWidget {
  const StructureNotes({super.key, required this.seats});

  final List<SeatStructure> seats;

  @override
  Widget build(BuildContext context) {
    final noted = seats.where((seat) => seat.noted > 0).toList();
    if (noted.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Structure jouée',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 4),
        const Text(
          'Compté sur les cartes notées pendant la soirée, pas sur le deck entier.',
        ),
        for (final seat in noted) ...[
          const SizedBox(height: 8),
          Text(
            '${seat.name} · ${seat.lands} terrains, ${seat.ramp} accélérations, '
            '${seat.draw} pioches, ${seat.creatures} créatures, '
            '${seat.threats} sorts de 6 ou plus',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final note in seat.notes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(note),
            ),
        ],
      ],
    );
  }
}
