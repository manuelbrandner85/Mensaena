import { NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

// POST /api/challenges/[id]/checkin
// Trägt einen täglichen Check-in ein. Funktioniert für Beitreten (erster Check-in)
// und für wiederholte tägliche Check-ins. Idempotent per Tag.
export async function POST(
  _req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  const { id: challengeId } = await params
  if (!challengeId) return err.bad('Challenge-ID fehlt')

  const today = new Date().toISOString().split('T')[0] // YYYY-MM-DD

  // Prüfen ob die Challenge existiert und aktiv ist
  const { data: challenge, error: challErr } = await supabase
    .from('challenges')
    .select('id, participant_count, status, end_date')
    .eq('id', challengeId)
    .single()

  if (challErr || !challenge) return err.notFound('Challenge nicht gefunden')
  if (challenge.status !== 'active') return err.bad('Challenge ist nicht aktiv')
  if (new Date(challenge.end_date) < new Date()) return err.bad('Challenge ist abgelaufen')

  // Prüfen ob der User heute schon eingecheckt hat
  const { data: existingToday } = await supabase
    .from('challenge_progress')
    .select('id')
    .eq('challenge_id', challengeId)
    .eq('user_id', user.id)
    .eq('date', today)
    .maybeSingle()

  if (existingToday) {
    return NextResponse.json({ alreadyCheckedIn: true, message: 'Heute bereits eingecheckt' })
  }

  // Prüfen ob der User schon früher an dieser Challenge teilgenommen hat
  const { data: existingProgress } = await supabase
    .from('challenge_progress')
    .select('id')
    .eq('challenge_id', challengeId)
    .eq('user_id', user.id)
    .limit(1)
    .maybeSingle()

  const isFirstCheckin = !existingProgress

  // Check-in für heute eintragen
  const { error: insertErr } = await supabase
    .from('challenge_progress')
    .insert({
      challenge_id: challengeId,
      user_id: user.id,
      date: today,
      checked_in: true,
      verified_by_admin: false,
    })

  if (insertErr) return err.internal(insertErr.message)

  // participant_count erhöhen wenn erster Check-in
  if (isFirstCheckin) {
    await supabase
      .from('challenges')
      .update({ participant_count: (challenge.participant_count ?? 0) + 1 })
      .eq('id', challengeId)
  }

  return NextResponse.json({
    success: true,
    joined: isFirstCheckin,
    checkedIn: true,
    date: today,
  })
}
