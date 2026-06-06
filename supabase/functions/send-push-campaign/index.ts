// send-push-campaign — Admin loest Push-Kampagne aus. Schreibt notifications-
// Zeilen mit metadata.marketing=true an alle marketing_opt_in=true Nutzer
// (Trigger schickt automatisch Push). Schutzregeln via notify_guard.
import { CORS, json, getUser, adminClient } from '../_shared/util.ts'
import { marketingGuard } from '../_shared/notify_guard.ts'

const BATCH = 200

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)
  const admin = adminClient()

  const { data: prof } = await admin
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!prof || prof.role !== 'admin') return json({ error: 'forbidden' }, 403)

  const body = await req.json().catch(() => ({}))
  const title = (body.title ?? '').toString().slice(0, 120)
  const text = (body.body ?? '').toString().slice(0, 500)
  const link = (body.link ?? '/dashboard/settings').toString().slice(0, 200)
  const segmentId = body.segment_id ? body.segment_id.toString() : undefined
  if (!title || !text) return json({ error: 'missing_title_or_body' }, 400)

  // Audience: marketing_opt_in=true (Segment optional)
  let q = admin.from('profiles').select('id').eq('marketing_opt_in', true)
  if (segmentId === 'new_users_7d') {
    q = q.gte('created_at', new Date(Date.now() - 7 * 86_400_000).toISOString())
  } else if (segmentId === 'top_helpers') {
    q = q.gte('karma_points', 50)
  }
  const { data: audience } = await q.limit(2000)
  const slice = (audience ?? []).slice(0, BATCH)

  let sent = 0, skipped = 0
  for (const u of slice) {
    const guard = await marketingGuard(admin, { userId: u.id, optInColumn: 'marketing_opt_in' })
    if (!guard.allowed) { skipped++; continue }
    try {
      await admin.from('notifications').insert({
        user_id: u.id,
        type: 'campaign',
        category: 'system',
        title,
        body: text,
        link,
        scheduled_for: guard.scheduledFor ?? null,
        metadata: { marketing: true, kind: 'push_campaign' },
      })
      sent++
    } catch (_) { skipped++ }
  }

  return json({ ok: true, audience: (audience ?? []).length, sent, skipped })
})
