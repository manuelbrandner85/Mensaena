// send-email-campaign — Admin loest Versand aus. Verschickt eine email_campaigns-
// Zeile an alle email_opt_in=true Nutzer im Segment, ueber send-email (Resend/SMTP).
// Schreibt fuer JEDEN Empfaenger eine email_sends-Zeile (Audit).
import { CORS, json, getUser, adminClient } from '../_shared/util.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const BATCH = 200

interface Profile { id: string; email?: string | null; name?: string | null; nickname?: string | null }

async function loadAudience(admin: ReturnType<typeof adminClient>, segmentId?: string): Promise<Profile[]> {
  // Default-Zielgruppe: alle email_opt_in=true. Segment-Filter optional.
  let q = admin.from('profiles').select('id, name, nickname').eq('email_opt_in', true)
  if (segmentId) {
    const { data: seg } = await admin
      .from('email_segments').select('filter_type, filter_config').eq('id', segmentId).maybeSingle()
    const ft = (seg?.filter_type ?? '').toString()
    if (ft === 'new_users_7d') q = q.gte('created_at', new Date(Date.now() - 7 * 86_400_000).toISOString())
    else if (ft === 'top_helpers') q = q.gte('karma_points', 50)
  }
  const { data: profs } = await q.limit(2000)
  if (!profs?.length) return []
  // E-Mails kommen aus auth.users; via admin-API holen.
  const ids = profs.map((p: Profile) => p.id)
  const { data: { users } } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 })
  const byId = new Map<string, string>()
  for (const u of users ?? []) {
    if (ids.includes(u.id) && u.email) byId.set(u.id, u.email)
  }
  return profs.map((p: Profile) => ({ ...p, email: byId.get(p.id) })).filter((p: Profile) => !!p.email)
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)
  const admin = adminClient()

  // Admin-Check
  const { data: prof } = await admin
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!prof || prof.role !== 'admin') return json({ error: 'forbidden' }, 403)

  // Notbremse
  const { data: brake } = await admin
    .from('app_settings').select('value').eq('key', 'marketing_paused').maybeSingle()
  if (brake?.value === true || brake?.value === 'true') {
    return json({ ok: false, error: 'marketing_paused' }, 423)
  }

  const body = await req.json().catch(() => ({}))
  const campaignId = (body.campaign_id ?? '').toString()
  const segmentId = body.segment_id ? body.segment_id.toString() : undefined
  const testTo = body.test_to ? body.test_to.toString() : null
  if (!campaignId) return json({ error: 'missing campaign_id' }, 400)

  const { data: c } = await admin
    .from('email_campaigns').select('id, subject, body_html, html_content, body_text')
    .eq('id', campaignId).maybeSingle()
  if (!c) return json({ error: 'campaign_not_found' }, 404)
  const html = (c.body_html || c.html_content || '').toString()
  if (!c.subject || !html) return json({ error: 'campaign_incomplete' }, 400)

  // Testversand: nur an angegebene Adresse, keine Audit-Zeilen.
  if (testTo) {
    const r = await fetch(`${SUPABASE_URL}/functions/v1/send-email`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${SERVICE_ROLE}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ to: testTo, subject: `[TEST] ${c.subject}`, html, text: c.body_text, category: 'marketing' }),
    })
    return json({ ok: r.ok, test: true })
  }

  const audience = await loadAudience(admin, segmentId)
  const slice = audience.slice(0, BATCH) // Volumenschutz pro Aufruf
  let sent = 0, failed = 0
  for (const u of slice) {
    try {
      const r = await fetch(`${SUPABASE_URL}/functions/v1/send-email`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${SERVICE_ROLE}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ to: u.email!, subject: c.subject, html, text: c.body_text, category: 'marketing' }),
      })
      const ok = r.ok
      await admin.from('email_sends').insert({
        campaign_id: campaignId, user_id: u.id, email: u.email,
        template: 'campaign', status: ok ? 'sent' : 'failed',
        sent_at: ok ? new Date().toISOString() : null,
      })
      if (ok) sent++; else failed++
    } catch (_) { failed++ }
  }

  await admin.from('email_campaigns').update({
    sent_at: new Date().toISOString(),
    sent_count: sent,
    recipient_count: audience.length,
    success_count: sent,
    failure_count: failed,
    status: 'sent',
  }).eq('id', campaignId)

  return json({ ok: true, audience: audience.length, sent, failed })
})
