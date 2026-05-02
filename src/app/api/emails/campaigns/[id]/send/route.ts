import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'
import { sendEmail } from '@/lib/email/send'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''
const BASE_URL     = process.env.NEXT_PUBLIC_APP_URL || 'https://www.mensaena.de'

let _admin: ReturnType<typeof createClient> | null = null
function admin() {
  if (!_admin) _admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } })
  return _admin
}

// Ersetzt {{vorname}}, {{name}}, {{stadt}}, {{letzte_hilfe}} mit echten Werten
function applyPersonalization(
  html: string,
  vars: { vorname: string; name: string; stadt: string; letzte_hilfe: string },
): string {
  return html
    .replace(/\{\{vorname\}\}/gi, vars.vorname)
    .replace(/\{\{name\}\}/gi, vars.name)
    .replace(/\{\{stadt\}\}/gi, vars.stadt)
    .replace(/\{\{letzte_hilfe\}\}/gi, vars.letzte_hilfe)
}

// Wraps all <a href="..."> with click-tracking redirect
function wrapLinksWithTracking(html: string, campaignId: string, email: string): string {
  return html.replace(
    /href="(https?:\/\/[^"]+)"/gi,
    (_, url) => {
      if (url.includes('/api/emails/track/')) return `href="${url}"`
      const trackUrl = `${BASE_URL}/api/emails/track/click?cid=${campaignId}&email=${encodeURIComponent(email)}&url=${encodeURIComponent(url)}`
      return `href="${trackUrl}"`
    },
  )
}

