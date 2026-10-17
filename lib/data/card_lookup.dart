import 'package:mtg_table/data/repository.dart';
import 'package:mtg_table/data/retry.dart';
import 'package:mtg_table/data/scryfall_card.dart';
import 'package:mtg_table/data/scryfall_client.dart';

/// Recherche Scryfall avec cache local (réutilisation, rate-limit doux).
class CardLookup {
  CardLookup(this.repo);

  final AppRepository repo;
  DateTime? _lastCall;

  Future<ScryfallCard?> named(String query) async {
    final result = await namedResult(query);
    return result.value;
  }

  Future<TryResult<ScryfallCard?>> namedResult(String query) async {
    final key = query.trim().toLowerCase();
    if (key.length < 2) {
      return const TryResult.fail('Nom trop court.');
    }

    final cached = await repo.loadCachedCard(key);
    if (cached != null) {
      try {
        return TryResult.ok(ScryfallCard.fromJson(cached));
      } on Object {
        // Cache corrompu : on ignore et on retente le réseau.
      }
    }

    await _throttle();
    // fetchScryfallCard applique déjà la méthode des 4 essais.
    final card = await fetchScryfallCard(query);
    if (card == null) {
      return const TryResult.fail(
        'Carte introuvable ou Scryfall inaccessible après 4 essais.',
      );
    }
    try {
      await repo.cacheCard(key, card.toCacheJson());
      if (card.name.toLowerCase() != key) {
        await repo.cacheCard(card.name, card.toCacheJson());
      }
    } on Object {
      // Cache best-effort : la carte reste utilisable.
    }
    return TryResult.ok(card);
  }

  Future<List<ScryfallCard>> search(String query) async {
    final result = await searchResult(query);
    return result.value ?? const [];
  }

  Future<TryResult<List<ScryfallCard>>> searchResult(String query) async {
    await _throttle();
    return searchScryfallCardsResult(query);
  }

  Future<void> _throttle() async {
    final last = _lastCall;
    if (last != null) {
      final wait =
          const Duration(milliseconds: 100) - DateTime.now().difference(last);
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait);
      }
    }
    _lastCall = DateTime.now();
  }
}
