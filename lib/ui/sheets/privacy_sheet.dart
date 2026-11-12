import 'package:flutter/material.dart';
import 'package:mtg_table/data/app_log.dart';

/// Transparence données / RGPD + actions d’effacement (app locale).
Future<void> showPrivacySheet(
  BuildContext context, {
  required Future<void> Function() onWipeAll,
  Future<void> Function()? onClearCacheOnly,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: _PrivacySheet(
          onWipeAll: onWipeAll,
          onClearCacheOnly: onClearCacheOnly,
        ),
      );
    },
  );
}

class _PrivacySheet extends StatelessWidget {
  const _PrivacySheet({
    required this.onWipeAll,
    this.onClearCacheOnly,
  });

  final Future<void> Function() onWipeAll;
  final Future<void> Function()? onClearCacheOnly;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const Text(
          'Vie privée & données (RGPD)',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'LifeStack fonctionne sans compte. '
          'La partie sur un seul téléphone, ou entre téléphones du même lieu, '
          'reste sur les appareils. Le salon en ligne est un choix : '
          'les noms et les scores partent chiffrés, et le code du salon est la clé. '
          'La recherche de carte passe par Scryfall.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        ),
        const SizedBox(height: 16),
        const _Block(
          title: 'Responsable du traitement',
          body:
              'Vous-même, sur votre appareil. Aucun compte n’est créé chez '
              'un éditeur distant pour cette application.',
        ),
        const _Block(
          title: 'Données stockées localement',
          body:
              '• Réglages et partie en cours\n'
              '• Profils joueurs, historique de parties, soirée multi-tables\n'
              '• Cache Scryfall (noms / textes / URLs d’images)\n'
              '• Journal technique d’erreurs (reste sur l’appareil, rien n’est envoyé)',
        ),
        const _Block(
          title: 'Réseau',
          body:
              'Uniquement vers api.scryfall.com (HTTPS) lorsque vous cherchez '
              'une carte ou une illustration. Le salon en ligne, si vous l’ouvrez, '
              'envoie la table chiffrée à un relais (HiveMQ, ou EMQX s’il ne répond pas) '
              'le temps de la relier. Le relais ne reçoit pas le texte de la partie : '
              'le code saisi à la table est la clé. Aucune télémétrie publicitaire.',
        ),
        const _Block(
          title: 'Bases légales (app locale)',
          body:
              'Intérêt légitime / exécution du service que vous demandez '
              '(suivre une partie). Pas de revente de données.',
        ),
        const _Block(
          title: 'Vos droits',
          body:
              'Accès et portabilité : export QR / code MTGS1 et MTGN1, '
              'récaps texte.\n'
              'Effacement : boutons ci-dessous. Les données restent jusqu’à '
              'ce que vous les effaciez, ou que vous désinstalliez l’application.\n'
              'Opposition : n’ouvrez pas le salon en ligne, et n’utilisez pas '
              'la recherche de cartes, si vous ne voulez aucun appel réseau.\n'
              'Pas de profilage, pas de publicité, pas de revente.',
        ),
        const _Block(
          title: 'Accessibilité (RGAA)',
          body:
              'L’interface est en français. Le texte suit la taille choisie '
              'dans le système, dans une limite encore lisible à table. '
              'Le fond est sombre, les chiffres restent clairs, et les '
              'actions principales ont un nom (pas seulement une icône). '
              'LifeStack n’a pas passé d’audit RGAA et ne déclare pas '
              'une conformité officielle.',
        ),
        const _Block(
          title: 'Magic et responsabilité',
          body:
              'LifeStack est écrit par DesertYGL et publié sous la GNU GPL '
              'version 3, sans garantie. Magic: The Gathering, les cartes, '
              'les images et les règles appartiennent à Wizards of the Coast. '
              'Ce compteur n’est pas officiel. DesertYGL n’est pas responsable '
              'd’un score faux, d’une partie, d’un tournoi, d’un réseau, '
              'de Scryfall, des relais du salon, ni de l’usage que vous '
              'en faites.',
        ),
        const SizedBox(height: 12),
        if (onClearCacheOnly != null)
          OutlinedButton.icon(
            onPressed: () async {
              await onClearCacheOnly!();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cartes effacé.')),
              );
            },
            icon: const Icon(Icons.cached_outlined),
            label: const Text('Effacer le cache Scryfall'),
          ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Tout effacer ?'),
                content: const Text(
                  'Supprime parties, profils, soirée, réglages et caches '
                  'sur cet appareil. Irréversible.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Effacer'),
                  ),
                ],
              ),
            );
            if (ok != true) return;
            try {
              await onWipeAll();
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Données locales effacées.')),
              );
            } on Object catch (error, stack) {
              AppLog.error('privacy wipe', error, stack);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Effacement impossible.')),
              );
            }
          },
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('Effacer toutes les données locales'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}
