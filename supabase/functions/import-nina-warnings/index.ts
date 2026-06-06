// import-nina-warnings v2 — nutzt listing.i18nTitle direkt.
// Detail-Fetch nur als Fallback. BBK liefert relevante Daten schon im
// mapData.json (i18nTitle.de, severity, urgency, startDate, geographic
// area in transKeys nicht enthalten — deshalb skip lat/lng wenn nicht
// im Title).

// @ts-nocheck
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const admin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } })

const SOURCES = [
  { name: 'mowas',  url: 'https://warnung.bund.de/api31/mowas/mapData.json' },
  { name: 'katwarn', url: 'https://warnung.bund.de/api31/katwarn/mapData.json' },
  { name: 'biwapp', url: 'https://warnung.bund.de/api31/biwapp/mapData.json' },
  { name: 'dwd',     url: 'https://warnung.bund.de/api31/dwd/mapData.json' },
]

function severityFor(s?: string): string {
  switch ((s ?? '').toLowerCase()) {
    case 'minor':    return 'low'
    case 'moderate': return 'medium'
    case 'severe':   return 'high'
    case 'extreme':  return 'critical'
    default:         return 'medium'
  }
}

function categoryFor(src: string): string {
  if (src === 'dwd') return 'storm'
  return 'other'
}

async function fetchDescription(source: string, id: string): Promise<string | null> {
  try {
    const r = await fetch(`https://warnung.bund.de/api31/${source}/${id}.json`)
    if (!r.ok) return null
    const j = await r.json()
    const info = Array.isArray(j.info) ? j.info[0] : null
    if (!info) return null
    return (info.description || info.headline || info.event || '').toString().substring(0, 3500)
  } catch (_) { return null }
}

serve(async (req) => {
  let imported = 0, updated = 0, skipped = 0
  const failures: string[] = []
  for (const src of SOURCES) {
    try {
      const idx = await fetch(src.url)
      if (!idx.ok) { failures.push(`${src.name}:${idx.status}`); continue }
      const list = await idx.json()
      if (!Array.isArray(list)) { failures.push(`${src.name}:not-array`); continue }
      for (const item of list.slice(0, 20)) {
        const id = item.id
        if (!id) { skipped++; continue }
        const i18n = item.i18nTitle ?? {}
        const title = (i18n.de || i18n.en || 'Warnung').toString().substring(0, 200)
        const desc = (await fetchDescription(src.name, id)) ||
                     'Offizielle Warnung — Details unter warnung.bund.de'
        const extId = `nina-${src.name}-${id}`
        const row = {
          creator_id: null,
          title,
          description: `${desc}\n\n[Quelle: ${src.name.toUpperCase()} · ${extId}]`,
          category: categoryFor(src.name),
          urgency: severityFor(item.severity),
          status: 'active',
          contact_name: 'BBK',
          is_anonymous: false,
          is_verified: true,
        }
        try {
          const { data: existing } = await admin
            .from('crises')
            .select('id')
            .ilike('description', `%${extId}%`)
            .maybeSingle()
          if (existing) {
            await admin.from('crises').update(row).eq('id', existing.id)
            updated++
          } else {
            const { error } = await admin.from('crises').insert(row)
            if (error) { failures.push(`insert:${error.message?.substring(0,80)}`); skipped++; continue }
            imported++
          }
        } catch (e) {
          failures.push(`catch:${String(e).substring(0,80)}`); skipped++
        }
      }
    } catch (e) { failures.push(`${src.name}:${String(e).substring(0,50)}`) }
  }
  return new Response(JSON.stringify({
    ok: true, imported, updated, skipped, failures: failures.slice(0, 10),
  }), { headers: { 'Content-Type': 'application/json' } })
})
