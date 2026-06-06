// import-farms-overpass v4 — Multi-Country BBox-Tiles.
// Cron ruft die Funktion pro Run mit ?country=auto auf — die rotiert
// durch ein vordefiniertes Set Metropol-Tiles (DE/AT/CH/IT/ES/FR/TR/RU/GB).
// Manuelle Override: ?bbox=... oder ?country=DE|IT|...

// @ts-nocheck
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const admin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } })

// Vordefinierte BBoxes (ca. 15x15 km um die Stadtkerne).
// Format: [s, w, n, e] in WGS84 Dezimalgrad. Country-Code wird beim Insert verwendet.
const CITY_TILES: Record<string, Array<{ name: string; bbox: string }>> = {
  DE: [
    { name: 'Berlin',    bbox: '52.40,13.20,52.60,13.55' },
    { name: 'Hamburg',   bbox: '53.45,9.85,53.65,10.15' },
    { name: 'München',   bbox: '48.05,11.45,48.25,11.75' },
    { name: 'Köln',      bbox: '50.85,6.85,51.05,7.05' },
    { name: 'Frankfurt', bbox: '50.05,8.60,50.20,8.80' },
  ],
  AT: [
    { name: 'Wien',      bbox: '48.10,16.25,48.30,16.55' },
    { name: 'Graz',      bbox: '47.00,15.35,47.15,15.55' },
    { name: 'Linz',      bbox: '48.20,14.20,48.35,14.40' },
  ],
  CH: [
    { name: 'Zürich',    bbox: '47.30,8.45,47.45,8.65' },
    { name: 'Bern',      bbox: '46.90,7.35,47.05,7.55' },
  ],
  IT: [
    { name: 'Roma',      bbox: '41.80,12.40,42.00,12.65' },
    { name: 'Milano',    bbox: '45.40,9.10,45.55,9.30' },
    { name: 'Napoli',    bbox: '40.80,14.15,40.95,14.35' },
    { name: 'Torino',    bbox: '45.00,7.55,45.15,7.75' },
  ],
  ES: [
    { name: 'Madrid',    bbox: '40.35,-3.80,40.55,-3.55' },
    { name: 'Barcelona', bbox: '41.30,2.05,41.50,2.25' },
    { name: 'Valencia',  bbox: '39.40,-0.45,39.55,-0.25' },
    { name: 'Sevilla',   bbox: '37.30,-6.05,37.45,-5.85' },
  ],
  FR: [
    { name: 'Paris',     bbox: '48.80,2.20,48.95,2.45' },
    { name: 'Lyon',      bbox: '45.70,4.75,45.85,4.95' },
    { name: 'Marseille', bbox: '43.20,5.30,43.40,5.50' },
    { name: 'Toulouse',  bbox: '43.55,1.35,43.70,1.55' },
  ],
  TR: [
    { name: 'İstanbul',  bbox: '40.95,28.85,41.15,29.10' },
    { name: 'Ankara',    bbox: '39.85,32.75,40.00,32.95' },
    { name: 'İzmir',     bbox: '38.35,27.05,38.50,27.25' },
  ],
  RU: [
    { name: 'Москва',    bbox: '55.65,37.45,55.85,37.75' },
    { name: 'Санкт-Петербург', bbox: '59.85,30.25,60.05,30.50' },
  ],
  GB: [
    { name: 'London',    bbox: '51.45,-0.20,51.60,0.05' },
    { name: 'Manchester', bbox: '53.40,-2.30,53.55,-2.15' },
    { name: 'Birmingham', bbox: '52.40,-1.95,52.55,-1.80' },
  ],
}

function slugify(s: string): string {
  return (s || 'farm').toLowerCase()
    .replace(/[ä]/g, 'ae').replace(/[ö]/g, 'oe')
    .replace(/[ü]/g, 'ue').replace(/[ß]/g, 'ss')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').substring(0, 80) || 'farm'
}

