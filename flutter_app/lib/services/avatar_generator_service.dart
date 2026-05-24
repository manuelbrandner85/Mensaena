/// SKILL: mensaena-features + mensaena-design
/// Avatar-Generatoren — DiceBear (Identicons) + Pollinations.ai (AI-Bilder).
/// Beide kostenlos, kein API-Key. Keine HTTP-Calls hier — nur URL-Bau.
/// Caller verwendet CachedNetworkImage(generated_url).
library;

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

  /// Lifelike Portrait per Pollinations (sanfter Default-Prompt).
  static String portraitFor(String userId,
      {String hint = 'friendly neighborhood portrait, soft warm light'}) {
    return pollinations(
      prompt: '$hint, seed-${userId.substring(0, userId.length.clamp(0, 8))}',
      size: 512,
    );
  }

  /// Default-Identicon für User ohne Foto (deterministisch).
  static String defaultFor(String userId) => diceBear(seed: userId);
}
