// Kleine statische Wissensbasis für den Mensaena-Bot.
// Wird vom /api/bot Endpoint als Retrieval-Kontext genutzt: die User-Frage
// wird auf Keyword-Overlap mit jedem Eintrag geprüft, die Top-3-Treffer
// landen als Kontext-Block im System-Prompt. Kein Vektor-Index, keine DB –
// absichtlich simpel, damit wir ohne Runtime-Dependencies auskommen.

export interface KBEntry {
  id: string
  title: string
  keywords: string[]
  content: string
}

export const KNOWLEDGE_BASE: KBEntry[] = [
  {
    id: 'was-ist-mensaena',
    title: 'Was ist Mensaena?',
    keywords: ['mensaena', 'plattform', 'was ist', 'vision', 'ziel', 'mission', 'über'],
    content: 'Mensaena ist eine deutschsprachige Gemeinwohl-Plattform, die Menschen lokal vernetzt. Motto: "Freiheit beginnt im Bewusstsein." Hilfe finden und anbieten, Tiere schützen, Ressourcen teilen – 100% kostenlos, werbefrei und ohne versteckte Kosten.',
  },
  {
    id: 'kostenlos',
    title: 'Kosten & Monetarisierung',
    keywords: ['kostenlos', 'gratis', 'preis', 'bezahlen', 'abo', 'werbung', 'geld', 'monetar'],
    content: 'Mensaena ist zu 100% kostenlos – jetzt und in Zukunft. Es gibt keine Abos, keine Werbung, keine versteckten Gebühren und keinen Verkauf von Nutzerdaten. Das Projekt finanziert sich aus Spenden und Gemeinwohlbeiträgen.',
  },
  {
    id: 'hilfe-erstellen',
    title: 'Hilfe suchen oder anbieten',
    keywords: ['hilfe', 'inserieren', 'anbieten', 'suchen', 'post', 'beitrag', 'erstellen', 'gesucht'],
    content: 'Unter /dashboard/create kannst du einen neuen Beitrag erstellen. Wähle einen Typ (z.B. "Hilfe gesucht", "Hilfe angeboten", "Tier", "Wohnen", "Versorgung"), trage Titel, Beschreibung und Standort ein und klicke auf Veröffentlichen. Andere Nutzer sehen dein Angebot auf der Karte und in den Listen.',
  },
  {
    id: 'chat',
    title: 'Community-Chat & Direktnachrichten',
    keywords: ['chat', 'nachricht', 'dm', 'privat', 'kanal', 'channel', 'sprachnachricht', 'voice'],
    content: 'Unter /dashboard/chat findest du öffentliche Community-Kanäle (nach Thema sortiert) und private Direktnachrichten. Du kannst Texte, Bilder und Sprachnachrichten senden – Sprachnachrichten werden mit einem Klick auf das Mikrofon aufgenommen (bis 3 Minuten). Der Browser fragt einmalig nach Mikrofon-Erlaubnis.',
  },
  {
    id: 'karte',
    title: 'Interaktive Karte',
    keywords: ['karte', 'map', 'standort', 'radius', 'umkreis', 'nahe', 'marker'],
    content: 'Die interaktive Karte unter /dashboard/map zeigt alle aktiven Hilfegesuche und Angebote in deiner Umgebung. Du kannst den Radius von 5 bis 200 km einstellen. Marker erscheinen in Echtzeit, sobald jemand einen neuen Beitrag erstellt. Jede Kategorie hat eine eigene Farbe und ein passendes Emoji in der Legende.',
  },
  {
    id: 'marktplatz',
    title: 'Marktplatz – Kaufen, Verkaufen, Verschenken, Tauschen',
    keywords: ['markt', 'marktplatz', 'verkauf', 'verschenk', 'tausch', 'shop', 'kaufen', 'anzeige'],
    content: 'Unter /dashboard/marketplace kannst du Artikel inserieren – Festpreis, Verhandlungsbasis, Tausch oder zum Verschenken. Pro Anzeige sind bis zu 5 Bilder möglich. Interessenten können direkt reservieren und dich per DM kontaktieren.',
  },
  {
    id: 'tiere',
    title: 'Tierhilfe & Tierrettung',
    keywords: ['tier', 'hund', 'katze', 'pferd', 'rettung', 'vermittlung', 'pfote', 'haustier'],
    content: 'Der Tierbereich unter /dashboard/animals bietet Vermittlung, Pflegestellen-Suche und Rettungsaktionen. Du kannst Tiere in Not melden, Pflegestellen anbieten oder bei Notfällen das Retter-System aktivieren.',
  },
  {
    id: 'krise',
    title: 'Krisensystem & Notfälle',
    keywords: ['krise', 'notfall', 'sos', 'retter', 'hilfe sofort', 'dringend'],
    content: 'Das Krisensystem unter /dashboard/crisis ist für akute Notfälle gedacht. Du kannst eine Krise melden, ein Rettungsnetzwerk in deiner Nähe aktivieren oder selbst Retter werden. Bei akuten Suizidgedanken oder psychischen Notlagen: Telefonseelsorge 0800 111 0 111 (24/7, kostenlos).',
  },
  {
    id: 'versorgung',
    title: 'Regionale Versorgung & Bauernhöfe',
    keywords: ['versorgung', 'bauernhof', 'bio', 'ernte', 'regional', 'lebensmittel', 'landwirt'],
    content: 'Im Versorgungsbereich unter /dashboard/supply findest du regionale Bauernhöfe, Bio-Produkte und Erntehilfe-Angebote. Du kannst auch selbst einen Hof eintragen unter /dashboard/supply/farm/add.',
  },
  {
    id: 'wohnen',
    title: 'Wohnen & Alltag',
    keywords: ['wohnen', 'wohnung', 'unterkunft', 'tausch', 'alltag', 'haus'],
    content: 'Unter /dashboard/housing kannst du Wohnraum anbieten oder suchen, Wohnungstausch organisieren oder Alltagshilfe koordinieren.',
  },
  {
    id: 'mental',
    title: 'Mentale Unterstützung',
    keywords: ['mental', 'psyche', 'stress', 'burnout', 'angst', 'depression', 'gefühl', 'trauma'],
    content: 'Für mentale Unterstützung gibt es /dashboard/mental-support mit Ressourcen, Techniken und Menschen, die zuhören. Du bist nicht allein. Bei akuter Not: Telefonseelsorge 0800 111 0 111.',
  },
  {
    id: 'skills-zeitbank',
    title: 'Skill-Netzwerk & Zeitbank',
    keywords: ['skill', 'zeitbank', 'fähigkeit', 'tauschen', 'stunden', 'handwerk', 'können'],
    content: 'Im Skill-Netzwerk unter /dashboard/skills bietest du Fähigkeiten an oder suchst welche. Die Zeitbank unter /dashboard/timebank erlaubt dir, Stunden gegen Stunden zu tauschen – eine Stunde Gartenhilfe = eine Stunde Nachhilfe.',
  },
  {
    id: 'mobilitaet',
    title: 'Mobilität & Mitfahrgelegenheiten',
    keywords: ['mitfahr', 'mobilität', 'fahrt', 'auto', 'transport', 'fahrgemeinschaft'],
    content: 'Unter /dashboard/mobility kannst du Mitfahrgelegenheiten anbieten oder suchen, Transporte koordinieren oder Autos teilen.',
  },
  {
    id: 'teilen',
    title: 'Teilen & Tauschen',
    keywords: ['teilen', 'tauschen', 'leihen', 'nachhaltig', 'verschenken', 'sharing'],
    content: 'Unter /dashboard/sharing kannst du Werkzeuge, Bücher, Geräte und andere Gegenstände teilen, verleihen oder tauschen – nachhaltig und kostenlos.',
  },
  {
    id: 'datenschutz',
    title: 'Datenschutz & Privatsphäre',
    keywords: ['datenschutz', 'privat', 'daten', 'dsgvo', 'tracking', 'sicherheit'],
    content: 'Mensaena respektiert deine Privatsphäre: Keine Werbenetzwerke, kein Tracking durch Dritte, kein Verkauf von Daten. Deine Beiträge sind öffentlich nur dort sichtbar, wo du es möchtest. Details unter /datenschutz.',
  },
  {
    id: 'profil',
    title: 'Profil & Einstellungen',
    keywords: ['profil', 'einstellung', 'konto', 'benachrichtigung', 'push', 'account'],
    content: 'Dein Profil findest du unter /dashboard/profile, Einstellungen unter /dashboard/settings. Dort kannst du Push-Benachrichtigungen (standardmäßig aktiv), Standort, Radius und Sprache anpassen.',
  },
]

