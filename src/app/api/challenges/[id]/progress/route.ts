import { NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'
import { calcStreak } from '../checkin/route'

// ── GET /api/challenges/[id]/progress ────────────────────────────────────────
// Vollständiger Fortschritt des eingeloggten Users für diese Challenge.
//
// Response:
//   isParticipant    boolean  – hat der User mindestens einen Eintrag?
//   checkedInToday   boolean  – heute bereits eingecheckt?
//   streak           number   – aktuelle Streak-Länge in Tagen
//   totalCheckins    number   – Gesamtzahl verifizierbarer Check-ins
//   verifiedCount    number   – Anzahl admin-verifizierter Einträge
//   entries          Array    – alle Einträge (für Tages-Grid im Frontend)
//   challenge        Object   – Basis-Infos der Challenge (Titel, Daten)
export async function GET(
  _req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  const { id }  = await params
  const today   = new Date().toISOString().split('T')[0]

  // Parallel: Challenge + eigene Einträge
  const [challengeRes, entriesRes] = await Promise.all([
    supabase
      .from('challenges')
      .select('id, title, category, start_date, end_date, status, points, difficulty')
      .eq('id', id)
      .single(),
    supabase
      .from('challenge_progress')
      .select('id, date, checked_in, proof_image_url, verified_by_admin, created_at')
      .eq('challenge_id', id)
      .eq('user_id', user.id)
      .order('date', { ascending: true }),
  ])

  if (!challengeRes.data) return err.notFound('Challenge nicht gefunden')

  const entries      = entriesRes.data ?? []
  const checkedDates = entries.filter(e => e.checked_in).map(e => e.date as string)
  const streak       = calcStreak(checkedDates)

  // Gesamttage der Challenge für Fortschritts-%
  const startDate  = new Date(challengeRes.data.start_date)
  const endDate    = new Date(challengeRes.data.end_date)
  const totalDays  = Math.max(
    1,
    Math.round((endDate.getTime() - startDate.getTime()) / 86_400_000) + 1,
  )
  const progressPct = Math.min(100, Math.round((checkedDates.length / totalDays) * 100))

  return NextResponse.json({
    challenge:      challengeRes.data,
    isParticipant:  entries.length > 0,
    checkedInToday: checkedDates.includes(today),
    streak,
    totalCheckins:  checkedDates.length,
    verifiedCount:  entries.filter(e => e.verified_by_admin).length,
    totalDays,
    progressPct,
    entries,
  })
}