async function fetchOverpass(bbox: string): Promise<any[]> {
  const q = `[out:json][timeout:20];(node["shop"="farm"](${bbox});node["craft"="beekeeper"](${bbox});node["craft"="cheesemaker"](${bbox});node["shop"="greengrocer"]["organic"="yes"](${bbox}););out body 80;`
  try {
    const r = await fetch('https://overpass.kumi.systems/api/interpreter', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'data=' + encodeURIComponent(q),
    })
    if (!r.ok) return []
    const j = await r.json()
    return Array.isArray(j.elements) ? j.elements.slice(0, 80) : []
  } catch (_) { return [] }
}

function inferCategory(t: any): string {
  if (t['shop'] === 'farm') return 'Hofladen'
  if (t['craft'] === 'beekeeper') return 'Imkerei'
  if (t['craft'] === 'cheesemaker') return 'Käserei'
  if (t['shop'] === 'greengrocer') return 'Bio-Laden'
  return 'Bauernhof'
}

function pickTile(countryParam: string | null): { country: string; tile: { name: string; bbox: string } } {
  // Auto-Mode: rotiere durch alle Tiles aller Länder.
  if (!countryParam || countryParam === 'auto') {
    const all: Array<{ country: string; tile: { name: string; bbox: string } }> = []
    for (const [c, tiles] of Object.entries(CITY_TILES)) {
      for (const t of tiles) all.push({ country: c, tile: t })
    }
    // Pseudo-zufällig pro Stunde — rotiert pro Cron-Run.
    const idx = Math.floor(Date.now() / (1000 * 60 * 60)) % all.length
    return all[idx]
  }
  // Country-Mode: nimm zufälliges Tile aus dem Country.
  const tiles = CITY_TILES[countryParam.toUpperCase()]
  if (!tiles || tiles.length === 0) return { country: 'DE', tile: CITY_TILES['DE'][0] }
  const idx = Math.floor(Date.now() / (1000 * 60 * 60)) % tiles.length
  return { country: countryParam.toUpperCase(), tile: tiles[idx] }
}

serve(async (req) => {
  const u = new URL(req.url)
  let bbox = u.searchParams.get('bbox')
  let country = 'DE'
  let tileName = 'manual'
  if (!bbox) {
    const pick = pickTile(u.searchParams.get('country'))
    bbox = pick.tile.bbox
    country = pick.country
    tileName = pick.tile.name
  } else {
    country = (u.searchParams.get('country') || 'DE').toUpperCase()
  }
  const elements = await fetchOverpass(bbox)
  if (elements.length === 0) {
    return new Response(JSON.stringify({ ok: true, country, tile: tileName, bbox, found: 0, inserted: 0 }),
      { headers: { 'Content-Type': 'application/json' } })
  }
  const rows: any[] = []
  for (const el of elements) {
    const t = el.tags ?? {}
    const name = t['name'] || t['operator']
    if (!name) continue
    const lat = el.lat ?? el.center?.lat
    const lon = el.lon ?? el.center?.lon
    if (!lat || !lon) continue
    rows.push({
      name,
      slug: slugify(name) + '-osm-' + el.id,
      category: inferCategory(t),
      city: t['addr:city'] ?? tileName,
      country: t['addr:country'] || country,
      phone: t['phone'] ?? null,
      website: t['website'] ?? null,
      latitude: lat,
      longitude: lon,
      is_bio: t['organic'] === 'yes',
      is_public: true,
      is_verified: true,
      source_name: 'OpenStreetMap',
      source_url: `https://www.openstreetmap.org/node/${el.id}`,
    })
  }
  let inserted = 0, err = ''
  if (rows.length) {
    const { error } = await admin
      .from('farm_listings')
      .upsert(rows, { onConflict: 'slug', ignoreDuplicates: false })
    if (error) err = error.message
    else inserted = rows.length
  }
  return new Response(JSON.stringify({
    ok: !err, country, tile: tileName, bbox, found: elements.length, inserted, error: err || undefined,
  }), { headers: { 'Content-Type': 'application/json' } })
})