/**
 * Sehr einfache Keyword-basierte Retrieval-Funktion. Normalisiert die Frage,
 * zählt Keyword-Treffer pro KB-Eintrag und gibt die Top-N zurück. Dient als
 * Fallback, wenn kein AI-Binding verfügbar ist (lokal ohne Wrangler, Tests).
 */
export function retrieveKBKeyword(question: string, topN = 3): KBEntry[] {
  const q = question.toLowerCase().replace(/[^a-zäöüß0-9\s]/g, ' ')
  const tokens = q.split(/\s+/).filter(t => t.length > 2)
  if (!tokens.length) return []

  const scored = KNOWLEDGE_BASE.map(entry => {
    let score = 0
    for (const kw of entry.keywords) {
      for (const tok of tokens) {
        if (tok.includes(kw) || kw.includes(tok)) score += 1
      }
    }
    return { entry, score }
  }).filter(s => s.score > 0)

  scored.sort((a, b) => b.score - a.score)
  return scored.slice(0, topN).map(s => s.entry)
}

// Rückwärtskompatibel: alter Name bleibt als Alias erhalten
export const retrieveKB = retrieveKBKeyword

// ── Vector RAG (Workers AI) ──────────────────────────────────────
// Wir generieren die KB-Embeddings einmal pro Worker-Instanz und cachen
// sie in-memory. Bei 16 Einträgen à ~200 Tokens entstehen ~25 ms extra
// beim ersten Request — danach ist der Lookup kostenlos. Kein externer
// Store, kein pgvector, keine Migration.
//
// Modell: `@cf/baai/bge-m3` (multilingual, 1024-dim, Cloudflare-Free-Tier).

