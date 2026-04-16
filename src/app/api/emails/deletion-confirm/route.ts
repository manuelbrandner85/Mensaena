import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { sendEmail } from '@/lib/email/send'
import { buildDeletionConfirmEmail, REENGAGEMENT_SCHEDULE_DAYS } from '@/lib/email/templates/deletion'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'
const BASE_URL     = process.env.NEXT_PUBLIC_APP_URL || 'https://www.mensaena.de'

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

// POST /api/emails/deletion-confirm
// Sendet die Löschbestätigung und setzt das nächste Re-Engagement-Datum.
// Wird vom Admin-Panel (UsersTab) nach Kontolöschung aufgerufen.
export async function POST(req: NextRequest) {
  let body: { email?: string; name?: string }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ error: 'Invalid body' }, { status: 400 })
  }

  const { email, name = '' } = body
  if (!email) {
    return NextResponse.json({ error: 'email required' }, { status: 400 })
  }

  // Followup-Eintrag suchen (vom DB-Trigger angelegt)
  const { data: followup } = await admin
    .from('email_deletion_followups')
    .select('id, unsubscribe_token')
    .eq('email', email)
    .eq('completed', false)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle()

  const unsubscribeToken = followup?.unsubscribe_token ?? ''
  const unsubscribeUrl = unsubscribeToken
    ? `${BASE_URL}/api/emails/deletion-unsubscribe?token=${unsubscribeToken}`
    : '#'

  // Löschbestätigung senden
  const { subject, html } = buildDeletionConfirmEmail({ name, unsubscribeUrl })
  const result = await sendEmail({ to: email, subject, html, fromName: 'Mensaena' })

  if (!result.ok) {
    console.error('[deletion-confirm] send failed:', result.error)
    return NextResponse.json({ ok: false, error: result.error }, { status: 500 })
  }

  // Nächstes Re-Engagement in 7 Tagen setzen
  if (followup?.id) {
    const nextDate = new Date()
    nextDate.setDate(nextDate.getDate() + REENGAGEMENT_SCHEDULE_DAYS[0])
    await admin
      .from('email_deletion_followups')
      .update({ emails_sent: 1, next_send_at: nextDate.toISOString() })
      .eq('id', followup.id)
  }

  return NextResponse.json({ ok: true })
}
