import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://gyqujitkvymlmgroovch.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''

let _admin: ReturnType<typeof createClient> | null = null
function admin() {
  if (!_admin) _admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } })
  return _admin
}

// GET /api/emails/confirm?token=xxx — Double-Opt-in Schritt 2 (öffentlich,
// Token-basiert). Aktiviert das E-Mail-Abo erst nach dem Bestätigungs-Klick.
export async function GET(req: NextRequest) {
  const token = req.nextUrl.searchParams.get('token')
  if (!token) {
    return NextResponse.json({ error: 'token required' }, { status: 400 })
  }

  const now = new Date().toISOString()
  const { data, error } = await admin()
    .from('email_subscriptions')
    .update({ subscribed: true, confirmed_at: now, unsubscribed_at: null })
    .eq('confirm_token', token)
    .select('user_id, email')
    .maybeSingle()

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
  if (!data) {
    return NextResponse.json({ error: 'Token nicht gefunden oder abgelaufen' }, { status: 404 })
  }

  // Spiegelt die Einwilligung in profiles + protokolliert den Nachweis.
  const uid = data.user_id as string
  await admin().from('profiles').update({ email_opt_in: true, email_opt_in_at: now }).eq('id', uid)
  await admin().from('consents').insert({
    user_id: uid,
    consent_type: 'email',
    granted: true,
    source: 'double_opt_in',
  })

  return NextResponse.json({ ok: true, email: data.email })
}
