import { NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

// Streak aus sortierten Datums-Strings berechnen
function calcStreak(checkedDates: string[]): number {
  if (!checkedDates.length) return 0
  const set = new Set(checkedDates)
  const today = new Date()
  let streak = 0
  let d = new Date(today)

  // Falls heute noch nicht eingecheckt: von gestern starten
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
// Gibt alle Einträge des Users für diese Challenge zurück
// + berechneten Streak + ob heute bereits eingecheckt
export async function GET(
  _req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  const { id } = await params
  const today = new Date().toISOString().split('T')[0]

  const { data: rows, error } = await supabase
    .from('challenge_progress')
    .select('id, date, checked_in, proof_image_url, verified_by_admin, created_at')
    .eq('challenge_id', id)
    .eq('user_id', user.id)
    .order('date', { ascending: true })

  if (error) return err.internal(error.message)

  const entries        = rows ?? []
  const checkedDates   = entries.filter(r => r.checked_in).map(r => r.date as string)
  const checkedInToday = checkedDates.includes(today)
  const streak         = calcStreak(checkedDates)
  const totalCheckins  = checkedDates.length

  return NextResponse.json({ entries, streak, totalCheckins, checkedInToday })
}

// ── POST /api/challenges/[id]/checkin ────────────────────────────────────────
// Erstellt oder aktualisiert den heutigen Eintrag auf checked_in = true
// UNIQUE(challenge_id, user_id, date) verhindert Doppel-Check-ins
export async function POST(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  const { id } = await params
  const body   = await req.json().catch(() => ({})) as { proof_image_url?: string | null }
  const today  = new Date().toISOString().split('T')[0]

  // Challenge existiert?
  const { data: challenge } = await supabase
    .from('challenges')
    .select('id, end_date')
    .eq('id', id)
    .single()

  if (!challenge) return err.notFound('Challenge nicht gefunden')
  if (new Date(challenge.end_date) < new Date()) return err.bad('Challenge ist bereits beendet')

  // Upsert: Insert oder Update bei gleichem (challenge_id, user_id, date)
  const { data: entry, error } = await supabase
    .from('challenge_progress')
    .upsert(
      {
        challenge_id:     id,
        user_id:          user.id,
        date:             today,
        checked_in:       true,
        proof_image_url:  body.proof_image_url ?? null,
      },
      { onConflict: 'challenge_id,user_id,date' },
    )
    .select()
    .single()

  if (error) return err.internal(error.message)

  // Streak neu berechnen
  const { data: allRows } = await supabase
    .from('challenge_progress')
    .select('date, checked_in')
    .eq('challenge_id', id)
    .eq('user_id', user.id)
    .eq('checked_in', true)

  const checkedDates = (allRows ?? []).map(r => r.date as string)
  const streak       = calcStreak(checkedDates)

  return NextResponse.json({ entry, streak, totalCheckins: checkedDates.length })
}
