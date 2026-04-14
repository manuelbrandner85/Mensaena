import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL
  || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY
  || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

// ── Hilfsfunktion: Streak aus Check-in-Daten berechnen ───────────────────────
export function calcStreak(checkedDates: string[]): number {
  if (!checkedDates.length) return 0
  const set   = new Set(checkedDates)
  let streak  = 0
  let d       = new Date()

  // Heute noch nicht eingecheckt → von gestern starten
  if (!set.has(d.toISOString().split('T')[0])) {
    d.setDate(d.getDate() - 1)
    if (!set.has(d.toISOString().split('T')[0])) return 0
    streak = 1
    d.setDate(d.getDate() - 1)
  } else {
    streak = 1
    d.setDate(d.getDate() - 1)
  }

  while (set.has(d.toISOString().split('T')[0])) {
    streak++
    d.setDate(d.getDate() - 1)
  }
  return streak
}

// ── GET /api/challenges/[id]/checkin ─────────────────────────────────────────
// Eigene Check-in-Einträge + Statistiken für diese Challenge
export async function GET(
  _req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  const { id }  = await params
  const today   = new Date().toISOString().split('T')[0]

  const { data: rows, error } = await supabase
    .from('challenge_progress')
    .select('id, date, checked_in, proof_image_url, verified_by_admin, created_at')
    .eq('challenge_id', id)
    .eq('user_id', user.id)
    .order('date', { ascending: true })

  if (error) return err.internal(error.message)

  const entries       = rows ?? []
  const checkedDates  = entries.filter(r => r.checked_in).map(r => r.date as string)
  const streak        = calcStreak(checkedDates)

  return NextResponse.json({
    entries,
    streak,
    totalCheckins:  checkedDates.length,
    checkedInToday: checkedDates.includes(today),
    isParticipant:  entries.length > 0,
  })
}

// ── POST /api/challenges/[id]/checkin ────────────────────────────────────────
// Checkt den User für heute ein (max. 1× pro Tag).
// Beim ersten Check-in wird participant_count auf challenges inkrementiert.
// Body (optional): { proof_image_url?: string }
export async function POST(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  const { id }  = await params
  const body    = await req.json().catch(() => ({})) as { proof_image_url?: string | null }
  const today   = new Date().toISOString().split('T')[0]

  // ── 1. Challenge-Status prüfen ────────────────────────────────────────────
  const { data: challenge } = await supabase
    .from('challenges')
    .select('id, end_date, participant_count')
    .eq('id', id)
    .single()

  if (!challenge) return err.notFound('Challenge nicht gefunden')
  if (new Date(challenge.end_date) < new Date())
    return err.bad('Challenge ist bereits beendet')

  // ── 2. Erstteilnahme erkennen (für participant_count) ────────────────────
  const { count: priorRows } = await supabase
    .from('challenge_progress')
    .select('id', { count: 'exact', head: true })
    .eq('challenge_id', id)
    .eq('user_id', user.id)

  const isFirstEntry = (priorRows ?? 0) === 0

  // ── 3. Heutigen Eintrag anlegen / aktualisieren ───────────────────────────
  const { data: entry, error } = await supabase
    .from('challenge_progress')
    .upsert(
      {
        challenge_id:    id,
        user_id:         user.id,
        date:            today,
        checked_in:      true,
        proof_image_url: body.proof_image_url ?? null,
      },
      { onConflict: 'challenge_id,user_id,date' },
    )
    .select()
    .single()

  if (error) return err.internal(error.message)

  // ── 4. participant_count inkrementieren (Service-Role, umgeht RLS) ────────
  if (isFirstEntry) {
    const adminClient = createClient(SUPABASE_URL, SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    })
    await adminClient
      .from('challenges')
      .update({ participant_count: (challenge.participant_count ?? 0) + 1 })
      .eq('id', id)
  }

  // ── 5. Aktuellen Streak zurückgeben ───────────────────────────────────────
  const { data: allChecked } = await supabase
    .from('challenge_progress')
    .select('date')
    .eq('challenge_id', id)
    .eq('user_id', user.id)
    .eq('checked_in', true)

  const checkedDates = (allChecked ?? []).map(r => r.date as string)
  const streak       = calcStreak(checkedDates)

  return NextResponse.json({
    entry,
    streak,
    totalCheckins: checkedDates.length,
    isNewParticipant: isFirstEntry,
  })
}