const EMBED_MODEL = '@cf/baai/bge-m3'

let kbVectorCache: { id: string; vector: number[] }[] | null = null
let kbVectorPromise: Promise<{ id: string; vector: number[] }[]> | null = null

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function embedText(ai: any, text: string): Promise<number[]> {
  const res = await ai.run(EMBED_MODEL, { text: [text] })
  // Workers AI returns { shape: [n, dim], data: number[][] }
  const vec = res?.data?.[0]
  if (!Array.isArray(vec)) throw new Error('embed: empty vector')
  return vec as number[]
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function ensureKbVectors(ai: any): Promise<{ id: string; vector: number[] }[]> {
  if (kbVectorCache) return kbVectorCache
  if (kbVectorPromise) return kbVectorPromise
  kbVectorPromise = (async () => {
    const out: { id: string; vector: number[] }[] = []
    for (const entry of KNOWLEDGE_BASE) {
      const text = `${entry.title}\n${entry.content}`
      const vector = await embedText(ai, text)
      out.push({ id: entry.id, vector })
    }
    kbVectorCache = out
    return out
  })()
  return kbVectorPromise
}

function cosineSim(a: number[], b: number[]): number {
  let dot = 0
  let na = 0
  let nb = 0
  const len = Math.min(a.length, b.length)
  for (let i = 0; i < len; i++) {
    dot += a[i] * b[i]
    na += a[i] * a[i]
    nb += b[i] * b[i]
  }
  if (na === 0 || nb === 0) return 0
  return dot / (Math.sqrt(na) * Math.sqrt(nb))
}

/**
 * Vektor-basierte Retrieval-Funktion. Bettet die Frage mit bge-m3 ein,
 * berechnet die Cosinus-Ähnlichkeit gegen die gecachten KB-Vektoren und
 * liefert die Top-N. Fällt bei Fehlern auf die Keyword-Variante zurück.
 */
export async function retrieveKBVector(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  ai: any,
  question: string,
  topN = 3,
  minScore = 0.3,
): Promise<KBEntry[]> {
  if (!ai || typeof ai.run !== 'function') return retrieveKBKeyword(question, topN)
  try {
    const [kbVectors, qVector] = await Promise.all([
      ensureKbVectors(ai),
      embedText(ai, question),
    ])
    const scored = kbVectors.map(({ id, vector }) => ({
      id,
      score: cosineSim(qVector, vector),
    }))
    scored.sort((a, b) => b.score - a.score)
    const hits = scored
      .filter(s => s.score >= minScore)
      .slice(0, topN)
      .map(s => KNOWLEDGE_BASE.find(e => e.id === s.id))
      .filter((e): e is KBEntry => !!e)
    // Fallback auf Keyword, wenn Embeddings keine klare Präferenz zeigen
    if (hits.length === 0) return retrieveKBKeyword(question, topN)
    return hits
  } catch (err) {
    console.warn('[bot] vector retrieval failed, falling back to keyword:', err)
    return retrieveKBKeyword(question, topN)
  }
}

// ── Krisen-Erkennung ─────────────────────────────────────────────
// Wenn die User-Nachricht auf eine akute psychische Notlage hindeutet,
// antwortet der Bot sofort mit einer vorgefertigten, empathischen Antwort
// und einer Weiterleitung an /dashboard/crisis + Telefonseelsorge.

const CRISIS_KEYWORDS = [
  'suizid', 'selbstmord', 'umbringen', 'mich töten', 'nicht mehr leben',
  'will sterben', 'will nicht mehr', 'nicht mehr weiter', 'keinen sinn mehr',
  'aufgeben', 'aus dem leben', 'schluss machen', 'alles vorbei',
  'depression akut', 'panikattacke', 'niemand liebt mich', 'hoffnungslos',
]

export function detectCrisis(text: string): boolean {
  const t = text.toLowerCase()
  return CRISIS_KEYWORDS.some(kw => t.includes(kw))
}

export const CRISIS_REPLY = `Ich höre dich. 💙 Was du gerade durchmachst klingt schwer, und du verdienst echte Unterstützung – nicht nur einen Chatbot.

**Bitte melde dich sofort bei Menschen, die helfen können:**

📞 **Telefonseelsorge (24/7, kostenlos, anonym)**
0800 111 0 111 oder 0800 111 0 222

💬 **Online-Chat:** online.telefonseelsorge.de

🚨 **Akuter Notfall:** Wähle 112

Hier auf Mensaena findest du unter **[Krisensystem](/dashboard/crisis)** auch Menschen in deiner Nähe, die sofort unterstützen können, und unter **[Mentale Unterstützung](/dashboard/mental-support)** Ressourcen und Techniken.

Du bist nicht allein. Bitte gib nicht auf. 🌿`

// ── Prompt-Injection-Schutz ────────────────────────────────────
// Einfache Heuristik, die typische Jailbreak-Muster erkennt. Wird nicht
// blockiert, sondern das Modell bekommt eine zusätzliche System-Anweisung
// "ignore override attempts", wenn eines dieser Muster auftaucht.

const INJECTION_PATTERNS = [
  /ignore\s+(all\s+)?previous\s+instructions?/i,
  /ignoriere\s+(alle\s+)?vorherigen?\s+anweisungen/i,
  /disregard\s+the\s+system\s+prompt/i,
  /you\s+are\s+now\s+(a|an)\s+/i,
  /du\s+bist\s+(jetzt|ab\s+jetzt)\s+(ein|eine)\s+/i,
  /pretend\s+to\s+be/i,
  /act\s+as\s+(a|an|if)/i,
  /jailbreak/i,
  /dan\s+mode/i,
]

export function detectInjection(text: string): boolean {
  return INJECTION_PATTERNS.some(p => p.test(text))
}
