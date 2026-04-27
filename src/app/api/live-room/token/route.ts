import { NextRequest, NextResponse } from 'next/server'
import { AccessToken } from 'livekit-server-sdk'
import { getApiClient, err } from '@/lib/supabase/api-auth'

// Self-hosted LiveKit (primary) — set via Cloudflare env vars after VPS setup
const SELF_URL    = process.env.LIVEKIT_SELF_URL    || ''
const SELF_KEY    = process.env.LIVEKIT_SELF_KEY    || ''
const SELF_SECRET = process.env.LIVEKIT_SELF_SECRET || ''

// LiveKit Cloud (fallback)
const CLOUD_URL    = 'wss://mensaena-atyyhep6.livekit.cloud'
const CLOUD_KEY    = process.env.LIVEKIT_API_KEY    || 'API6xiELPJspzGZ'
const CLOUD_SECRET = process.env.LIVEKIT_API_SECRET || 'wj4aGfeSEKXezVovVyofmfE53Ew0vWQQjFJGhhOsHtnG'

function pickServer(): { url: string; key: string; secret: string } {
  if (SELF_URL && SELF_KEY && SELF_SECRET) {
    return { url: SELF_URL, key: SELF_KEY, secret: SELF_SECRET }
  }
  return { url: CLOUD_URL, key: CLOUD_KEY, secret: CLOUD_SECRET }
}

/**
 * POST /api/live-room/token
 *
 * Returns a LiveKit JWT + the server URL the client should connect to.
 * Uses self-hosted VPS when configured, falls back to LiveKit Cloud.
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

  const { url, key, secret } = pickServer()

  const at = new AccessToken(key, secret, {
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
  return NextResponse.json({ token, url })
}
