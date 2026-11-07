import 'package:flutter/material.dart';
import 'package:mtg_table/domain/player_profile.dart';
import 'package:mtg_table/theme/app_theme.dart';

Future<PlayerProfile?> showPickProfileSheet(
  BuildContext context,
  List<PlayerProfile> profiles,
) {
  return showModalBottomSheet<PlayerProfile>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Charger un profil',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (profiles.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'Aucun profil enregistré.\n'
                      'À côté d’un nom, touchez l’icône Sauver le profil.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: profiles.length,
                    itemBuilder: (context, index) {
                      final profile = profiles[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: playerColor(profile.color),
                          child: Text(
                            playerInitial(profile.name),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        title: Text(profile.name),
                        subtitle: Text(
                          profile.commanders.isEmpty
                              ? 'Sans commandant'
                              : profile.commanders.join(' · '),
                        ),
                        onTap: () => Navigator.pop(context, profile),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> confirmSaveProfile(
  BuildContext context, {
  required String name,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sauver le profil ?'),
      content: Text(
        'Enregistre « $name » (couleur, commandants, art) pour le recharger plus tard.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sauver'),
        ),
      ],
    ),
  );
  return result == true;
}
