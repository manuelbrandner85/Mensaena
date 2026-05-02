// FIX-110: LiveKit Token-Helper – nur Self-Hosted VPS, keine Cloud-Variablen.
// Wird server-side aufgerufen (DM-Call-Routes) ohne HTTP-Round-Trip.

import { AccessToken } from 'livekit-server-sdk'

const SELF_URL    = process.env.LIVEKIT_SELF_URL    || ''
const SELF_KEY    = process.env.LIVEKIT_SELF_KEY    || ''
const SELF_SECRET = process.env.LIVEKIT_SELF_SECRET || ''

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

export async function generateLiveKitToken(input: LiveKitTokenInput): Promise<LiveKitTokenResult> {
  if (!SELF_URL || !SELF_KEY || !SELF_SECRET) {
    throw new Error('LiveKit credentials nicht konfiguriert (LIVEKIT_SELF_URL/KEY/SECRET)')
  }

  const at = new AccessToken(SELF_KEY, SELF_SECRET, {
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
  return { token, url: SELF_URL, roomName: input.roomName }
}
