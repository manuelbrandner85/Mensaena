import { NextRequest, NextResponse } from 'next/server'
import { AccessToken } from 'livekit-server-sdk'
import { getApiClient, err } from '@/lib/supabase/api-auth'

// Self-hosted LiveKit (primary) — configure via Cloudflare env vars when VPS is ready
const SELF_URL    = process.env.LIVEKIT_SELF_URL    || ''
const SELF_KEY    = process.env.LIVEKIT_SELF_KEY    || ''
const SELF_SECRET = process.env.LIVEKIT_SELF_SECRET || ''

// LiveKit Cloud (fallback)
const CLOUD_URL    = 'wss://mensaena-atyyhep6.livekit.cloud'
// FIX-15: Hardcoded credentials entfernt
const CLOUD_KEY    = process.env.LIVEKIT_API_KEY    ?? ''
const CLOUD_SECRET = process.env.LIVEKIT_API_SECRET ?? ''

function pickServer(): { url: string; key: string; secret: string } {
  if (SELF_URL && SELF_KEY && SELF_SECRET) {
    return { url: SELF_URL, key: SELF_KEY, secret: SELF_SECRET }
  }
  // FIX-15: Credentials-Validierung vor Token-Erstellung
  if (!CLOUD_KEY || !CLOUD_SECRET) {
    throw new Error('LiveKit credentials not configured')
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
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  let roomName: string
  let displayName: string
  let forceCloud: boolean
  try {
    const body = await req.json()
    roomName   = body.roomName    ?? ''
    displayName = body.displayName ?? 'Mitglied'
    forceCloud  = body.forceCloud  === true
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

  // FIX-15: Fehler bei fehlenden Credentials sauber abfangen
  try {
    // forceCloud: Cloud bevorzugen, aber bei fehlenden Cloud-Creds auf VPS ausweichen
    const { url, key, secret } = forceCloud && CLOUD_KEY && CLOUD_SECRET
      ? { url: CLOUD_URL, key: CLOUD_KEY, secret: CLOUD_SECRET }
      : pickServer()

    const at = new AccessToken(key, secret, {
      identity: user.id,
      name: displayName,
      ttl: '4h',
      metadata,
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
  } catch {
    return NextResponse.json(
      { error: 'Sprachanrufe sind derzeit nicht verfügbar' },
      { status: 500 },
    )
  }
}
