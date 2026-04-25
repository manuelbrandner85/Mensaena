/**
 * Intent classifier — figures out what kind of post the user is creating
 * based on the title + description text. Used to suggest a better post type
 * when the user is in the wrong category.
 *
 * Strategy:
 *   1) Fast keyword scan (this file, ~free, instant) → high-confidence match
 *   2) Fallback to AI (server route, ~100ms) when keywords are ambiguous
 */

export type IntentType =
  | 'rescue'        // Hilfe / Lebensmittel retten
  | 'animal'        // Tierhilfe
  | 'housing'       // Wohnen
  | 'supply'        // Regionale Versorgung
  | 'mobility'      // Mobilität
  | 'sharing'       // Teilen / Verschenken
  | 'community'     // Gemeinschaft
  | 'crisis'        // Notfall / Krise
  | 'help_request'  // Hilfe gesucht
  | 'help_offered'  // Hilfe angeboten
  | 'skill'         // Skill / Können
  | 'knowledge'     // Wissen / Anleitung
  | 'mental'        // Mentale Unterstützung

export interface IntentMatch {
  type: IntentType
  confidence: number     // 0..1
  matchedKeywords: string[]
}

interface PatternDef {
  type: IntentType
  /** Words that strongly indicate this intent. Lowercase, matched as whole-word substrings. */
  keywords: string[]
  /** Multiplier for confidence (default 1). Use < 1 for weaker signals. */
  weight?: number
}

// Patterns are scored by counting unique keyword hits per intent.
const PATTERNS: PatternDef[] = [
  // ── Tierhilfe ─────────────────────────────────────────────────
  {
    type: 'animal',
    keywords: [
      'katze', 'katzen', 'kater', 'kätzchen',
      'hund', 'hunde', 'welpe', 'welpen',
      'kaninchen', 'hase', 'meerschweinchen', 'hamster',
      'vogel', 'wellensittich', 'papagei',
      'pferd', 'pony', 'esel', 'ziege', 'schaf', 'huhn', 'hennen',
      'tier', 'tiere', 'tierarzt', 'tierpflege',
      'entlaufen', 'gefunden', 'vermisst',
      'pflegestelle', 'tierheim',
      'leine', 'gassi', 'futter', 'streu',
    ],
  },

  // ── Mobilität ─────────────────────────────────────────────────
  {
    type: 'mobility',
    keywords: [
      'fahrrad', 'fahrräder', 'rad', 'bike',
      'auto', 'pkw', 'wagen', 'fahrzeug',
      'mitfahrer', 'mitfahrt', 'mitfahrgelegenheit', 'fahrgemeinschaft',
      'fahre nach', 'fahre zu', 'fahrt nach',
      'lastenrad', 'roller', 'e-bike', 'e-roller',
      'führerschein', 'tanken', 'transporter',
      'bahn', 'zug', 'bus',
      'umzugswagen',
    ],
  },

  // ── Wohnen ────────────────────────────────────────────────────
  {
    type: 'housing',
    keywords: [
      'zimmer', 'wohnung', 'wg', 'unterkunft',
      'mietwohnung', 'miete', 'untermiete',
      'haus', 'apartment', 'studio',
      'notunterkunft', 'pension',
      'umzug', 'einziehen', 'ausziehen',
      'schlafplatz', 'schlafgelegenheit',
    ],
  },

  // ── Versorgung / Lebensmittel ─────────────────────────────────
  {
    type: 'supply',
    keywords: [
      'gemüse', 'obst', 'kartoffeln', 'tomaten', 'äpfel', 'birnen',
      'salat', 'kräuter',
      'gartenernte', 'ernte', 'erntehelfer',
      'hofladen', 'bauernhof', 'imker', 'honig',
      'bio', 'regional', 'saisonal',
      'milch', 'käse', 'eier',
      'beeren', 'pilze', 'nüsse',
    ],
  },

  // ── Krise / Notfall ───────────────────────────────────────────
  {
    type: 'crisis',
    keywords: [
      'notfall', 'notfälle', 'sofort', 'dringend',
      'krise', 'krisen', 'katastrophe',
      'sos', 'lebensgefahr', 'verletzt',
      'feuer', 'brand', 'überflutung', 'hochwasser',
      'rettung', 'krankenhaus',
      'panik', 'hilfe!!!',
    ],
    weight: 1.5, // crisis takes priority
  },

  // ── Mental Health ────────────────────────────────────────────
  {
    type: 'mental',
    keywords: [
      'einsam', 'einsamkeit', 'alleine',
      'depression', 'depressiv', 'traurig', 'trauer',
      'angst', 'überfordert', 'burnout',
      'gespräch', 'reden', 'zuhören', 'zuhörer',
      'seele', 'psychisch', 'mental',
      'panikattacke', 'krise',
    ],
  },

  // ── Skill / Wissen ───────────────────────────────────────────
  {
    type: 'skill',
    keywords: [
      'unterricht', 'nachhilfe', 'lerne', 'lernen',
      'kurs', 'workshop', 'training',
      'gitarre', 'klavier', 'sprache', 'englisch', 'deutsch',
      'computer', 'pc', 'handy', 'smartphone',
      'reparatur', 'reparieren', 'handwerk',
      'beratung',
    ],
  },
  {
    type: 'knowledge',
    keywords: [
      'anleitung', 'tutorial', 'guide', 'erklärung',
      'wissen', 'wie geht', 'tipps für', 'how to',
      'rezept', 'rezepte',
    ],
  },

  // ── Sharing / Verschenken ────────────────────────────────────
  {
    type: 'sharing',
    keywords: [
      'verschenke', 'verschenken', 'gebe ab', 'gebe weg',
      'übrig', 'überschuss', 'rest', 'reste',
      'tausche', 'tauschen', 'tausch',
      'verleihe', 'verleihen', 'leihe',
      'gratis', 'kostenlos', 'umsonst',
      'bücher', 'kindersachen', 'klamotten', 'kleidung', 'spielzeug',
      'werkzeug', 'kindersitz', 'kinderwagen',
      'teilen',
    ],
  },

  // ── Hilfe-Anfrage ────────────────────────────────────────────
  {
    type: 'help_request',
    keywords: [
      'brauche hilfe', 'suche hilfe', 'benötige hilfe',
      'kann mir jemand', 'jemand der',
      'einkaufen für mich', 'einkaufshilfe',
      'umzugshilfe', 'umzug helfen',
      'gartenhilfe', 'rasenmäher',
      'hilfe gesucht',
    ],
    weight: 1.2,
  },

  // ── Hilfe angeboten ──────────────────────────────────────────
  {
    type: 'help_offered',
    keywords: [
      'biete hilfe', 'kann helfen', 'helfe gerne', 'helfe bei',
      'unterstütze', 'übernehme',
      'biete an', 'biete unterstützung',
      'kann ich helfen',
      'einkaufshelfer', 'einkaufsfahrt',
    ],
  },

  // ── Lebensmittel retten ──────────────────────────────────────
  {
    type: 'rescue',
    keywords: [
      'foodsharing', 'lebensmittel retten', 'foodsave',
      'mhd', 'mindesthaltbarkeitsdatum',
      'bäckerei', 'aufstrich', 'brot übrig',
      'restaurant übrig',
    ],
  },

  // ── Community ────────────────────────────────────────────────
  {
    type: 'community',
    keywords: [
      'treffen', 'meeting', 'stammtisch', 'gemeinschaft',
      'verein', 'initiative', 'projekt',
      'abstimmung', 'umfrage',
      'gemeinschaftsgarten', 'nachbarschaftstreff',
    ],
  },
]

