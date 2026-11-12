import 'package:mtg_table/data/safe_image.dart';

class ScryfallCard {
  const ScryfallCard({
    required this.name,
    required this.typeLine,
    required this.oracleText,
    required this.isLand,
    required this.isCreature,
    this.id,
    this.manaCost = '',
    this.cmc = 0,
    this.printedName,
    this.printedText,
    this.artUrl,
    this.imageUrl,
    this.power,
    this.toughness,
    this.priceEur,
    this.priceUsd,
    this.legalFormats = const [],
  });

  final String? id;
  final String name;
  final String typeLine;
  final String oracleText;
  final bool isLand;
  final bool isCreature;
  final String manaCost;
  final int cmc;
  final String? printedName;
  final String? printedText;
  final String? artUrl;
  final String? imageUrl;
  final String? power;
  final String? toughness;
  final String? priceEur;
  final String? priceUsd;
  final List<String> legalFormats;

  String get priceLabel {
    final bits = <String>[];
    if (priceEur != null && priceEur!.isNotEmpty) bits.add('$priceEur €');
    if (priceUsd != null && priceUsd!.isNotEmpty) bits.add('$priceUsd \$');
    return bits.join(' · ');
  }

  String get legalLabel =>
      legalFormats.isEmpty ? '' : legalFormats.join(', ');

  /// Texte à parser : français imprimé si dispo, sinon oracle anglais.
  String get effectText {
    final printed = printedText?.trim();
    if (printed != null && printed.isNotEmpty) return printed;
    return oracleText;
  }

  String get displayName {
    final printed = printedName?.trim();
    if (printed != null && printed.isNotEmpty) return printed;
    return name;
  }

  factory ScryfallCard.fromJson(Map<String, dynamic> json) {
    final typeLine = json['type_line'] as String? ?? '';
    var oracle = json['oracle_text'] as String? ?? '';
    String? art;
    String? image;
    String? power = json['power'] as String?;
    String? toughness = json['toughness'] as String?;
    var mana = json['mana_cost'] as String? ?? '';

    final uris = json['image_uris'];
    if (uris is Map) {
      art = uris['art_crop'] as String?;
      image = uris['normal'] as String? ?? uris['large'] as String?;
    }

    final faces = json['card_faces'];
    if (faces is List && faces.isNotEmpty) {
      final parts = <String>[];
      for (final face in faces) {
        if (face is! Map) continue;
        final map = Map<String, dynamic>.from(face);
        final faceOracle = map['oracle_text'] as String? ?? '';
        final faceName = map['name'] as String? ?? '';
        if (faceOracle.isNotEmpty) {
          parts.add(faceName.isEmpty ? faceOracle : '$faceName\n$faceOracle');
        }
        if (art == null) {
          final faceUris = map['image_uris'];
          if (faceUris is Map) {
            art = faceUris['art_crop'] as String?;
            image ??= faceUris['normal'] as String?;
          }
        }
        power ??= map['power'] as String?;
        toughness ??= map['toughness'] as String?;
        if (mana.isEmpty) mana = map['mana_cost'] as String? ?? '';
      }
      if (oracle.isEmpty && parts.isNotEmpty) oracle = parts.join('\n\n');
    }

    final lower = typeLine.toLowerCase();
    final prices = json['prices'];
    String? eur;
    String? usd;
    if (prices is Map) {
      eur = prices['eur']?.toString();
      usd = prices['usd']?.toString();
    }
    final legalities = json['legalities'];
    final legal = <String>[];
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
        if (state == 'legal') legal.add(format);
        if (state == 'restricted') legal.add('$format (restreint)');
      }
    }
    return ScryfallCard(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Carte',
      typeLine: typeLine,
      oracleText: oracle,
      isLand: lower.contains('land') || lower.contains('terrain'),
      isCreature: lower.contains('creature') || lower.contains('créature'),
      manaCost: mana,
      cmc: (json['cmc'] as num?)?.round() ?? 0,
      printedName: json['printed_name'] as String?,
      printedText: json['printed_text'] as String?,
      artUrl: isTrustedImageUrl(art) ? art : null,
      imageUrl: isTrustedImageUrl(image) ? image : null,
      power: power,
      toughness: toughness,
      priceEur: eur,
      priceUsd: usd,
      legalFormats: legal,
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'name': name,
    'type_line': typeLine,
    'oracle_text': oracleText,
    'mana_cost': manaCost,
    'printed_name': printedName,
    'printed_text': printedText,
    'image_uris': {
      if (artUrl != null) 'art_crop': artUrl,
      if (imageUrl != null) 'normal': imageUrl,
    },
    'power': power,
    'toughness': toughness,
    'prices': {
      if (priceEur != null) 'eur': priceEur,
      if (priceUsd != null) 'usd': priceUsd,
    },
    'legalities': {
      for (final format in legalFormats)
        if (!format.contains('restreint')) format: 'legal',
    },
  };
}
