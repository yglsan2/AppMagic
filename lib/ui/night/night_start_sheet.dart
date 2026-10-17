import 'package:flutter/material.dart';
import 'package:mtg_table/domain/night_session.dart';
import 'package:mtg_table/domain/night_transfer.dart';

Future<NightSession?> showCreateOrImportNightSheet(BuildContext context) {
  return showModalBottomSheet<NightSession>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _NightStartSheet(),
  );
}

class _NightStartSheet extends StatefulWidget {
  const _NightStartSheet();

  @override
  State<_NightStartSheet> createState() => _NightStartSheetState();
}

class _NightStartSheetState extends State<_NightStartSheet> {
  final _title = TextEditingController();
  final _import = TextEditingController();
  int _pods = 2;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _import.dispose();
    super.dispose();
  }

  void _create() {
    final night = NightSession.create(
      title: _title.text,
      podCount: _pods,
    );
    Navigator.pop(context, night);
  }

  void _importNight() {
    final decoded = decodeNightTransfer(_import.text);
    if (decoded == null) {
      setState(() => _error = 'Code MTGN1 invalide.');
      return;
    }
    Navigator.pop(context, decoded);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Mode soirée',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Plusieurs tables, un classement commun. '
              'Partagez le code pour fusionner les résultats entre téléphones.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nom de la soirée',
                hintText: 'Ex. Commander chez Léa',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Nombre de tables',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final n in const [1, 2, 3, 4])
                  ChoiceChip(
                    label: Text('$n'),
                    selected: _pods == n,
                    onSelected: (_) => setState(() => _pods = n),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _create,
              child: const Text('Ouvrir la soirée'),
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Rejoindre / fusionner',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _import,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Code MTGN1…',
                hintText: 'Collez le code d’une autre table',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: Color(0xFFFF8FA3))),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _importNight,
              child: const Text('Importer la soirée'),
            ),
          ],
        ),
      ),
    );
  }
}
