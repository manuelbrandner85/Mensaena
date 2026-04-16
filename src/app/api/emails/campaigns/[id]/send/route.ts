import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'
import { sendEmail } from '@/lib/email/send'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'
const BASE_URL     = process.env.NEXT_PUBLIC_APP_URL || 'https://www.mensaena.de'

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

// POST /api/emails/campaigns/[id]/send – Kampagne an alle Subscriber senden
export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  // Auth prüfen
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) {
    return err.forbidden()
  }

  const { id } = await params

  // Kampagne laden
  const { data: campaign, error: campaignErr } = await admin
    .from('email_campaigns')
    .select('*')
    .eq('id', id)
    .maybeSingle()

  if (campaignErr) return err.internal(campaignErr.message)
  if (!campaign) return err.notFound('Kampagne nicht gefunden')
  if (campaign.status === 'sent') return err.conflict('Kampagne wurde bereits gesendet')

  // Als "sending" markieren
  await admin
    .from('email_campaigns')
    .update({ status: 'sending' })
    .eq('id', id)

  // Alle aktiven Subscriber laden
  const { data: subscribers, error: subErr } = await admin
    .from('email_subscriptions')
    .select('user_id, email, unsubscribe_token')
    .eq('subscribed', true)

  if (subErr) {
    await admin.from('email_campaigns').update({ status: 'draft' }).eq('id', id)
    return err.internal(subErr.message)
  }

  const recipientCount = subscribers?.length ?? 0
  let sentCount = 0
  const logEntries: Array<{
    campaign_id: string
    user_id: string | null
    email: string
    status: string
    error_msg: string | null
  }> = []

  // Sequenziell senden mit kurzem Delay (SMTP-Schutz)
  for (const sub of (subscribers ?? [])) {
    // Unsubscribe-URL personalisieren
    const unsubscribeUrl = `${BASE_URL}/unsubscribe?token=${sub.unsubscribe_token}`
    // Unsubscribe-Link in der HTML ersetzen (Platzhalter im Template)
    const personalizedHtml = campaign.html_content.replace(
      /UNSUBSCRIBE_URL/g,
      unsubscribeUrl
    )

    const result = await sendEmail({
      to: sub.email,
      subject: campaign.subject,
      html: personalizedHtml,
      fromName: 'Mensaena',
    })

    logEntries.push({
      campaign_id: id,
      user_id: sub.user_id,
      email: sub.email,
      status: result.ok ? 'sent' : 'failed',
      error_msg: result.ok ? null : (result.error ?? null),
    })

    if (result.ok) sentCount++

    // 200ms Pause zwischen Mails (SMTP-Schutz)
    await new Promise(r => setTimeout(r, 200))
  }

  // Logs batch-insert
  if (logEntries.length > 0) {
    await admin.from('email_logs').insert(logEntries)
  }

  // Kampagne als "sent" markieren
  await admin
    .from('email_campaigns')
    .update({
      status: 'sent',
      sent_at: new Date().toISOString(),
      recipient_count: recipientCount,
      sent_count: sentCount,
    })
    .eq('id', id)

  return NextResponse.json({
    ok: true,
    recipient_count: recipientCount,
    sent_count: sentCount,
    failed_count: recipientCount - sentCount,
  })
}
