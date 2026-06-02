// Spritpreise-Proxy: liefert Tankstellen + Live-Preise abhängig vom Land.
// - AT: e-control.at (offizielle, kostenlose Behörden-API, kein Key)
// - DE: Tankerkönig (creativecommons.tankerkoenig.de, Key aus push_config)
// Antwort-Schema ist einheitlich, damit der Client beide Quellen gleich
// rendert. Demo-Key wird erkannt und mit demo:true zurückgegeben, damit der
// Client einen Hinweis statt Fake-Preisen zeigen kann.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const ADMIN = createClient(SUPABASE_URL, SERVICE_KEY);

const DEMO_TK_KEY = '00000000-0000-0000-0000-000000000002';
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type Station = {
  id: string;
  brand: string;
  name: string;
  street: string;
  place: string;
  lat: number;
  lng: number;
  distance_km: number;
  is_open: boolean;
  diesel: number | null;
  e5: number | null;
  e10: number | null;
};

function haversineKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
) {
  const r = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return 2 * r * Math.asin(Math.sqrt(Math.min(1, a)));
}

async function fromTankerkoenig(
  lat: number,
  lng: number,
  rad: number,
  apiKey: string,
): Promise<Station[]> {
  const r = Math.max(1, Math.min(25, rad));
  const url =
    `https://creativecommons.tankerkoenig.de/json/list.php` +
    `?lat=${lat}&lng=${lng}&rad=${r}&type=all&sort=dist&apikey=${apiKey}`;
  const res = await fetch(url);
  if (!res.ok) return [];
  const j = await res.json();
  if (!j.ok) return [];
  const list = (j.stations ?? []) as Array<Record<string, unknown>>;
  return list.map((s) => ({
    id: String(s.id ?? ''),
    brand: String(s.brand ?? ''),
    name: String(s.name ?? ''),
    street: `${s.street ?? ''} ${s.houseNumber ?? ''}`.trim(),
    place: String(s.place ?? ''),
    lat: Number(s.lat ?? 0),
    lng: Number(s.lng ?? 0),
    distance_km: Number(s.dist ?? 0),
    is_open: s.isOpen === true,
    diesel: typeof s.diesel === 'number' ? s.diesel : null,
    e5: typeof s.e5 === 'number' ? s.e5 : null,
    e10: typeof s.e10 === 'number' ? s.e10 : null,
  }));
}

// E-Control (Österreich): drei Fueltypes einzeln abfragen, dann nach
// station-ID mergen.
async function fromEControl(
  lat: number,
  lng: number,
  rad: number,
): Promise<Station[]> {
  const types = ['DIE', 'SUP', 'GAS'] as const; // Diesel, Super95(E5), CNG/SuperPlus → wir nutzen DIE/SUP, e10 hat AT nicht
  const byId = new Map<string, Station>();
  for (const t of types) {
    const url =
      `https://api.e-control.at/sprit/1.0/search/gas-stations/by-address` +
      `?latitude=${lat}&longitude=${lng}&fuelType=${t}&includeClosed=true`;
    let res: Response;
    try {
      res = await fetch(url, {
        headers: { 'User-Agent': 'mensaena/1.0' },
      });
    } catch {
      continue;
    }
    if (!res.ok) continue;
    let data: unknown;
    try {
      data = await res.json();
    } catch {
      continue;
    }
    const arr = Array.isArray(data) ? data : [];
    for (const raw of arr) {
      const r = raw as Record<string, unknown>;
      const id = String(r.id ?? '');
      if (!id) continue;
      const location = (r.location ?? {}) as Record<string, unknown>;
      const slat = Number(location.latitude ?? 0);
      const slng = Number(location.longitude ?? 0);
      const dist = haversineKm(lat, lng, slat, slng);
      if (dist > rad) continue;
      const prices = (r.prices as Array<Record<string, unknown>>) ?? [];
      const price = prices.length > 0 ? Number(prices[0].amount ?? 0) : null;
      const existing = byId.get(id) ?? {
        id,
        brand: String(r.contact && (r.contact as any).brand ? (r.contact as any).brand : ''),
        name: String(r.name ?? ''),
        street: String(location.address ?? ''),
        place: String(location.city ?? ''),
        lat: slat,
        lng: slng,
        distance_km: dist,
        is_open: r.open !== false,
        diesel: null,
        e5: null,
        e10: null,
      };
      if (t === 'DIE') existing.diesel = price;
      if (t === 'SUP') existing.e5 = price; // AT Super95 = E5-Äquivalent
      byId.set(id, existing);
    }
  }
  return Array.from(byId.values()).sort(
    (a, b) => a.distance_km - b.distance_km,
  );
}

async function getTankerkoenigKey(): Promise<string> {
  try {
    const { data } = await ADMIN.rpc('get_push_config');
    if (Array.isArray(data)) {
      for (const row of data as Array<{ key: string; value: string }>) {
        if (row.key === 'tankerkoenig_api_key') return row.value || DEMO_TK_KEY;
      }
    }
  } catch {/* fallthrough */}
  return DEMO_TK_KEY;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'method_not_allowed' }), {
      status: 405,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }
  let body: { lat?: number; lng?: number; rad_km?: number; country?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'bad_body' }), {
      status: 400,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }
  const lat = Number(body.lat);
  const lng = Number(body.lng);
  const rad = Math.max(1, Math.min(25, Number(body.rad_km ?? 10)));
  if (!isFinite(lat) || !isFinite(lng)) {
    return new Response(JSON.stringify({ error: 'bad_coords' }), {
      status: 400,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  // Land: explizit oder anhand der Koordinaten (grobe AT-Bounding-Box).
  const country = (body.country ?? '').toUpperCase();
  const looksAT =
    country === 'AT' ||
    (lat >= 46.3 && lat <= 49.2 && lng >= 9.4 && lng <= 17.2);
  const looksDE =
    country === 'DE' ||
    (lat >= 47.2 && lat <= 55.1 && lng >= 5.8 && lng <= 15.1);

  try {
    let stations: Station[] = [];
    let source = 'none';
    let demo = false;

    if (looksAT && country !== 'DE') {
      stations = await fromEControl(lat, lng, rad);
      source = 'e-control';
    }
    if (stations.length === 0 && (looksDE || country === '')) {
      const key = await getTankerkoenigKey();
      demo = key === DEMO_TK_KEY;
      stations = await fromTankerkoenig(lat, lng, rad, key);
      source = 'tankerkoenig';
    }
    return new Response(
      JSON.stringify({ ok: true, source, demo, stations }),
      { headers: { ...CORS, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      {
        status: 500,
        headers: { ...CORS, 'Content-Type': 'application/json' },
      },
    );
  }
});
