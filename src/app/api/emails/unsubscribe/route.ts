import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''

let _admin: ReturnType<typeof createClient> | null = null
function admin() {
  if (!_admin) _admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } })
  return _admin
}

// GET /api/emails/unsubscribe?token=xxx – öffentlich, kein Auth nötig
export async function GET(req: NextRequest) {
  const token = req.nextUrl.searchParams.get('token')
  if (!token) {
    return NextResponse.json({ error: 'token required' }, { status: 400 })
  }

  const { data, error } = await admin()
    .from('email_subscriptions')
    .update({ subscribed: false, unsubscribed_at: new Date().toISOString() })
    .eq('unsubscribe_token', token)
    .select('email')
    .maybeSingle()

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
  if (!data) {
    return NextResponse.json({ error: 'Token nicht gefunden' }, { status: 404 })
  }

  return NextResponse.json({ ok: true, email: data.email })
}

// PATCH /api/emails/unsubscribe – eingeloggter User schaltet eigene Subscription um
export async function PATCH(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  let body: { subscribed?: boolean }
  try { body = await req.json() } catch { return err.bad('Invalid body') }

  const subscribed = body.subscribed ?? false

  const { error } = await supabase
    .from('email_subscriptions')
    .update({
      subscribed,
      unsubscribed_at: subscribed ? null : new Date().toISOString(),
    })
    .eq('user_id', user.id)

  if (error) return err.internal(error.message)
  return NextResponse.json({ ok: true })
}
