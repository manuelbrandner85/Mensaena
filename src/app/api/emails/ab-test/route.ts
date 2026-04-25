import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

// POST /api/emails/ab-test
// Body: { campaign_id, subject_a, subject_b, split_pct? }
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) return err.forbidden()

  const { campaign_id, subject_a, subject_b, split_pct = 10 } = await req.json().catch(() => ({}))
  if (!campaign_id || !subject_a || !subject_b) return err.bad('campaign_id, subject_a, subject_b erforderlich')

  const { data, error } = await admin.from('ab_tests').upsert({
    campaign_id,
    subject_a,
    subject_b,
    split_pct: Math.min(50, Math.max(5, split_pct)),
    status: 'running',
    resolve_at: new Date(Date.now() + 4 * 3600000).toISOString(),
  }, { onConflict: 'campaign_id' }).select().single()

  if (error) return err.internal(error.message)
  return NextResponse.json({ ok: true, ab_test: data })
}

// GET /api/emails/ab-test?campaign_id=xxx
export async function GET(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) return err.forbidden()

  const campaign_id = req.nextUrl.searchParams.get('campaign_id')
  if (!campaign_id) return err.bad('campaign_id fehlt')

  const { data, error } = await admin.from('ab_tests').select('*').eq('campaign_id', campaign_id).maybeSingle()
  if (error) return err.internal(error.message)
  return NextResponse.json({ ab_test: data })
}

// PATCH /api/emails/ab-test — Gewinner manuell setzen
export async function PATCH(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) return err.forbidden()

  const { campaign_id, winner } = await req.json().catch(() => ({}))
  if (!campaign_id || !winner) return err.bad('campaign_id und winner (a|b) erforderlich')

  const { data: test } = await admin.from('ab_tests').select('subject_a, subject_b').eq('campaign_id', campaign_id).maybeSingle()
  if (!test) return err.notFound('A/B-Test nicht gefunden')

  const winningSubject = winner === 'a' ? test.subject_a : test.subject_b
  await admin.from('ab_tests').update({ winner, status: 'resolved' }).eq('campaign_id', campaign_id)
  await admin.from('email_campaigns').update({ subject: winningSubject }).eq('id', campaign_id)

  return NextResponse.json({ ok: true, winner, winning_subject: winningSubject })
}
