// FIX-110: LiveKit Token-Helper – nur Self-Hosted VPS, keine Cloud-Variablen.
// Verwendet lightweight JWT-Generator statt livekit-server-sdk.

import { createLivekitToken } from '@/lib/livekit-jwt'

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

  const token = await createLivekitToken(SELF_KEY, SELF_SECRET, {
    identity: input.identity,
    name: input.displayName,
    ttl: 4 * 3600,
    ...(input.metadata ? { metadata: input.metadata } : {}),
    grant: {
      room: input.roomName,
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    },
  })

  return { token, url: SELF_URL, roomName: input.roomName }
}
