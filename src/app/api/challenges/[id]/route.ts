import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'

// Service-Role-Key: Umgeht RLS für Admin-Operationen.
// Derselbe Key wie in /api/fix-rls – serverseitig-only, nie im Client.
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL
  || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY
  || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

// ── DELETE /api/challenges/[id] ────────────────────────────────────────────────
// Nur Admins und der ursprüngliche Ersteller dürfen löschen.
// Cascade: challenge_progress wird automatisch via ON DELETE CASCADE entfernt.
export async function DELETE(
  _req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  const { id } = await params
  if (!id) return err.bad('Challenge-ID fehlt')

  // ── 1. Challenge laden ──────────────────────────────────────────────────────
  const { data: challenge, error: fetchErr } = await supabase
    .from('challenges')
    .select('id, title, creator_id, participant_count')
    .eq('id', id)
    .single()

  if (fetchErr || !challenge) return err.notFound('Challenge nicht gefunden')

  // ── 2. Berechtigungsprüfung ────────────────────────────────────────────────
  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single()

  const isAdmin   = profile?.role === 'admin'
  const isCreator = challenge.creator_id === user.id

  if (!isAdmin && !isCreator) return err.forbidden()

  // ── 3. Löschen mit Service-Role (umgeht RLS) ──────────────────────────────
  // challenge_progress wird automatisch via ON DELETE CASCADE entfernt.
  const adminClient = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const { error: deleteErr } = await adminClient
    .from('challenges')
    .delete()
    .eq('id', id)

  if (deleteErr) return err.internal(deleteErr.message)

  return NextResponse.json({
    success: true,
    deleted: { id, title: challenge.title },
  })
}
