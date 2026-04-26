import { NextRequest, NextResponse } from 'next/server'

// ─────────────────────────────────────────────────────────────────────────────
// Bundesagentur für Arbeit – Bildungssuche Server-Proxy
//
// Credentials: BA InfoSysBub public-client OAuth2
// Token-Endpoint: https://rest.arbeitsagentur.de/oauth/gettoken_cc
// Token-Laufzeit: 24 h → wird serverseitig gecacht
// ─────────────────────────────────────────────────────────────────────────────

const BA_TOKEN_URL     = 'https://rest.arbeitsagentur.de/oauth/gettoken_cc'
const BA_AB_URL        = 'https://rest.arbeitsagentur.de/infosysbub/absuche/pc/v1/ausbildungsangebot'
const BA_WB_URL        = 'https://rest.arbeitsagentur.de/infosysbub/wbsuche/pc/v2/bildungsangebot'
const USER_AGENT       = 'MensaEna/1.0 (https://www.mensaena.de)'

// BA public-client credentials for InfoSysBub – no secret needed
// Override via env if required (BA may issue a custom key)
const CLIENT_ID     = process.env.BA_EDUCATION_CLIENT_ID     ?? 'infosysbub'
const CLIENT_SECRET = process.env.BA_EDUCATION_CLIENT_SECRET ?? ''

// ── Server-side token cache ───────────────────────────────────────────────────

let cachedToken: string | null = null
let tokenExpiresAt = 0

async function getToken(): Promise<string | null> {
  if (cachedToken && Date.now() < tokenExpiresAt - 60_000) return cachedToken
  try {
    const body = new URLSearchParams({
      grant_type:    'client_credentials',
      client_id:     CLIENT_ID,
      client_secret: CLIENT_SECRET,
    })
    const res = await fetch(BA_TOKEN_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent':   USER_AGENT,
      },
      body: body.toString(),
      // Don't cache the token request itself
      cache: 'no-store',
    })
    if (!res.ok) {
      console.warn('[education] BA token fetch failed', res.status)
      return null
    }
    const json = await res.json() as { access_token?: string; expires_in?: number }
    if (!json.access_token) return null
    cachedToken    = json.access_token
    tokenExpiresAt = Date.now() + (json.expires_in ?? 86400) * 1000
    return cachedToken
  } catch (err) {
    console.warn('[education] BA token error', err)
    return null
  }
}

// ── Raw response types ────────────────────────────────────────────────────────

interface RawAusbildung {
  referenznummer?: string
  titel?:          string
  bildungsanbieter?: { name?: string }
  angebotsAdresse?:  { ort?: string; plz?: string; strasse?: string }
  beginnDaten?:      Array<{ startdatum?: string }>
  angebotsbeschreibung?: string
  url?: string
  externeUrl?: string
}

interface RawWeiterbildung {
  id?:              number | string
  titel?:           string
  bildungsanbieter?: { name?: string; url?: string }
  veranstaltungsort?: { ort?: string; plz?: string; strasse?: string }
  naechsterStarttermin?: string
  foerderung?:      boolean
  beschreibung?:    string
  bildungsart?:     { bezeichnung?: string }
  url?: string
}

// ── Normalisation helpers ─────────────────────────────────────────────────────

function normalizeAusbildung(raw: RawAusbildung, plz: string) {
  const addrPlz = raw.angebotsAdresse?.plz ?? plz
  const city    = raw.angebotsAdresse?.ort ?? ''
  return {
    id:          raw.referenznummer ?? String(Math.random()),
    title:       raw.titel ?? 'Ausbildungsangebot',
    provider:    raw.bildungsanbieter?.name ?? '',
    city,
    plz:         addrPlz,
    startDate:   raw.beginnDaten?.[0]?.startdatum ?? null,
    description: raw.angebotsbeschreibung ?? null,
    url:         raw.externeUrl ?? raw.url
                   ?? `https://www.arbeitsagentur.de/bildung/ausbildung/ausbildungsangebote/${raw.referenznummer ?? ''}`,
    type:        'apprenticeship' as const,
  }
}

