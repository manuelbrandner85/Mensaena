// auto-social-content — Cron wöchentlich. Die KI erzeugt aus ECHTEN, aber
// ANONYMISIERTEN Erfolgszahlen fertige, teilbare Social-Posts. Diese landen im
// Content-Planer (content_plan, status 'draft', source 'ai_social'). Es wird
// NICHTS automatisch veröffentlicht — Freigabe erfolgt manuell per Klick.
// Keine personenbezogenen Daten: nur aggregierte Zahlen + community_recaps.
import { CORS, json, adminClient, logAi } from '../_shared/util.ts'
import { callAiChain, parseAiJson } from '../_shared/ai.ts'

const WINDOW_DAYS = 7

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const admin = adminClient()
  const since = new Date(Date.now() - WINDOW_DAYS * 86_400_000).toISOString()

  // Aggregierte, anonyme Kennzahlen der Woche.
  const [helpsRes, newUsersRes, postsRes, recapRes] = await Promise.all([
    admin.from('interactions').select('id', { count: 'exact', head: true })
      .eq('status', 'completed').gte('updated_at', since),
    admin.from('profiles').select('id', { count: 'exact', head: true })
      .gte('created_at', since),
    admin.from('posts').select('id', { count: 'exact', head: true })
      .gte('created_at', since),
    admin.from('community_recaps').select('share_text, stats')
      .order('week_start', { ascending: false }).limit(1).maybeSingle(),
  ])

  const helps = helpsRes.count ?? 0
  const newUsers = newUsersRes.count ?? 0
  const posts = postsRes.count ?? 0
  const recap = (recapRes.data as { share_text?: string } | null)?.share_text ?? ''

  const facts = [
    `Abgeschlossene Hilfen (7 Tage): ${helps}`,
    `Neue Nachbar:innen (7 Tage): ${newUsers}`,
    `Neue Beiträge (7 Tage): ${posts}`,
    recap ? `Wochenrückblick: ${recap}` : '',
  ].filter(Boolean).join('\n')

  // KI: 2 teilbare Posts als JSON. Keine Namen, keine personenbezogenen Daten.
  const { text } = await callAiChain(
    'Du bist Social-Media-Redakteur:in einer gemeinnützigen Nachbarschaftshilfe-'
    + 'App (Mensaena). Erzeuge aus den aggregierten, anonymen Wochenzahlen ZWEI '
    + 'kurze, warmherzige, teilbare Posts (je max 280 Zeichen, 1–2 passende '
    + 'Emojis, KEINE Namen, KEINE personenbezogenen Daten, keine erfundenen Zahlen). '
    + 'Antworte als JSON: {"posts":[{"title":"...","text":"..."},{"title":"...","text":"..."}]}',
    facts,
    { timeoutMs: 12000, jsonMode: true },
  )

  const parsed = parseAiJson<{ posts?: Array<{ title?: string; text?: string }> }>(text)
  const items = (parsed?.posts ?? []).filter((p) => p && p.text)
  if (items.length === 0) {
    return json({ ok: true, created: 0, note: 'no usable AI output' })
  }

  let created = 0
  for (const it of items.slice(0, 3)) {
    try {
      await admin.from('content_plan').insert({
        kind: 'social',
        title: (it.title || 'Social-Post').toString().slice(0, 120),
        body: (it.text || '').toString().slice(0, 600),
        share_text: (it.text || '').toString().slice(0, 600),
        status: 'draft',
        source: 'ai_social',
      })
      created++
    } catch (_) { /* skip */ }
  }
  await logAi(admin, { userId: null, feature: 'social_content' })
  return json({ ok: true, created })
})
