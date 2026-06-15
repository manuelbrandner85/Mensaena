/// SKILL: mensaena-features + mensaena-design
/// Avatar-Generatoren — DiceBear (Identicons + Portraits) + Pollinations.ai (AI-Bilder).
/// Alle kostenlos, kein API-Key. Keine HTTP-Calls hier — nur URL-Bau.
/// Caller verwendet CachedNetworkImage(generated_url).
library;

import 'dart:math' as math;

class AvatarGenerator {
  const AvatarGenerator._();

  /// DiceBear v7 — vielfältige Avatar-Stile, deterministisch aus seed.
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
    return 'https://api.dicebear.com/7.x/$style/png?$qs';
  }

  /// Pollinations.ai — AI-generierte Bilder aus Text-Prompt.
  /// Vollständig kostenlos + kein Key. Caching auf Server-Side.
  /// https://pollinations.ai/
  static String pollinations({
    required String prompt,
    int size = 512,
    int? seed,
  }) {
    final encoded = Uri.encodeComponent(prompt);
    final s = seed ?? prompt.hashCode.abs() % 1000000;
    return 'https://image.pollinations.ai/prompt/$encoded'
        '?width=$size&height=$size&seed=$s&nologo=true';
  }

  /// 8 vielfältige DiceBear-Stile für rotierende Avatare.
  static const List<String> _diceBearStyles = [
    'lorelei',
    'avataaars',
    'personas',
    'notionists',
    'adventurer',
    'micah',
    'open-peeps',
    'big-smile',
  ];

  /// DiceBear-Avatar mit zufälligem Stil + freshmen Seed pro Aufruf.
  /// Tap-zu-Tap immer unterschiedliche Avatare, kostenlos, kein Key.
  static String portraitFor(String userId, {int? variantIndex, int? seed}) {
    final rng = math.Random();
    final idx = variantIndex ?? rng.nextInt(_diceBearStyles.length);
    final style = _diceBearStyles[idx % _diceBearStyles.length];
    final s = seed ?? rng.nextInt(1000000);
    return diceBear(seed: s.toString(), style: style, size: 256);
  }

  /// Default-Identicon für User ohne Foto (deterministisch).
  static String defaultFor(String userId) => diceBear(seed: userId);
}
