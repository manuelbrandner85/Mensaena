// ai-moderate — KI-Sicherheitsnetz für Graubereich-Inhalte.
// Lokale Wortliste/Regex läuft ZUERST im Client; diese Function nur im Zweifel.
// Bei flagged: Eintrag in reports (status 'pending') für Admin-Review.
// NICHTS wird automatisch gelöscht.
import { callAiChain, parseAiJson } from '../_shared/ai.ts'
import {
  CORS, json, getUser, adminClient, checkRate, logAi,
} from '../_shared/util.ts'

interface Verdict {
  flagged: boolean
  reason: string
  severity: 'low' | 'medium' | 'high'
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)
  const admin = adminClient()
  if (!(await checkRate(admin, user.id, 'ai_moderate', 20, 60))) {
    return json({ flagged: false, limited: true })
  }
  const body = await req.json().catch(() => ({}))
  const text = (body.text ?? '').toString().slice(0, 3000)
  const contentType = (body.contentType ?? '').toString().slice(0, 30)
  const contentId = (body.contentId ?? '').toString().slice(0, 64)
  if (!text.trim()) return json({ error: 'empty' }, 400)

  const system =
    'Du bist ein behutsamer Moderations-Filter für eine Nachbarschaftshilfe-App. ' +
    'Prüfe den Text auf: Hass/Hetze, Gewaltandrohung, Beleidigung, Spam/Betrug, ' +
    'sexuelle Belästigung, gefährliche Desinformation. Nachbarschaftliche Bitten, ' +
    'Kritik oder emotionale Notlagen sind NICHT zu flaggen. Antworte AUSSCHLIESSLICH ' +
    'als JSON {"flagged":boolean,"reason":"kurz","severity":"low|medium|high"}.'

  const { text: out, provider } =
    await callAiChain(system, text, { timeoutMs: 12_000, jsonMode: true })
  await logAi(admin, { userId: user.id, feature: 'ai_moderate', provider })

  const v = parseAiJson<Verdict>(out)
  if (!v) return json({ flagged: false, provider })

  const flagged = v.flagged === true
  const severity = ['low', 'medium', 'high'].includes(v.severity)
    ? v.severity
    : 'low'

  // Nur bei flagged UND vorhandener Inhalts-Referenz einen Report anlegen.
  if (flagged && contentType && contentId) {
    try {
      await admin.from('reports').insert({
        reporter_id: user.id,
        content_type: contentType,
        content_id: contentId,
        reason: `KI-Moderation (${severity}): ${(v.reason ?? '').toString().slice(0, 200)}`,
        status: 'pending',
      })
    } catch (_) {
      // best-effort
    }
  }
  return json({ flagged, reason: v.reason ?? '', severity, provider })
})
