import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mtg_table/data/app_log.dart';
import 'package:mtg_table/data/retry.dart';
import 'package:mtg_table/data/safe_image.dart';
import 'package:mtg_table/data/scryfall_client.dart';

class CardSearchScreen extends StatefulWidget {
  const CardSearchScreen({super.key});

  @override
  State<CardSearchScreen> createState() => _CardSearchScreenState();
}

class _CardSearchScreenState extends State<CardSearchScreen> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<_CardHit> _hits = const [];
  int _type = 0;
  int _mv = 3;

  static const _types = ['creature', 'instant', 'sorcery'];
  static const _typeLabels = ['Créature', 'Éphémère', 'Rituel'];

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _schedule(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _hits = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await searchScryfallCardsResult(query, limit: 20);
      if (!mounted) return;
      if (!result.ok) {
        setState(() {
          _error = result.errorMessage;
          _loading = false;
          _hits = const [];
        });
        return;
      }
      final cards = result.value ?? const [];
      setState(() {
        _hits = [
          for (final card in cards)
            _CardHit(
              name: card.displayName,
              mana: card.manaCost,
              typeLine: card.typeLine,
              oracle: card.effectText,
              image: card.imageUrl,
              legal: card.legalLabel.isEmpty
                  ? 'Légalité non précisée'
                  : card.legalLabel,
              price: card.priceLabel,
            ),
        ];
        _loading = false;
        _error = cards.isEmpty ? 'Aucune carte.' : null;
      });
    } on Object catch (error, stack) {
      AppLog.error('cardSearch', error, stack);
      if (!mounted) return;
      setState(() {
        _error = 'Pas de réseau, ou Scryfall ne répond pas (4 essais).';
        _loading = false;
      });
    }
  }

  Future<void> _random() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await withFourTries(() async {
        final uri = Uri.https('api.scryfall.com', '/cards/random', {
          'q': 't:${_types[_type]} mv=$_mv',
        });
        final response = await scryfallGetOnce(uri);
        if (response.statusCode != 200) {
          throw HttpRetryException(response.statusCode);
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          throw StateError('réponse invalide');
        }
        return Map<String, dynamic>.from(decoded);
      });
      if (!mounted) return;
      setState(() {
        _hits = [_CardHit.fromJson(body)];
        _loading = false;
      });
    } on Object catch (error, stack) {
      AppLog.error('cardRandom', error, stack);
      if (!mounted) return;
      setState(() {
        _error = 'Pas de réseau, ou Scryfall ne répond pas (4 essais).';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Outils'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Cartes'),
              Tab(text: 'Hasard'),
              Tab(text: 'Mémo'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Nom, type, texte…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _schedule,
                    onSubmitted: _search,
                  ),
                ),
                if (_loading) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _hits.length,
                    itemBuilder: (context, index) =>
                        _CardTile(hit: _hits[index]),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Données de cartes : Scryfall'),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Une carte au hasard, façon Momir ou Jhoira : choisissez un type et un coût de mana.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < _typeLabels.length; i++)
                      ChoiceChip(
                        label: Text(_typeLabels[i]),
                        selected: _type == i,
                        onSelected: (_) => setState(() => _type = i),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Coût de mana'),
                    IconButton(
                      onPressed: _mv > 0 ? () => setState(() => _mv--) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text(
                      '$_mv',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      onPressed: _mv < 15 ? () => setState(() => _mv++) : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                FilledButton(
                  onPressed: _loading ? null : _random,
                  child: const Text('Tirer'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!),
                ],
                for (final hit in _hits) _CardTile(hit: hit),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                _Memo(
                  title: 'Commander',
                  body:
                      'Chacun commence à 40 points de vie. Un joueur perd s’il a reçu 21 points de dégâts ou plus d’un même commandant. Les dégâts de deux commandants différents ne se cumulent pas.',
                ),
                _Memo(
                  title: 'Plusieurs commandants',
                  body:
                      'Partenaire, Partenaire de, Amis pour la vie, un docteur et son compagnon, ou un background : chacun a son compteur de 21 et sa taxe. 15 points d’un commandant et 15 d’un autre ne font pas perdre. La taxe augmente de 2 à chaque lancement depuis la zone de commandement.',
                ),
                _Memo(
                  title: 'Duel Commander',
                  body:
                      '20 points de vie, avec la taxe de commandant, sans les dégâts de commandant. Ce format ne les compte pas. Vous pouvez les réactiver dans Plus d’options, avant de lancer.',
                ),
                _Memo(
                  title: 'Autres départs',
                  body:
                      'Bagarre : 25 points de vie. Briseur de serment : 20, avec un sort signature. Géant à deux têtes : un total pour l’équipe, ici 30. Les dégâts de commandant restent comptés joueur par joueur.',
                ),
                _Memo(
                  title: 'Poison, monarque, initiative',
                  body:
                      'Dix marqueurs poison font perdre la partie. Le monarque pioche une carte au début de son étape de fin. S’il subit des dégâts de combat, l’attaquant devient monarque. L’initiative change de la même façon : elle passe à celui qui inflige les dégâts de combat.',
                ),
                _Memo(
                  title: 'Jour, nuit, dé planaire',
                  body:
                      'La partie passe en nuit si le joueur dont c’est le tour n’a lancé aucun sort. Elle repasse au jour s’il en a lancé au moins deux. Le dé planaire a quatre faces blanches, une planeswalk et une chaos.',
                ),
                _Memo(
                  title: 'Fin de tour',
                  body:
                      'Quand vous passez au joueur suivant, le mana flottant et le storm de celui qui vient de jouer reviennent à zéro. C’est un réglage, désactivable.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Memo extends StatelessWidget {
  const _Memo({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }
}

class _CardHit {
  _CardHit({
    required this.name,
    required this.mana,
    required this.typeLine,
    required this.oracle,
    required this.image,
    required this.legal,
    required this.price,
  });

  final String name;
  final String mana;
  final String typeLine;
  final String oracle;
  final String? image;
  final String legal;
  final String price;

  factory _CardHit.fromJson(Map<String, dynamic> json) {
    final faces = json['card_faces'];
    var oracle = json['oracle_text'] as String? ?? '';
    String? image;
    final uris = json['image_uris'];
    if (uris is Map && uris['normal'] is String) {
      image = uris['normal'] as String;
    }
    if (oracle.isEmpty && faces is List) {
      oracle = [
        for (final face in faces)
          if (face is Map)
            '${face['name'] ?? ''}\n${face['oracle_text'] ?? ''}',
      ].join('\n\n');
    }
    if (image == null &&
        faces is List &&
        faces.isNotEmpty &&
        faces.first is Map) {
      final faceUris = faces.first['image_uris'];
      if (faceUris is Map && faceUris['normal'] is String) {
        image = faceUris['normal'] as String;
      }
    }
    final legalities = json['legalities'];
    final legalBits = <String>[];
    if (legalities is Map) {
      for (final format in const [
        'commander',
        'standard',
        'modern',
        'pioneer',
        'legacy',
        'pauper',
        'brawl',
      ]) {
        final state = legalities[format];
        if (state == 'legal') {
          legalBits.add(format);
        }
        if (state == 'restricted') {
          legalBits.add('$format (restreint)');
        }
      }
    }
    final prices = json['prices'];
    var price = '';
    if (prices is Map) {
      if (prices['eur'] != null) price = '${prices['eur']} €';
      if (prices['usd'] != null) {
        price = price.isEmpty
            ? '${prices['usd']} \$'
            : '$price · ${prices['usd']} \$';
      }
    }
    return _CardHit(
      name: json['name'] as String? ?? 'Carte',
      mana: json['mana_cost'] as String? ?? '',
      typeLine: json['type_line'] as String? ?? '',
      oracle: oracle,
      image: image,
      legal: legalBits.isEmpty ? 'Légalité non précisée' : legalBits.join(', '),
      price: price,
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.hit});

  final _CardHit hit;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        hit.name,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        [
          hit.mana,
          hit.typeLine,
          if (hit.price.isNotEmpty) hit.price,
        ].where((s) => s.trim().isNotEmpty).join(' · '),
      ),
      children: [
        if (hit.image != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SafeNetworkImage(
              url: hit.image,
              height: 280,
              errorBuilder: (_, _, _) => const Text('Image indisponible'),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              [
                hit.oracle,
                if (hit.legal.isNotEmpty) 'Légal : ${hit.legal}',
                if (hit.price.isNotEmpty) 'Prix : ${hit.price}',
              ].join('\n\n'),
            ),
          ),
        ),
      ],
    );
  }
}
