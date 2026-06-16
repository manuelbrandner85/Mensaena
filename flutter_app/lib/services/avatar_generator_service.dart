/// Avatar-Generatoren — DiceBear (Identicons + Portraits).
/// Alle kostenlos, kein API-Key. Keine HTTP-Calls hier — nur URL-Bau.
/// Caller verwendet CachedNetworkImage(generated_url).
library;

import 'dart:math' as math;

class AvatarGenerator {
  const AvatarGenerator._();

  /// DiceBear v9 — vielfältige Avatar-Stile, deterministisch aus seed.
  /// https://www.dicebear.com/styles/
  static String diceBear({
    required String seed,
    String style = 'lorelei',
    int size = 256,
    String? backgroundColor,
  }) {
    final params = <String, String>{
      'seed': seed,
      'size': size.toString(),
      'radius': '50',
    };
    if (backgroundColor != null) params['backgroundColor'] = backgroundColor;
    final qs = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return 'https://api.dicebear.com/9.x/$style/png?$qs';
  }

  /// 6 hochwertige DiceBear-Portrait-Stile für rotierende Avatare.
  static const List<String> _portraitStyles = [
    'lorelei',
    'adventurer',
    'notionists',
    'avataaars',
    'micah',
    'personas',
  ];

  /// DiceBear-Avatar mit rotierendem Stil — kostenfrei, kein Key.
  /// [variantIndex] pinnt einen konkreten Stil (für Retry-Logik).
  /// [seed] kann explizit übergeben werden; sonst zufällig.
  static String portraitFor(String userId, {int? variantIndex, int? seed}) {
    final rng = math.Random();
    final idx = variantIndex ?? rng.nextInt(_portraitStyles.length);
    final style = _portraitStyles[idx % _portraitStyles.length];
    final s = seed ?? rng.nextInt(1000000);
    return diceBear(seed: s.toString(), style: style, size: 256);
  }

  /// Anzahl verfügbarer Portrait-Stile (für Retry-Logik im UI).
  static int get portraitStyleCount => _portraitStyles.length;

  /// Default-Identicon für User ohne Foto (deterministisch aus userId).
  static String defaultFor(String userId) => diceBear(seed: userId);
}
