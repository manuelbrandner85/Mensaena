import { NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

// GET /api/zeitbank/balance
// Eigenes Zeitkonto: geleistete vs. erhaltene Stunden + Saldo
export async function GET() {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  const [givenRes, receivedRes, pendingGiverRes, pendingReceiverRes, communityRes] =
    await Promise.all([
      supabase
        .from('timebank_entries')
        .select('hours')
        .eq('giver_id', user.id)
        .eq('status', 'confirmed'),
      supabase
        .from('timebank_entries')
        .select('hours')
        .eq('receiver_id', user.id)
        .eq('status', 'confirmed'),
      supabase
        .from('timebank_entries')
        .select('*', { count: 'exact', head: true })
        .eq('giver_id', user.id)
        .eq('status', 'pending'),
      supabase
        .from('timebank_entries')
        .select('*', { count: 'exact', head: true })
        .eq('receiver_id', user.id)
        .eq('status', 'pending'),
      supabase
        .from('timebank_entries')
        .select('hours')
        .eq('status', 'confirmed'),
    ])

  const sum = (rows: { hours: number }[] | null) =>
    Math.round(((rows ?? []).reduce((s, r) => s + r.hours, 0)) * 10) / 10

  const given    = sum(givenRes.data)
  const received = sum(receivedRes.data)
  const balance  = Math.round((given - received) * 10) / 10

  return NextResponse.json({
    data: {
      given,
      received,
      balance,
      pending_as_helper:  pendingGiverRes.count    ?? 0,
      pending_as_helped:  pendingReceiverRes.count ?? 0,
      community_total:    sum(communityRes.data),
    },
  })
}
