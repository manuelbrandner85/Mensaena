import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'
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

// POST /api/emails/welcome-all – Willkommensmail an alle aktiven Subscriber senden
// Nur Admin. Überspringt User, die bereits eine Willkommensmail erhalten haben.
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) {
    return err.forbidden()
  }

  // Alle aktiven Subscriber laden, deren welcome_sent_at noch null ist in email_preferences
  // Wir nutzen email_subscriptions + profiles für Namen
  const { data: subscribers, error: subErr } = await admin
    .from('email_subscriptions')
    .select('user_id, email, unsubscribe_token')
    .eq('subscribed', true)

  if (subErr) return err.internal(subErr.message)
  if (!subscribers?.length) {
    return NextResponse.json({ ok: true, sent: 0, message: 'Keine Subscriber' })
  }

  let sent = 0
  let failed = 0

  for (const sub of subscribers) {
    // Name aus Profil laden
    let displayName = ''
    if (sub.user_id) {
      const { data: prof } = await admin
        .from('profiles')
        .select('display_name, name')
        .eq('id', sub.user_id)
        .maybeSingle()
      displayName = prof?.display_name || prof?.name || ''
    }

    const unsubscribeUrl = `${BASE_URL}/unsubscribe?token=${sub.unsubscribe_token}`
    const { subject, html } = buildWelcomeEmail({ name: displayName, unsubscribeUrl })

    const result = await sendEmail({ to: sub.email, subject, html, fromName: 'Mensaena' })
    if (result.ok) {
      sent++
    } else {
      failed++
      console.error(`[welcome-all] failed for ${sub.email}:`, result.error)
    }

    // 200ms Delay
    await new Promise(r => setTimeout(r, 200))
  }

  return NextResponse.json({ ok: true, sent, failed, total: subscribers.length })
}
