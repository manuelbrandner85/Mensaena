// Einmaliger Geocoding-Backfill: Beiträge OHNE Koordinaten, aber MIT
// location_text bekommen lat/lng via Nominatim (OpenStreetMap) nachgetragen.
// So landen auch Altdaten auf der Karte, deren Autor kein Geo im Profil hat.
//
// Sicherheit: nur mit dem Service-Role-Key als Bearer aufrufbar (Owner-only).
// Batch-basiert: pro Aufruf max. `limit` Posts, damit das Edge-Timeout
// (~150s) nicht reißt — Nominatim erlaubt nur ~1 Request/Sekunde.
//
// Aufruf (wiederholen bis remaining == 0):
//   curl -X POST \
//     "https://huaqldjkgyosefzfhjnf.supabase.co/functions/v1/backfill-geo" \
//     -H "Authorization: Bearer <SERVICE_ROLE_KEY>" \
//     -H "Content-Type: application/json" \
//     -d '{"limit": 40}'

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const ADMIN = createClient(SUPABASE_URL, SERVICE_KEY);

const NOMINATIM = 'https://nominatim.openstreetmap.org/search';
// Nominatim-Policy verlangt eine identifizierbare User-Agent-Kennung.
const UA = 'Mensaena/1.0 (geo-backfill; +https://www.mensaena.de)';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function geocode(
  query: string,
): Promise<{ lat: number; lng: number } | null> {
  const uri = new URL(NOMINATIM);
  uri.searchParams.set('q', query);
  uri.searchParams.set('format', 'jsonv2');
  uri.searchParams.set('limit', '1');
  uri.searchParams.set('countrycodes', 'de,at,ch');
  uri.searchParams.set('accept-language', 'de');
  try {
    const res = await fetch(uri.toString(), {
      headers: { 'User-Agent': UA, Accept: 'application/json' },
    });
    if (!res.ok) return null;
    const list = await res.json();
    if (!Array.isArray(list) || list.length === 0) return null;
    const lat = parseFloat(list[0].lat);
    const lng = parseFloat(list[0].lon);
    if (Number.isNaN(lat) || Number.isNaN(lng)) return null;
    return { lat, lng };
  } catch {
    return null;
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ ok: false, error: 'POST only' }), {
      status: 405,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  // Owner-Gate: Authorization-Bearer muss der Service-Role-Key sein.
  const auth = req.headers.get('Authorization') || '';
  const token = auth.replace(/^Bearer\s+/i, '').trim();
  if (!SERVICE_KEY || token !== SERVICE_KEY) {
    return new Response(JSON.stringify({ ok: false, error: 'unauthorized' }), {
      status: 401,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  let limit = 40;
  try {
    const body = await req.json();
    if (typeof body?.limit === 'number') {
      limit = Math.max(1, Math.min(100, Math.floor(body.limit)));
    }
  } catch {/* leerer Body → Default 40 */}

  // Kandidaten: keine Koordinaten, aber Standort-Text vorhanden.
  const { data: rows, error } = await ADMIN
    .from('posts')
    .select('id, location_text')
    .is('latitude', null)
    .is('longitude', null)
    .not('location_text', 'is', null)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) {
    return new Response(
      JSON.stringify({ ok: false, error: error.message }),
      { status: 500, headers: { ...CORS, 'Content-Type': 'application/json' } },
    );
  }

  let processed = 0;
  let updated = 0;
  let skipped = 0;

  for (const row of rows ?? []) {
    processed++;
    const text = String(row.location_text ?? '').trim();
    // GPS-Platzhalter und zu kurze/vage Texte überspringen.
    if (text.length < 3 || /^GPS:/i.test(text)) {
      skipped++;
      continue;
    }
    const hit = await geocode(text);
    if (hit) {
      const { error: upErr } = await ADMIN
        .from('posts')
        .update({ latitude: hit.lat, longitude: hit.lng })
        .eq('id', row.id);
      if (upErr) {
        skipped++;
      } else {
        updated++;
      }
    } else {
      skipped++;
    }
    // Nominatim-Rate-Limit respektieren (~1 Request/Sekunde).
    await sleep(1100);
  }

  // Wie viele bleiben insgesamt noch übrig?
  const { count: remaining } = await ADMIN
    .from('posts')
    .select('id', { count: 'exact', head: true })
    .is('latitude', null)
    .is('longitude', null)
    .not('location_text', 'is', null);

  return new Response(
    JSON.stringify({
      ok: true,
      processed,
      updated,
      skipped,
      remaining: remaining ?? null,
      hint:
        (remaining ?? 0) > 0
          ? 'remaining > 0 → erneut aufrufen, bis remaining 0 ist'
          : 'fertig — alle geocodierbaren Altdaten haben jetzt Koordinaten',
    }),
    { headers: { ...CORS, 'Content-Type': 'application/json' } },
  );
});
