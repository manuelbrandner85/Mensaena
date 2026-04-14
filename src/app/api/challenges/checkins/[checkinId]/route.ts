import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL
  || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY
  || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

// ── PATCH /api/challenges/checkins/[checkinId] ────────────────────────────────
// Admin only: Eintrag in challenge_progress verifizieren oder ablehnen
// Body: { verified_by_admin: boolean }
export async function PATCH(
  req: Request,
  { params }: { params: Promise<{ checkinId: string }> },
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single()

  if (profile?.role !== 'admin') return err.forbidden()

  const { checkinId } = await params
  const body = await req.json().catch(() => ({})) as { verified_by_admin?: boolean }

  if (typeof body.verified_by_admin !== 'boolean') {
    return err.bad('verified_by_admin (boolean) fehlt')
  }

  const adminClient = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const { data: entry, error } = await adminClient
    .from('challenge_progress')
    .update({ verified_by_admin: body.verified_by_admin })
    .eq('id', checkinId)
    .select()
    .single()

  if (error) return err.internal(error.message)

  return NextResponse.json({ entry })
}
