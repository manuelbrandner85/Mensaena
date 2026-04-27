import { NextRequest, NextResponse } from 'next/server'
import { AccessToken } from 'livekit-server-sdk'
import { getApiClient, err } from '@/lib/supabase/api-auth'

const LIVEKIT_API_KEY    = process.env.LIVEKIT_API_KEY    || 'API6xiELPJspzGZ'
const LIVEKIT_API_SECRET = process.env.LIVEKIT_API_SECRET || 'wj4aGfeSEKXezVovVyofmfE53Ew0vWQQjFJGhhOsHtnG'

/**
 * POST /api/live-room/token
 *
 * Generates a LiveKit JWT for the authenticated user to join a room.
 * Body: { roomName: string, displayName?: string }
 */
export async function POST(req: NextRequest) {
  const { user } = await getApiClient()
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

  const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
    identity: user.id,
    name: displayName,
    ttl: '4h',
  })
  at.addGrant({
    roomJoin: true,
    room: roomName,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true,
  })

  const token = await at.toJwt()
  return NextResponse.json({ token })
}