const MIN_CONFIDENCE_TO_SUGGEST = 0.45
const STRONG_CONFIDENCE = 0.75

/**
 * Classify a post intent purely from text – no network calls.
 * Returns null if no pattern scored above the threshold.
 */
export function classifyIntent(title: string, description = ''): IntentMatch | null {
  const text = `${title}\n${description}`.toLowerCase()
  if (text.trim().length < 4) return null

  const scores = new Map<IntentType, { score: number; keywords: string[] }>()

  for (const pattern of PATTERNS) {
    let hits = 0
    const matched: string[] = []
    for (const kw of pattern.keywords) {
      // Whole-word boundary check (handles German umlauts; word chars + ä/ö/ü/ß)
      const re = new RegExp(`(^|[^a-zäöüß])${escapeRegex(kw)}([^a-zäöüß]|$)`, 'i')
      if (re.test(text)) {
        hits++
        matched.push(kw)
      }
    }
    if (hits === 0) continue
    // Score: 1 hit = 0.5, 2 hits = 0.75, 3+ = 0.9, weighted
    const raw = hits === 1 ? 0.5 : hits === 2 ? 0.75 : 0.9
    const score = Math.min(1, raw * (pattern.weight ?? 1))
    const prev = scores.get(pattern.type)
    if (!prev || prev.score < score) {
      scores.set(pattern.type, { score, keywords: matched })
    }
  }

  if (scores.size === 0) return null

  const sorted = [...scores.entries()].sort((a, b) => b[1].score - a[1].score)
  const [topType, top] = sorted[0]
  if (top.score < MIN_CONFIDENCE_TO_SUGGEST) return null

  return {
    type: topType,
    confidence: top.score,
    matchedKeywords: top.keywords,
  }
}

/**
 * Returns true if the detected intent is strong enough that we should
 * prompt the user even when ambiguity exists.
 */
export function isStrongMatch(match: IntentMatch | null): boolean {
  return !!match && match.confidence >= STRONG_CONFIDENCE
}

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

// ── German labels for IntentType ────────────────────────────────
export const INTENT_LABELS: Record<IntentType, string> = {
  rescue:       'Lebensmittel retten',
  animal:       'Tierhilfe',
  housing:      'Wohnen',
  supply:       'Regionale Versorgung',
  mobility:     'Mobilität',
  sharing:      'Teilen / Verschenken',
  community:    'Gemeinschaft',
  crisis:       'Notfall / Krise',
  help_request: 'Hilfe gesucht',
  help_offered: 'Hilfe angeboten',
  skill:        'Skill / Können',
  knowledge:    'Wissen / Anleitung',
  mental:       'Mentale Unterstützung',
}

export const INTENT_EMOJI: Record<IntentType, string> = {
  rescue: '🧡', animal: '🐾', housing: '🏡', supply: '🌾', mobility: '🚗',
  sharing: '🔄', community: '🗳️', crisis: '🚨', help_request: '🆘',
  help_offered: '💚', skill: '🎯', knowledge: '📚', mental: '🧠',
}

/**
 * Maps an IntentType to the URL of its dedicated module page.
 * Used by the suggestion banner's "wechseln" action.
 */
export const INTENT_ROUTES: Record<IntentType, string> = {
  rescue:       '/dashboard/rescuer',
  animal:       '/dashboard/animals',
  housing:      '/dashboard/housing',
  supply:       '/dashboard/supply',
  mobility:     '/dashboard/mobility',
  sharing:      '/dashboard/sharing',
  community:    '/dashboard/groups',
  crisis:       '/dashboard/crisis',
  help_request: '/dashboard/posts',
  help_offered: '/dashboard/posts',
  skill:        '/dashboard/skills',
  knowledge:    '/dashboard/knowledge',
  mental:       '/dashboard/mental-support',
}
