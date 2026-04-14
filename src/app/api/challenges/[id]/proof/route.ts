import { NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

// ── POST /api/challenges/[id]/proof ──────────────────────────────────────────
// Hängt eine Beweis-URL an einen bestehenden Check-in-Eintrag.
//
// Der Client lädt das Bild direkt in den Supabase-Storage-Bucket
// 'challenge-proofs' hoch und schickt die resultierende Public-URL hierher.
//
// Body:
//   proof_image_url  string   – öffentliche URL des hochgeladenen Bildes
//   date?            string   – YYYY-MM-DD, Default: heute
//
// Validierung:
//   - User muss für das Datum bereits eingecheckt sein (checked_in = true)
//   - Challenge darf nicht abgelaufen sein
export async function POST(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  const { id } = await params
  const body   = await req.json().catch(() => ({})) as {
    proof_image_url?: string
    date?: string
  }

  if (!body.proof_image_url?.trim())
    return err.bad('proof_image_url fehlt')

  const targetDate = body.date ?? new Date().toISOString().split('T')[0]

  // ── 1. Challenge aktiv? ───────────────────────────────────────────────────
  const { data: challenge } = await supabase
    .from('challenges')
    .select('id, end_date')
    .eq('id', id)
    .single()

  if (!challenge) return err.notFound('Challenge nicht gefunden')
  if (new Date(challenge.end_date) < new Date())
    return err.bad('Challenge ist bereits beendet')

  // ── 2. User-Check-in für dieses Datum vorhanden? ──────────────────────────
  const { data: existing } = await supabase
    .from('challenge_progress')
    .select('id, checked_in')
    .eq('challenge_id', id)
    .eq('user_id', user.id)
    .eq('date', targetDate)
    .single()

  if (!existing)
    return err.bad(`Kein Check-in für ${targetDate} gefunden. Bitte erst einchecken.`)

  if (!existing.checked_in)
    return err.bad('Check-in für dieses Datum ist nicht bestätigt.')

  // ── 3. Beweis-URL speichern ───────────────────────────────────────────────
  const { data: entry, error } = await supabase
    .from('challenge_progress')
    .update({ proof_image_url: body.proof_image_url.trim() })
    .eq('id', existing.id)
    .select()
    .single()

  if (error) return err.internal(error.message)

  return NextResponse.json({ entry })
}
