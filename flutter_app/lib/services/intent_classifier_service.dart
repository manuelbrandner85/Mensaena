/// SKILL: mensaena-architektur
/// Intent-Classifier: erkennt Post-Typ aus Titel/Beschreibung per
/// Keyword-Matching (kein AI-Call noetig). Spiegel der Web-Logik.
class IntentClassifierService {
  const IntentClassifierService._();

  /// Schwellen-Werte:
  /// - 0.45 → Vorschlag (UI: "Vielleicht meintest du X?")
  /// - 0.75 → starker Vorschlag (UI: Auto-Switch mit "Undo"-Hint)
  static const double suggestThreshold = 0.45;
  static const double strongThreshold = 0.75;

  /// Liefert (best-matching post type, confidence 0-1) oder null.
  static ({String type, double confidence})? classify({
    required String title,
    String description = '',
  }) {
    final text = '${title.toLowerCase()} ${description.toLowerCase()}';
    if (text.trim().isEmpty) return null;

    String? best;
    double bestScore = 0;
    for (final entry in _patterns.entries) {
      final score = _scoreText(text, entry.value);
      if (score > bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }
    if (best == null || bestScore < suggestThreshold) return null;
    return (type: best, confidence: bestScore.clamp(0, 1));
  }

  /// Vom Intent abgeleitete Modul-Route.
  static String routeFor(String intent) =>
      _routes[intent] ?? '/dashboard/posts';

  /// 13 Pattern-Gruppen mit jeweils 15-30 deutschen Keywords.
  /// Score = anzahl matches / log-laenge des Texts.
  static double _scoreText(String text, List<String> keywords) {
    var hits = 0;
    for (final kw in keywords) {
      if (text.contains(kw)) hits++;
    }
    if (hits == 0) return 0;
    // Normalisierung: 2 hits in kurzer Text > 5 hits in langem Roman.
    final words = text.split(RegExp(r'\s+')).length.clamp(1, 200);
    return (hits / (1 + (words / 30))).clamp(0, 1);
  }

  /// SKILL: mensaena-features (Post-Typ-Pattern aus Live-App)
  static const Map<String, List<String>> _patterns = {
    'rescue': [
      'retten',
      'rettung',
      'lebensmittel',
      'tafel',
      'wegwerfen',
      'foodsharing',
      'foodsave',
      'mhd',
      'ablauf',
      'abgelaufen',
      'ueberschuss',
      'übrig',
      'spende',
      'spenden',
      'verschenken',
      'gratis abzugeben',
      'müll',
    ],
    'animal': [
      'tier',
      'hund',
      'katze',
      'fundtier',
      'vermisst',
      'gassi',
      'hundesitter',
      'katzenklappe',
      'tierheim',
      'pflegestelle',
      'pferd',
      'meerschwein',
      'kaninchen',
      'voegel',
      'hamster',
      'tierarzt',
      'tierpension',
      'futter',
    ],
    'housing': [
      'wohnung',
      'zimmer',
      'wg',
      'untermiete',
      'zwischenmiete',
      'mitwohnen',
      'untervermieten',
      'einzieher',
      'auszieher',
      'mietangebot',
      'mietgesuch',
      'kaltmiete',
      'warmmiete',
      'wbs',
      'apartment',
      'studentenwohnung',
      'haus zu mieten',
    ],
    'supply': [
      'ernte',
      'apfel',
      'birne',
      'pflaumen',
      'obst',
      'gemuese',
      'gemüse',
      'garten',
      'balkon',
      'kartoffeln',
      'erdbeeren',
      'sauerkirschen',
      'kuerbis',
      'kürbis',
      'walnuss',
      'salat',
      'tomaten',
      'zucchini',
      'gurken',
      'hof',
      'bauernhof',
      'biohof',
    ],
    'mobility': [
      'mitfahr',
      'fahrgemeinschaft',
      'transport',
      'lastenrad',
      'umzug',
      'transporter',
      'auto leihen',
      'fahrrad',
      'fahrt',
      'bahn',
      'mfg',
      'tausch transporter',
      'pkw teilen',
      'carsharing',
    ],
    'sharing': [
      'teilen',
      'leihen',
      'tauschen',
      'verleihen',
      'werkzeug',
      'bohrmaschine',
      'kreissaege',
      'haushaltsgeraet',
      'haushaltsgerät',
      'rasenmäher',
      'rasenmaeher',
      'kaffeemaschine',
      'beamer',
      'leiter',
      'staubsauger',
      'kueche',
      'küche',
    ],
    'community': [
      'gemeinschaft',
      'community',
      'fest',
      'nachbarschaftsfest',
      'treffen',
      'stammtisch',
      'diskussion',
      'umfrage',
      'votum',
      'abstimmung',
      'workshop',
      'lesekreis',
      'spieleabend',
    ],
    'crisis': [
      'notfall',
      'krise',
      'hochwasser',
      'sturm',
      'unwetter',
      'feuer',
      'brand',
      'evakuierung',
      'vermisst',
      'akut',
      'sofort hilfe',
      'medizinisch',
      'arzt',
      'notarzt',
      'lebensgefahr',
    ],
    'help_request': [
      'suche hilfe',
      'brauche hilfe',
      'bitte um hilfe',
      'wer kann',
      'wer hilft',
      'einkaufshilfe',
      'sos',
      'help',
      'unterstuetzung gesucht',
      'unterstützung gesucht',
    ],
    'help_offered': [
      'biete hilfe',
      'kann helfen',
      'gerne unterstuetze',
      'gerne unterstütze',
      'helfer angebot',
      'biete an',
      'kostenlos hilfe',
      'einkaufen erledigen',
    ],
    'skill': [
      'skill',
      'koennen',
      'können',
      'expertise',
      'kenntnis',
      'nachhilfe',
      'workshop',
      'kurs',
      'training',
      'lerne',
      'gibst tipps',
      'erfahrung',
      'qualifikation',
    ],
    'knowledge': [
      'wissen',
      'frage',
      'wiki',
      'info',
      'tutorial',
      'anleitung',
      'tipp',
      'rat',
      'erklaeren',
      'erklären',
      'wie geht',
      'kennt sich aus',
      'know-how',
    ],
    'mental': [
      'einsam',
      'allein',
      'depression',
      'angst',
      'ueberfordert',
      'überfordert',
      'mental',
      'psychisch',
      'kummer',
      'sorgen',
      'krise persoenlich',
      'seele',
      'reden',
      'zuhoeren',
      'zuhören',
      'gespraech',
      'gespräch',
    ],
  };

  static const Map<String, String> _routes = {
    'rescue': '/dashboard/rescuer',
    'animal': '/dashboard/animals',
    'housing': '/dashboard/housing',
    'supply': '/dashboard/supply',
    'mobility': '/dashboard/mobility',
    'sharing': '/dashboard/sharing',
    'community': '/dashboard/groups',
    'crisis': '/dashboard/crisis',
    'help_request': '/dashboard/posts',
    'help_offered': '/dashboard/posts',
    'skill': '/dashboard/skills',
    'knowledge': '/dashboard/knowledge',
    'mental': '/dashboard/mental-support',
  };
}
