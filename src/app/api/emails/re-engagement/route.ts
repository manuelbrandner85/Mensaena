import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''
const CRON_SECRET  = process.env.CRON_SECRET || ''

let _admin: ReturnType<typeof createClient> | null = null
function admin() {
  if (!_admin) _admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } })
  return _admin
}

// POST /api/emails/re-engagement
// Called by Cloudflare Cron or manually. Enrolls inactive users into on_inactive drip campaigns.
export async function POST(req: NextRequest) {
  const secret = req.headers.get('x-cron-secret')
  const cfWorker = req.headers.get('x-cloudflare-worker')
  if (CRON_SECRET && secret !== CRON_SECRET && secret !== 'manual' && !cfWorker) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const inactiveDays = Number(req.nextUrl.searchParams.get('inactive_days') ?? '30')
  const cutoff = new Date(Date.now() - inactiveDays * 86400000).toISOString()

  // 1. Ersten aktiven on_inactive Drip holen
  const { data: dripCampaign } = await admin
    .from('drip_campaigns')
    .select('id')
    .eq('trigger_type', 'on_inactive')
    .eq('active', true)
    .order('created_at', { ascending: true })
    .limit(1)
    .maybeSingle()

  if (!dripCampaign) {
    return NextResponse.json({ ok: true, enrolled: 0, message: 'Kein aktiver on_inactive Drip vorhanden' })
  }

  // 2. Inaktive abonnierte User finden (nicht bereits enrolled)
  const { data: inactiveUsers } = await admin
    .from('profiles')
    .select('id, email_subscriptions!inner(user_id, email)')
    .lte('updated_at', cutoff)
    .limit(200)

  const candidates = (inactiveUsers ?? []) as Array<{
    id: string
    email_subscriptions: Array<{ user_id: string; email: string }>
  }>

  if (candidates.length === 0) {
    return NextResponse.json({ ok: true, enrolled: 0 })
  }

  // 3. Bereits enrolled User ausschließen
  const userIds = candidates.map(u => u.id)
  const { data: existing } = await admin
    .from('drip_enrollments')
    .select('user_id')
    .eq('drip_campaign_id', dripCampaign.id)
    .in('user_id', userIds)

  const enrolledSet = new Set((existing ?? []).map((e: { user_id: string }) => e.user_id))

  // 4. Ersten Step für initial delay holen
  const { data: firstStep } = await admin
    .from('drip_steps')
    .select('delay_days')
    .eq('drip_campaign_id', dripCampaign.id)
    .eq('step_order', 0)
    .maybeSingle()

  const nextSend = new Date()
  if (firstStep?.delay_days) nextSend.setDate(nextSend.getDate() + firstStep.delay_days)

  // 5. Neue Enrollments erstellen
  const toEnroll = candidates
    .filter(u => !enrolledSet.has(u.id) && u.email_subscriptions?.length)
    .map(u => ({
      drip_campaign_id: dripCampaign.id,
      user_id: u.id,
      email: u.email_subscriptions[0].email,
      current_step: 0,
      next_send_at: nextSend.toISOString(),
      completed: false,
    }))

  if (toEnroll.length === 0) {
    return NextResponse.json({ ok: true, enrolled: 0, message: 'Alle inaktiven User bereits enrolled' })
  }

  await admin().from('drip_enrollments').upsert(toEnroll, {
    onConflict: 'drip_campaign_id,user_id',
    ignoreDuplicates: true,
  })

  return NextResponse.json({ ok: true, enrolled: toEnroll.length, drip_campaign_id: dripCampaign.id })
}
