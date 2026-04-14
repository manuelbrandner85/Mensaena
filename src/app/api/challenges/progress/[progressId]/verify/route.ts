import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL
  || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY
  || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

// ── PATCH /api/challenges/progress/[progressId]/verify ───────────────────────
// Admin only: Eintrag in challenge_progress verifizieren oder ablehnen.
//
// Body:
//   verified  boolean  – true = bestätigt, false = abgelehnt / zurückgesetzt
//
// Logik:
//   - Setzt verified_by_admin auf den angegebenen Wert
//   - Service-Role umgeht RLS (nur Admin hat Schreibrecht per Policy)
export async function PATCH(
  req: Request,
  { params }: { params: Promise<{ progressId: string }> },
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  // ── Admin-Check ───────────────────────────────────────────────────────────
  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single()

  if (profile?.role !== 'admin') return err.forbidden()

  // ── Body validieren ───────────────────────────────────────────────────────
  const body = await req.json().catch(() => ({})) as { verified?: boolean }

  if (typeof body.verified !== 'boolean')
    return err.bad('verified (boolean) fehlt im Request-Body')

  const { progressId } = await params

  // ── Eintrag aktualisieren (Service-Role) ──────────────────────────────────
  const adminClient = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const { data: entry, error } = await adminClient
    .from('challenge_progress')
    .update({ verified_by_admin: body.verified })
    .eq('id', progressId)
    .select('id, challenge_id, user_id, date, checked_in, proof_image_url, verified_by_admin')
    .single()

  if (error) {
    if (error.code === 'PGRST116') return err.notFound('Eintrag nicht gefunden')
    return err.internal(error.message)
  }

  return NextResponse.json({
    entry,
    message: body.verified ? 'Eintrag verifiziert' : 'Verifikation zurückgezogen',
  })
}
