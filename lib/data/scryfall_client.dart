import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mtg_table/data/app_log.dart';
import 'package:mtg_table/data/retry.dart';
import 'package:mtg_table/data/safe_image.dart';
import 'package:mtg_table/data/scryfall_card.dart';

Map<String, dynamic>? _decodeMap(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } on Object catch (error, stack) {
    AppLog.error('scryfall JSON', error, stack);
  }
  return null;
}

String? _trustedArt(String? url) => isTrustedImageUrl(url) ? url : null;

const _headers = {
  'User-Agent': 'TableMTG/1.0',
  'Accept': 'application/json',
};

class HttpRetryException implements Exception {
  HttpRetryException(this.statusCode);
  final int statusCode;

  @override
  String toString() => 'HTTP $statusCode';
}

/// Un seul GET. Les retries (×4) sont gérés par [withFourTries] au-dessus.
Future<http.Response> scryfallGetOnce(Uri uri) async {
  final response = await http.get(uri, headers: _headers);
  if (response.statusCode == 429 || response.statusCode >= 500) {
    throw HttpRetryException(response.statusCode);
  }
  return response;
}

Future<String?> _artOnce(String trimmed) async {
  final uri = Uri.https('api.scryfall.com', '/cards/named', {
    'fuzzy': trimmed,
  });
  final response = await scryfallGetOnce(uri);
  if (response.statusCode == 404) return null;
  if (response.statusCode != 200) {
    throw HttpRetryException(response.statusCode);
  }
  final map = _decodeMap(response.body);
  if (map == null) return null;
  final images = map['image_uris'];
  if (images is Map) {
    return _trustedArt(
      images['art_crop'] as String? ?? images['normal'] as String?,
    );
  }
  final faces = map['card_faces'];
  if (faces is List && faces.isNotEmpty && faces.first is Map) {
    final faceImages = (faces.first as Map)['image_uris'];
    if (faceImages is Map) {
      return _trustedArt(
        faceImages['art_crop'] as String? ?? faceImages['normal'] as String?,
      );
    }
  }
  return null;
}

/// Illustration commandant — 4 essais puis null.
Future<String?> fetchCommanderArtUrl(String name) async {
  final trimmed = name.trim();
  if (trimmed.length < 2) return null;
  return withFourTriesOrNull<String>(() => _artOnce(trimmed));
}

/// Même chose avec message d’erreur pour l’UI.
Future<TryResult<String?>> fetchCommanderArtUrlResult(String name) async {
  final trimmed = name.trim();
  if (trimmed.length < 2) {
    return const TryResult.fail('Nom trop court.');
  }
  return withFourTriesResult(
    () => _artOnce(trimmed),
    failMessage: 'Impossible de joindre Scryfall après 4 essais.',
  );
}

Future<ScryfallCard?> _namedOnce(String trimmed) async {
  final named = Uri.https('api.scryfall.com', '/cards/named', {
    'fuzzy': trimmed,
  });
  final response = await scryfallGetOnce(named);
  if (response.statusCode == 404) return null;
  if (response.statusCode != 200) {
    throw HttpRetryException(response.statusCode);
  }
  final body = _decodeMap(response.body);
  if (body == null) return null;
  var card = ScryfallCard.fromJson(body);

  final id = body['id'] as String?;
  if (id != null) {
    final fr = await _frenchOnce(id);
    if (fr != null) {
      card = ScryfallCard(
        id: card.id,
        name: card.name,
        typeLine: fr.typeLine.isNotEmpty ? fr.typeLine : card.typeLine,
        oracleText: card.oracleText,
        isLand: card.isLand,
        isCreature: card.isCreature,
        manaCost: card.manaCost,
        printedName: fr.printedName ?? fr.name,
        printedText: fr.printedText ?? fr.oracleText,
        artUrl: _trustedArt(fr.artUrl) ?? card.artUrl,
        imageUrl: _trustedArt(fr.imageUrl) ?? card.imageUrl,
        power: card.power,
        toughness: card.toughness,
        priceEur: card.priceEur,
        priceUsd: card.priceUsd,
        legalFormats: card.legalFormats,
      );
    }
  }
  return card;
}

Future<ScryfallCard?> _frenchOnce(String oracleId) async {
  try {
    final uri = Uri.https('api.scryfall.com', '/cards/search', {
      'q': 'oracleid:$oracleId lang:fr',
      'unique': 'prints',
      'order': 'released',
      'dir': 'desc',
    });
    final response = await scryfallGetOnce(uri);
    if (response.statusCode != 200) return null;
    final body = _decodeMap(response.body);
    if (body == null) return null;
    final data = body['data'];
    if (data is! List || data.isEmpty || data.first is! Map) return null;
    return ScryfallCard.fromJson(Map<String, dynamic>.from(data.first as Map));
  } on Object catch (error, stack) {
    AppLog.error('scryfall FR', error, stack);
    return null;
  }
}

Future<ScryfallCard?> fetchScryfallCard(String name) async {
  final trimmed = name.trim();
  if (trimmed.length < 2) return null;
  return withFourTriesOrNull<ScryfallCard>(() => _namedOnce(trimmed));
}

Future<List<ScryfallCard>> _searchOnce(String trimmed, int limit) async {
  final uri = Uri.https('api.scryfall.com', '/cards/search', {
    'q': trimmed,
    'unique': 'cards',
  });
  final response = await scryfallGetOnce(uri);
  if (response.statusCode == 404) return const [];
  if (response.statusCode != 200) {
    throw HttpRetryException(response.statusCode);
  }
  final body = _decodeMap(response.body);
  if (body == null) return const [];
  final data = body['data'];
  if (data is! List) return const [];
  return [
    for (final raw in data.take(limit))
      if (raw is Map) ScryfallCard.fromJson(Map<String, dynamic>.from(raw)),
  ];
}

Future<List<ScryfallCard>> searchScryfallCards(
  String query, {
  int limit = 12,
}) async {
  final trimmed = query.trim();
  if (trimmed.length < 2) return const [];
  final result = await withFourTriesOrNull<List<ScryfallCard>>(
    () => _searchOnce(trimmed, limit),
  );
  return result ?? const [];
}

Future<TryResult<List<ScryfallCard>>> searchScryfallCardsResult(
  String query, {
  int limit = 12,
}) async {
  final trimmed = query.trim();
  if (trimmed.length < 2) {
    return const TryResult.ok([]);
  }
  return withFourTriesResult(
    () => _searchOnce(trimmed, limit),
    failMessage: 'Recherche Scryfall indisponible après 4 essais.',
  );
}
