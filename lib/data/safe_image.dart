import 'package:flutter/material.dart';

/// N’accepte que des HTTPS vers des hôtes Scryfall connus (pas d’URL arbitraire
/// issue d’un JSON / QR importé).
bool isTrustedImageUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.scheme != 'https') return false;
  if (uri.host.isEmpty) return false;
  final host = uri.host.toLowerCase();
  return host == 'api.scryfall.com' ||
      host == 'scryfall.com' ||
      host.endsWith('.scryfall.com') ||
      host.endsWith('.scryfall.io');
}

/// [Image.network] uniquement si l’URL est de confiance.
class SafeNetworkImage extends StatelessWidget {
  const SafeNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final src = url;
    if (!isTrustedImageUrl(src)) {
      return errorBuilder?.call(
            context,
            Exception('URL image non autorisée'),
            null,
          ) ??
          const SizedBox.shrink();
    }
    return Image.network(
      src!,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder ?? (_, _, _) => const SizedBox.shrink(),
    );
  }
}
