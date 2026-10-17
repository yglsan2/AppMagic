import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/recap.dart';

Future<void> showGameRecapSheet(
  BuildContext context,
  GameController controller,
) {
  final text = buildControllerRecap(controller);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Récap de partie',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    text,
                    style: const TextStyle(height: 1.35, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Récap copié — collez-le où vous voulez.')),
                  );
                },
                icon: const Icon(Icons.copy_all),
                label: const Text('Copier pour partager'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
