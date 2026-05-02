import { NextRequest, NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'
import { generateLiveKitToken } from '@/lib/livekit/token'

export const runtime = 'nodejs'

export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  let roomName: string
  let displayName: string
  try {
    const body = await req.json()
    roomName    = body.roomName    ?? ''
    displayName = body.displayName ?? 'Mitglied'
  } catch {
    return err.bad('Ungültiger Body')
  }
  if (!roomName) return err.bad('roomName fehlt')

  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .maybeSingle()
  const metadata = JSON.stringify({ role: (profile as { role?: string } | null)?.role ?? 'user' })

  try {
    const result = await generateLiveKitToken({ roomName, identity: user.id, displayName, metadata }) // FIX-99: forceCloud entfernt
    return NextResponse.json({ token: result.token, url: result.url })
  } catch {
    return NextResponse.json({ error: 'LiveKit nicht verfügbar' }, { status: 500 })
  }
}