// POST /api/emails/campaigns/[id]/send
export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) {
    return err.forbidden()
  }

  const { id } = await params

  const { data: campaign, error: campaignErr } = await admin
    .from('email_campaigns')
    .select('*')
    .eq('id', id)
    .maybeSingle()

  if (campaignErr) return err.internal(campaignErr.message)
  if (!campaign) return err.notFound('Kampagne nicht gefunden')
  if (campaign.status === 'sent') return err.conflict('Kampagne wurde bereits gesendet')

  let recipientEmails: string[] | undefined
  let scheduledAt: string | undefined
  let segment: string | undefined
  let channels: string[] = ['email']
  try {
    const body = await req.json().catch(() => ({}))
    recipientEmails = body?.emails as string[] | undefined
    scheduledAt = body?.scheduled_at as string | undefined
    segment = body?.segment as string | undefined
    if (Array.isArray(body?.channels)) channels = body.channels as string[]
  } catch { /* kein Body → alle, sofort, nur Email */ }

  if (scheduledAt) {
    await admin
      .from('email_campaigns')
      .update({ status: 'scheduled' as string, scheduled_at: scheduledAt, channels })
      .eq('id', id)
    return NextResponse.json({ ok: true, scheduled: true, scheduled_at: scheduledAt, sent_count: 0, recipient_count: 0 })
  }

  await admin().from('email_campaigns').update({ status: 'sending', channels }).eq('id', id)

  // Segment → User-IDs
  let segmentUserIds: string[] | undefined
  if (segment) {
    const now = new Date()
    let profileQuery = admin().from('profiles').select('id')
    if (segment === 'new_7d')      profileQuery = profileQuery.gte('created_at', new Date(now.getTime() - 7 * 86400000).toISOString())
    else if (segment === 'new_30d') profileQuery = profileQuery.gte('created_at', new Date(now.getTime() - 30 * 86400000).toISOString())
    else if (segment === 'inactive_30d') profileQuery = profileQuery.lte('updated_at', new Date(now.getTime() - 30 * 86400000).toISOString())
    else if (segment === 'inactive_90d') profileQuery = profileQuery.lte('updated_at', new Date(now.getTime() - 90 * 86400000).toISOString())
    const { data: segProfiles } = await profileQuery.limit(500)
    segmentUserIds = (segProfiles ?? []).map((p: { id: string }) => p.id)
  }

  let query = admin
    .from('email_subscriptions')
    .select('user_id, email, unsubscribe_token')
    .eq('subscribed', true)
  if (recipientEmails?.length) query = query.in('email', recipientEmails)
  else if (segmentUserIds?.length) query = query.in('user_id', segmentUserIds)

  const { data: subscribers, error: subErr } = await query
  if (subErr) {
    await admin().from('email_campaigns').update({ status: 'draft' }).eq('id', id)
    return err.internal(subErr.message)
  }

  // Profil-Map für Personalisierung vorab laden
  const userIds = (subscribers ?? []).map((s: { user_id: string }) => s.user_id).filter(Boolean)
  const profileMap: Record<string, { name: string; location: string }> = {}
  if (userIds.length > 0) {
    const { data: profiles } = await admin
      .from('profiles')
      .select('id, name, location')
      .in('id', userIds)
    for (const p of profiles ?? []) {
      profileMap[p.id] = { name: p.name ?? '', location: p.location ?? '' }
    }
  }

  const sendEmail_ = channels.includes('email')
  const sendPush_  = channels.includes('push')

  // Push-Abonnenten laden (Web-Push + FCM) für Multi-Channel
  let pushTokens: Array<{ user_id: string; token: string; platform: string }> = []
  if (sendPush_ && segmentUserIds) {
    const { data: tokens } = await admin
      .from('fcm_tokens')
      .select('user_id, token, platform')
      .in('user_id', segmentUserIds)
      .eq('active', true)
    pushTokens = tokens ?? []
  } else if (sendPush_ && !recipientEmails?.length) {
    const { data: tokens } = await admin
      .from('fcm_tokens')
      .select('user_id, token, platform')
      .eq('active', true)
      .limit(500)
    pushTokens = tokens ?? []
  }

  const recipientCount = subscribers?.length ?? 0
  let sentCount = 0
  const logEntries: Array<{
    campaign_id: string; user_id: string | null; email: string; status: string; error_msg: string | null
  }> = []

  for (const sub of (subscribers ?? [])) {
    const prof = profileMap[sub.user_id] ?? { name: '', location: '' }
    const vorname = prof.name?.split(' ')[0] ?? ''
    const personVars = {
      vorname: vorname || 'Nachbar',
      name: prof.name || 'Nachbar',
      stadt: prof.location || 'deiner Stadt',
      letzte_hilfe: 'einer Nachbarschaftshilfe',
    }

    const unsubscribeUrl = `${BASE_URL}/unsubscribe?token=${sub.unsubscribe_token}`
    const trackPixel = `<img src="${BASE_URL}/api/emails/track/open?cid=${id}&email=${encodeURIComponent(sub.email)}" width="1" height="1" alt="" style="display:none;" />`

    let html = campaign.html_content
    html = applyPersonalization(html, personVars)
    html = html.replace(/UNSUBSCRIBE_URL/g, unsubscribeUrl)
    html = wrapLinksWithTracking(html, id, sub.email)
    html = html.replace('</body>', `${trackPixel}</body>`)

    let ok = true
    if (sendEmail_) {
      const result = await sendEmail({ to: sub.email, subject: campaign.subject, html, fromName: 'Mensaena' })
      ok = result.ok
      logEntries.push({
        campaign_id: id,
        user_id: sub.user_id,
        email: sub.email,
        status: result.ok ? 'sent' : 'failed',
        error_msg: result.ok ? null : (result.error ?? null),
      })
    }
    if (ok) sentCount++
    await new Promise(r => setTimeout(r, 200))
  }

  // Multi-Channel: Push-Benachrichtigungen via Supabase Edge Function
  if (sendPush_ && pushTokens.length > 0) {
    try {
      await fetch(`${SUPABASE_URL}/functions/v1/send-push`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${SERVICE_KEY}` },
        body: JSON.stringify({
          tokens: pushTokens.map(t => t.token),
          title: campaign.subject,
          body: campaign.preview_text ?? campaign.subject,
          data: { url: '/dashboard/notifications' },
        }),
      })
    } catch { /* Push-Fehler ist nicht kritisch */ }
  }

  if (logEntries.length > 0) await admin().from('email_logs').insert(logEntries)

  await admin
    .from('email_campaigns')
    .update({ status: 'sent', sent_at: new Date().toISOString(), recipient_count: recipientCount, sent_count: sentCount })
    .eq('id', id)

  return NextResponse.json({
    ok: true,
    recipient_count: recipientCount,
    sent_count: sentCount,
    failed_count: recipientCount - sentCount,
    push_count: pushTokens.length,
  })
}
