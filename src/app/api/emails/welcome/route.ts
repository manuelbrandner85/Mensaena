import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { sendEmail } from '@/lib/email/send'
import { buildWelcomeEmail } from '@/lib/email/templates/welcome'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''
const BASE_URL     = process.env.NEXT_PUBLIC_APP_URL || 'https://www.mensaena.de'

let _admin: ReturnType<typeof createClient> | null = null
function admin() {
  if (!_admin) _admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } })
  return _admin
}

export async function POST(req: NextRequest) {
  let body: { userId?: string; email?: string; name?: string }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ error: 'Invalid body' }, { status: 400 })
  }

  const { userId, email } = body
  if (!email) {
    return NextResponse.json({ error: 'email required' }, { status: 400 })
  }

  // Name aus Profil auslesen (display_name → name → Fallback)
  let displayName = ''
  if (userId) {
    const { data: profile } = await admin
      .from('profiles')
      .select('display_name, name')
      .eq('id', userId)
      .maybeSingle()
    displayName = profile?.display_name || profile?.name || ''
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

  const { subject, html } = buildWelcomeEmail({ name: displayName, unsubscribeUrl })

  // E-Mail versenden
  const result = await sendEmail({ to: email, subject, html, fromName: 'Mensaena' })

  if (!result.ok) {
    console.error('[welcome-email] send failed:', result.error)
    return NextResponse.json({ ok: false, error: result.error }, { status: 500 })
  }

  // Versand loggen
  await admin().from('email_logs').insert({
    user_id: userId || null,
    email,
    status: 'sent',
    campaign_id: null,
    error_msg: null,
  })

  return NextResponse.json({ ok: true })
}
