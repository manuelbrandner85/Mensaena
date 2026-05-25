/// SKILL: mensaena-features + mensaena-design
/// Avatar-Generatoren — DiceBear (Identicons) + Pollinations.ai (AI-Bilder).
/// Beide kostenlos, kein API-Key. Keine HTTP-Calls hier — nur URL-Bau.
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

  /// 8 Prompt-Varianten mit gemischten Gender/Alter/Ethnien um die
  /// Pollinations/Stable-Diffusion Default-Bias zu durchbrechen (die
  /// liefert sonst fast nur junge Frauen).
  static const List<String> _portraitVariants = [
    'friendly middle-aged man portrait photo, warm smile, soft natural light, neighborhood vibe',
    'friendly young woman portrait photo, warm smile, soft natural light, neighborhood vibe',
    'friendly elderly man portrait photo, kind eyes, soft natural light, neighborhood vibe',
    'friendly elderly woman portrait photo, kind eyes, soft natural light, neighborhood vibe',
    'friendly bearded man portrait photo, warm smile, soft natural light, neighborhood vibe',
    'friendly woman with curly hair portrait photo, warm smile, soft natural light, neighborhood vibe',
    'friendly non-binary person portrait photo, warm expression, soft natural light, neighborhood vibe',
    'friendly young man portrait photo, warm smile, soft natural light, neighborhood vibe',
  ];

  /// Lifelike Portrait per Pollinations. Bei jedem Aufruf andere Variante
  /// + frischer Random-Seed, damit Tap-zu-Tap echt unterschiedliche Bilder
  /// rauskommen. Vorher: deterministischer Hash → User sah immer dasselbe
  /// Frauen-Portrait weil der Default-Prompt + SD-Bias keinen Mann erzeugt
  /// hat. Jetzt: rotierende Prompts + neuer Seed = volle Vielfalt.
  static String portraitFor(String userId, {int? variantIndex, int? seed}) {
    final rng = math.Random();
    final idx =
        variantIndex ?? rng.nextInt(_portraitVariants.length);
    final s = seed ?? rng.nextInt(1000000);
    return pollinations(
      prompt: _portraitVariants[idx % _portraitVariants.length],
      seed: s,
      size: 512,
    );
  }

  /// Default-Identicon für User ohne Foto (deterministisch).
  static String defaultFor(String userId) => diceBear(seed: userId);
}
