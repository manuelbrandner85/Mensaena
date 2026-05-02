import { AccessToken } from 'livekit-server-sdk'

const SELF_URL    = process.env.LIVEKIT_SELF_URL    || ''
const SELF_KEY    = process.env.LIVEKIT_SELF_KEY    || ''
const SELF_SECRET = process.env.LIVEKIT_SELF_SECRET || ''

function pickServer(): { url: string; key: string; secret: string } {
  if (!SELF_URL || !SELF_KEY || !SELF_SECRET) {
    throw new Error('LiveKit VPS credentials not configured (LIVEKIT_SELF_URL/KEY/SECRET)')
  }
  return { url: SELF_URL, key: SELF_KEY, secret: SELF_SECRET }
}

export interface LiveKitTokenInput {
  roomName: string
  identity: string
  displayName: string
  metadata?: string
  forceCloud?: boolean
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
  const { url, key, secret } = input.forceCloud && CLOUD_KEY && CLOUD_SECRET
    ? { url: CLOUD_URL, key: CLOUD_KEY, secret: CLOUD_SECRET }
    : pickServer()
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
