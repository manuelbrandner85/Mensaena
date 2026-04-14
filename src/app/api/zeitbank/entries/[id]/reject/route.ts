import { NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

// PATCH /api/zeitbank/entries/[id]/reject
// Nur der Empfänger (helped) darf ablehnen
export async function PATCH(
  _req: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  const { id } = await params

  // Eintrag laden und prüfen
  const { data: entry, error: fetchErr } = await supabase
    .from('timebank_entries')
    .select('id, giver_id, receiver_id, status, hours')
    .eq('id', id)
    .single()

  if (fetchErr || !entry) return err.notFound('Eintrag nicht gefunden')
  if (entry.receiver_id !== user.id) return err.forbidden()
  if (entry.status !== 'pending')
    return err.conflict('Eintrag ist nicht mehr ausstehend')

  // Ablehnen
  const { error } = await supabase
    .from('timebank_entries')
    .update({ status: 'rejected' })
    .eq('id', id)

  if (error) return err.internal(error.message)

  // Notification für den Helfer
  await supabase.from('zeitbank_notifications').insert({
    user_id:  entry.giver_id,
    entry_id: id,
    type:     'rejected',
    message:  `Deine eingetragene Hilfe von ${entry.hours} Std. wurde leider abgelehnt.`,
  })

  return NextResponse.json({ data: { id, status: 'rejected' } })
}
