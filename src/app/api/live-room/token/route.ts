// FIX-110: VPS-only Token-Endpoint, kein Cloud-Fallback, kein forceCloud.

import { NextRequest, NextResponse } from 'next/server'
import { createLivekitToken } from '@/lib/livekit-jwt'
import { getApiClient, err } from '@/lib/supabase/api-auth'

export const runtime = 'nodejs'

const SELF_URL    = process.env.LIVEKIT_SELF_URL    || ''
const SELF_KEY    = process.env.LIVEKIT_SELF_KEY    || ''
const SELF_SECRET = process.env.LIVEKIT_SELF_SECRET || ''

/**
 * POST /api/live-room/token
 * Returns a LiveKit JWT + the server URL.
 * Body: { roomName: string, displayName?: string }
 */
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  if (!SELF_URL || !SELF_KEY || !SELF_SECRET) {
    return NextResponse.json(
      { error: 'LiveKit nicht konfiguriert (LIVEKIT_SELF_URL/KEY/SECRET)' },
      { status: 500 },
    )
  }

  let roomName: string
  let displayName: string
  try {
    const body = await req.json()
    roomName   = body.roomName    ?? ''
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
    const token = await createLivekitToken(SELF_KEY, SELF_SECRET, {
      identity: user.id,
      name: displayName,
      ttl: 4 * 3600,
      metadata,
      grant: {
        roomJoin: true,
        room: roomName,
        canPublish: true,
        canSubscribe: true,
        canPublishData: true,
      },
    })
    return NextResponse.json({ token, url: SELF_URL })
  } catch (e) {
    return NextResponse.json(
      { error: (e as Error)?.message ?? 'Token konnte nicht erstellt werden' },
      { status: 500 },
    )
  }
}
