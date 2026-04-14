import { NextRequest, NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

// GET /api/zeitbank/notifications
// Offene Bestätigungs-Anfragen und Statusmeldungen des eingeloggten Users
// Query-Params:
//   ?unseen=true   → nur ungesehene Notifications
export async function GET(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  const unseenOnly = req.nextUrl.searchParams.get('unseen') === 'true'

  let query = supabase
    .from('zeitbank_notifications')
    .select(`
      id,
      type,
      message,
      seen,
      clicked,
      created_at,
      entry:entry_id (
        id,
        hours,
        description,
        help_date,
        status,
        giver:giver_id (id, name, nickname, avatar_url),
        receiver:receiver_id (id, name, nickname, avatar_url)
      )
    `)
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(50)

  if (unseenOnly) query = query.eq('seen', false)

  const { data, error } = await query
  if (error) return err.internal(error.message)

  return NextResponse.json({ data: data ?? [] })
}
