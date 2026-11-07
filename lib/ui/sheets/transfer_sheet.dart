import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/session_transfer.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> showExportTransferSheet(
  BuildContext context,
  GameController controller,
) {
  final code = encodeSessionTransfer(controller.exportSession());
  if (code == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impossible d’encoder la partie. Réessayez.'),
      ),
    );
    return Future<void>.value();
  }
  final fits = sessionTransferFitsQr(code);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Transférer la partie',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                fits
                    ? 'Scannez ce QR sur l’autre téléphone : Outils, puis Importer. '
                          'Ou copiez le code.'
                    : 'Partie trop riche pour un QR fiable : copiez le code '
                          'et collez-le sur l’autre appareil.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 16),
              if (fits)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: code,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copié')),
                    );
                  } on Object {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copie impossible sur cet appareil.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copier le code'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<Map<String, dynamic>?> showImportTransferSheet(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _ImportSheet(),
  );
}

class _ImportSheet extends StatefulWidget {
  const _ImportSheet();

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.isEmpty) {
        setState(() => _error = 'Presse-papiers vide.');
        return;
      }
      setState(() {
        _controller.text = text.trim();
        _error = null;
      });
    } on Object {
      setState(() => _error = 'Impossible de lire le presse-papiers.');
    }
  }

  void _submit() {
    try {
      final decoded = decodeSessionTransfer(_controller.text);
      if (decoded == null) {
        setState(() => _error = 'Code invalide. Collez un code MTGS1…');
        return;
      }
      Navigator.pop(context, decoded);
    } on Object {
      setState(() => _error = 'Lecture du code impossible.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Importer une partie',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Collez le code généré sur l’autre téléphone (QR ou copie).',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'MTGS1.…',
              labelText: 'Code de partie',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF8FA3))),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _paste,
                  icon: const Icon(Icons.paste),
                  label: const Text('Coller'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Ouvrir'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