function normalizeWeiterbildung(raw: RawWeiterbildung, plz: string) {
  const city = raw.veranstaltungsort?.ort ?? ''
  return {
    id:          String(raw.id ?? Math.random()),
    title:       raw.titel ?? 'Weiterbildungsangebot',
    provider:    raw.bildungsanbieter?.name ?? '',
    city,
    plz:         raw.veranstaltungsort?.plz ?? plz,
    startDate:   raw.naechsterStarttermin ?? null,
    description: raw.beschreibung ?? null,
    funded:      raw.foerderung ?? false,
    category:    raw.bildungsart?.bezeichnung ?? null,
    url:         raw.bildungsanbieter?.url ?? raw.url
                   ?? `https://kursnet-finden.arbeitsagentur.de/kurs/suche?ort=${encodeURIComponent(city)}&plz=${raw.veranstaltungsort?.plz ?? plz}`,
    type:        'course' as const,
  }
}

// ── Route handler ─────────────────────────────────────────────────────────────

export async function GET(req: NextRequest) {
  const sp     = req.nextUrl.searchParams
  const kind   = sp.get('kind') ?? 'apprenticeship'   // 'apprenticeship' | 'course'
  const plz    = sp.get('plz') ?? ''
  const radius = sp.get('radius') ?? '25'
  const query  = sp.get('query') ?? ''
  const page   = sp.get('page') ?? '0'
  const size   = sp.get('size') ?? '10'

  if (!plz) {
    return NextResponse.json({ error: 'plz required' }, { status: 400 })
  }

  const token = await getToken()

  const headers: HeadersInit = {
    'User-Agent': USER_AGENT,
    'Accept':     'application/json',
  }
  if (token) headers['Authorization'] = `Bearer ${token}`

  try {
    if (kind === 'apprenticeship') {
      const params = new URLSearchParams({
        ort:     plz,
        umkreis: radius,
        page,
        size,
      })
      if (query) params.set('ausbildungsbezeichnung', query)

      const res = await fetch(`${BA_AB_URL}?${params}`, {
        headers,
        next: { revalidate: 3600 },
      })

      if (!res.ok) {
        console.warn('[education] absuche error', res.status)
        return NextResponse.json({ items: [], total: 0 })
      }

      const json = await res.json() as {
        eingebettet?: Record<string, RawAusbildung[]>
        maxErgebnisse?: number
      }

      // The embedded key name varies; grab first array value
      const firstKey = Object.keys(json.eingebettet ?? {})[0] ?? ''
      const items = (json.eingebettet?.[firstKey] ?? []).map(r => normalizeAusbildung(r, plz))

      return NextResponse.json(
        { items, total: json.maxErgebnisse ?? items.length },
        { headers: { 'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=300' } },
      )
    }

    // Courses (Weiterbildung)
    const params = new URLSearchParams({
      'orte.plz': plz,
      umkreis:    radius,
      page,
      size,
    })
    if (query) params.set('suchworte', query)

    const res = await fetch(`${BA_WB_URL}?${params}`, {
      headers,
      next: { revalidate: 3600 },
    })

    if (!res.ok) {
      console.warn('[education] wbsuche error', res.status)
      return NextResponse.json({ items: [], total: 0 })
    }

    const json = await res.json() as {
      eingebettet?: Record<string, RawWeiterbildung[]>
      maxErgebnisse?: number
    }

    const firstKey = Object.keys(json.eingebettet ?? {})[0] ?? ''
    const items = (json.eingebettet?.[firstKey] ?? []).map(r => normalizeWeiterbildung(r, plz))

    return NextResponse.json(
      { items, total: json.maxErgebnisse ?? items.length },
      { headers: { 'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=300' } },
    )
  } catch (err) {
    console.error('[education] route error', err)
    return NextResponse.json({ items: [], total: 0 })
  }
}
