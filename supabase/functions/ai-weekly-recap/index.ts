// ai-weekly-recap — EINMAL pro Woche per pg_cron (NICHT pro Nutzer).
// Aggregiert Wochenzahlen und erzeugt EINEN kurzen, ermutigenden Text.
// Speichert in community_recaps. Dedupe pro week_start (Montag).
import { callAiChain } from '../_shared/ai.ts'
import { CORS, json, adminClient, logAi } from '../_shared/util.ts'

function mondayOf(d: Date): string {
  const x = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()))
  const day = (x.getUTCDay() + 6) % 7 // 0 = Montag
  x.setUTCDate(x.getUTCDate() - day)
  return x.toISOString().slice(0, 10)
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const admin = adminClient()
  const weekStart = mondayOf(new Date())

  // Dedupe: existiert schon ein Recap für diese Woche?
  const { data: existing } = await admin
    .from('community_recaps')
    .select('id, content')
    .eq('week_start', weekStart)
    .maybeSingle()
  if (existing) return json({ recap: existing.content, cached: true })

  const sinceIso = new Date(Date.now() - 7 * 86_400_000).toISOString()
  async function count(table: string): Promise<number> {
    try {
      const { count } = await admin
        .from(table)
        .select('id', { count: 'exact', head: true })
        .gte('created_at', sinceIso)
      return count ?? 0
    } catch (_) {
      return 0
    }
  }
  const stats = {
    posts: await count('posts'),
    helps: await count('interactions'),
    groups: await count('groups'),
    events: await count('events'),
  }

  const system =
    'Du schreibst die wöchentliche Gemeinschafts-Zusammenfassung einer ' +
    'Nachbarschaftshilfe-App. Schreibe EINEN kurzen, ermutigenden, dankbaren ' +
    'Absatz (3-4 Sätze) auf Deutsch über das, was die Gemeinschaft diese Woche ' +
    'bewegt hat. Keine erfundenen Zahlen — nutze nur die gegebenen. Warmherzig, ' +
    'nicht werblich.'
  const content =
    `Diese Woche: ${stats.posts} neue Beiträge, ${stats.helps} Hilfe-Interaktionen, ` +
    `${stats.groups} neue Gruppen, ${stats.events} neue Events.`

  const { text, provider } = await callAiChain(system, content, { timeoutMs: 12_000 })
  const recapText = text ||
    `Diese Woche habt ihr ${stats.posts} Beiträge geteilt und ${stats.helps} mal ` +
    'füreinander geholfen. Danke, dass ihr Mensaena lebendig macht 🌱'

  let recapId: string | null = null
  try {
    const { data: ins } = await admin
      .from('community_recaps')
      .insert({ week_start: weekStart, content: recapText, stats })
      .select('id')
      .maybeSingle()
    recapId = ins?.id ?? null
  } catch (_) {
    // best-effort
  }
  await logAi(admin, { userId: null, feature: 'ai_weekly_recap', provider })

  return json({ recap: recapText, id: recapId, stats, week_start: weekStart })
})
