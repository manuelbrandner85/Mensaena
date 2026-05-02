import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { sendEmail } from '@/lib/email/send'
import { buildReengagementByIndex, REENGAGEMENT_SCHEDULE_DAYS } from '@/lib/email/templates/deletion'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''
const BASE_URL     = process.env.NEXT_PUBLIC_APP_URL || 'https://www.mensaena.de'
const CRON_SECRET  = process.env.CRON_SECRET || ''

let _admin: ReturnType<typeof createClient> | null = null
function admin() {
  if (!_admin) _admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } })
  return _admin
}

// POST /api/emails/process-followups
// Cron-Job: Verarbeitet fällige Re-Engagement-Mails für gelöschte User.
// Zeitplan: Email 1 nach 7 Tagen, Email 2 nach 14 Tagen, Email 3 nach 30 Tagen, Email 4 nach 60 Tagen.
export async function POST(req: NextRequest) {
  // FIX-120: Auth: nur via Cron-Secret. Wenn nicht konfiguriert → REJECT
  // (vorher: leerer CRON_SECRET liess Auth-Check komplett weg).
  if (!CRON_SECRET) {
    return NextResponse.json({ error: 'CRON_SECRET nicht konfiguriert' }, { status: 503 })
  }
  const secret = req.headers.get('x-cron-secret') || ''
  if (secret !== CRON_SECRET) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  // Fällige Followups laden (next_send_at ≤ jetzt, nicht abgeschlossen, max 4 Mails)
  const { data: followups, error } = await admin()
    .from('email_deletion_followups')
    .select('*')
    .eq('completed', false)
    .lte('next_send_at', new Date().toISOString())
    .lt('emails_sent', 5) // 1 confirm + 4 re-engagement = max 5
    .order('next_send_at', { ascending: true })
    .limit(50)

  if (error) {
    console.error('[process-followups] query error:', error.message)
    return NextResponse.json({ error: error.message }, { status: 500 })
  }

  if (!followups?.length) {
    return NextResponse.json({ ok: true, processed: 0 })
  }

  let processed = 0
  let failed = 0

  for (const fu of followups) {
    // emails_sent: 1 = confirm sent, so re-engagement index = emails_sent - 1
    const reengagementIndex = fu.emails_sent - 1

    // Index 0-3 = 4 re-engagement mails
    if (reengagementIndex < 0 || reengagementIndex >= 4) {
      // Alle gesendet → abschließen
      await admin()
        .from('email_deletion_followups')
        .update({ completed: true })
        .eq('id', fu.id)
      continue
    }

    const unsubscribeUrl = `${BASE_URL}/api/emails/deletion-unsubscribe?token=${fu.unsubscribe_token}`
    const emailData = buildReengagementByIndex(reengagementIndex, {
      name: fu.display_name || '',
      unsubscribeUrl,
    })

    if (!emailData) {
      await admin()
        .from('email_deletion_followups')
        .update({ completed: true })
        .eq('id', fu.id)
      continue
    }

    const result = await sendEmail({
      to: fu.email,
      subject: emailData.subject,
      html: emailData.html,
      fromName: 'Mensaena',
    })

    if (result.ok) {
      const newCount = fu.emails_sent + 1
      const nextIndex = reengagementIndex + 1

      if (nextIndex >= 4) {
        // Letzte Mail gesendet → abschließen
        await admin()
          .from('email_deletion_followups')
          .update({ emails_sent: newCount, completed: true })
          .eq('id', fu.id)
      } else {
        // Nächstes Sendedatum berechnen
        const nextDate = new Date(fu.deleted_at)
        nextDate.setDate(nextDate.getDate() + REENGAGEMENT_SCHEDULE_DAYS[nextIndex])
        await admin()
          .from('email_deletion_followups')
          .update({ emails_sent: newCount, next_send_at: nextDate.toISOString() })
          .eq('id', fu.id)
      }
      processed++
    } else {
      console.error(`[process-followups] failed for ${fu.email}:`, result.error)
      failed++
    }

    // 200ms Delay zwischen Mails
    await new Promise(r => setTimeout(r, 200))
  }

  return NextResponse.json({ ok: true, processed, failed })
}
