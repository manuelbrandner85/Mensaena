import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { sendEmail } from '@/lib/email/send'
import { buildWelcomeEmail } from '@/lib/email/templates/welcome'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'
const BASE_URL     = process.env.NEXT_PUBLIC_APP_URL || 'https://www.mensaena.de'

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

export async function POST(req: NextRequest) {
  let body: { userId?: string; email?: string; name?: string }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ error: 'Invalid body' }, { status: 400 })
  }

  const { userId, email, name = 'Nachbar' } = body
  if (!email) {
    return NextResponse.json({ error: 'email required' }, { status: 400 })
  }

  // Unsubscribe-Token aus email_subscriptions holen (wird via DB-Trigger angelegt)
  let unsubscribeToken: string | null = null
  if (userId) {
    const { data } = await admin
      .from('email_subscriptions')
      .select('unsubscribe_token, subscribed')
      .eq('user_id', userId)
      .maybeSingle()

    if (data) {
      unsubscribeToken = data.unsubscribe_token
      // Nicht senden wenn bereits abgemeldet
      if (!data.subscribed) {
        return NextResponse.json({ ok: true, skipped: true })
      }
    } else {
      // Subscription noch nicht da (Trigger-Latenz) → anlegen
      const { data: ins } = await admin
        .from('email_subscriptions')
        .insert({ user_id: userId, email })
        .select('unsubscribe_token')
        .single()
      unsubscribeToken = ins?.unsubscribe_token ?? null
    }
  }

  const unsubscribeUrl = unsubscribeToken
    ? `${BASE_URL}/unsubscribe?token=${unsubscribeToken}`
    : `${BASE_URL}/unsubscribe`

  const { subject, html } = buildWelcomeEmail({ name, unsubscribeUrl })

  // E-Mail versenden
  const result = await sendEmail({ to: email, subject, html, fromName: 'Mensaena' })

  if (!result.ok) {
    console.error('[welcome-email] send failed:', result.error)
    return NextResponse.json({ ok: false, error: result.error }, { status: 500 })
  }

  // Kampagnen-Log (optional, als Willkommens-Kampagne falls nötig)
  return NextResponse.json({ ok: true })
}
