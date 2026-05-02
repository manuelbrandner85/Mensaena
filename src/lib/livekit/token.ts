import { AccessToken } from 'livekit-server-sdk'

/**
 * Internal LiveKit token-generation helper used by DM-call routes.
 * Mirrors the logic in /api/live-room/token but is callable server-side
 * without an HTTP round-trip.
 */

const SELF_URL    = process.env.LIVEKIT_SELF_URL    || ''
const SELF_KEY    = process.env.LIVEKIT_SELF_KEY    || ''
const SELF_SECRET = process.env.LIVEKIT_SELF_SECRET || ''

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

export interface LiveKitTokenInput {
  roomName: string
  identity: string
  displayName: string
  metadata?: string
}

export interface LiveKitTokenResult {
  token: string
  url: string
  roomName: string
}

/**
 * Erzeugt einen LiveKit-JWT für einen DM-Call.
 * Verwendet Self-Hosted-Server wenn konfiguriert, sonst Cloud-Fallback.
 */
export async function generateLiveKitToken(input: LiveKitTokenInput): Promise<LiveKitTokenResult> {
  const { url, key, secret } = pickServer()
  const at = new AccessToken(key, secret, {
    identity: input.identity,
    name: input.displayName,
    ttl: 60 * 60 * 4,
    ...(input.metadata ? { metadata: input.metadata } : {}),
  })
  at.addGrant({
    room: input.roomName,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true,
  })
  const token = await at.toJwt()
  return { token, url, roomName: input.roomName }
}
