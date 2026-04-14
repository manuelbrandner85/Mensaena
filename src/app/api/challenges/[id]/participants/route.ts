import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL
  || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY
  || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

function calcStreak(checkedDates: string[]): number {
  if (!checkedDates.length) return 0
  const set  = new Set(checkedDates)
  const today = new Date()
  let streak  = 0
  let d       = new Date(today)

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

// ── GET /api/challenges/[id]/participants ─────────────────────────────────────
// Admin only: alle Teilnehmer mit Fortschritts-Daten
export async function GET(
  _req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single()

  if (profile?.role !== 'admin') return err.forbidden()

  const { id } = await params

  const adminClient = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  // Alle Einträge dieser Challenge laden
  const { data: rows, error } = await adminClient
    .from('challenge_progress')
    .select('id, user_id, date, checked_in, proof_image_url, verified_by_admin, created_at')
    .eq('challenge_id', id)
    .order('date', { ascending: true })

  if (error) return err.internal(error.message)

  // Profilinfos separat laden (kein embedded join wegen RLS)
  const userIds = [...new Set((rows ?? []).map(r => r.user_id))]
  const { data: profilesData } = await adminClient
    .from('profiles')
    .select('id, name, avatar_url')
    .in('id', userIds)

  const profileMap = new Map((profilesData ?? []).map(p => [p.id, p]))

  // Einträge nach User gruppieren + Statistiken berechnen
  const byUser = new Map<string, typeof rows>()
  ;(rows ?? []).forEach(r => {
    const arr = byUser.get(r.user_id) ?? []
    arr.push(r)
    byUser.set(r.user_id, arr)
  })

  const participants = [...byUser.entries()].map(([userId, entries]) => {
    const checkedDates   = entries.filter(e => e.checked_in).map(e => e.date as string)
    const lastCheckin    = checkedDates.at(-1) ?? null
    const streak         = calcStreak(checkedDates)
    const totalCheckins  = checkedDates.length
    const verifiedCount  = entries.filter(e => e.verified_by_admin).length

    return {
      user_id:        userId,
      profile:        profileMap.get(userId) ?? null,
      streak,
      totalCheckins,
      verifiedCount,
      lastCheckinDate: lastCheckin,
      entries,
    }
  })

  return NextResponse.json({ participants })
}
