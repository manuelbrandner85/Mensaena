import { AccessToken } from 'livekit-server-sdk'

// ── Server-Konfiguration ──────────────────────────────────────
const SELF_URL    = process.env.LIVEKIT_SELF_URL    || ''
const SELF_KEY    = process.env.LIVEKIT_SELF_KEY    || ''
const SELF_SECRET = process.env.LIVEKIT_SELF_SECRET || ''

const CLOUD_URL    = 'wss://mensaena-atyyhep6.livekit.cloud'
const CLOUD_KEY    = process.env.LIVEKIT_API_KEY    ?? ''
const CLOUD_SECRET = process.env.LIVEKIT_API_SECRET ?? ''

// FIX-77: VPS-Health-Cache – kein Check bei jedem Token-Request
let vpsHealthy: boolean | null = null
let vpsCheckedAt = 0
const VPS_CHECK_INTERVAL = 60_000 // 60s Cache

// FIX-77: VPS erreichbar? Schneller HTTP-Check
async function isVpsAlive(): Promise<boolean> {
  if (!SELF_URL || !SELF_KEY || !SELF_SECRET) return false
  const now = Date.now()
  if (vpsHealthy !== null && now - vpsCheckedAt < VPS_CHECK_INTERVAL) {
    return vpsHealthy
  }
  try {
    const httpUrl = SELF_URL
      .replace('wss://', 'https://')
      .replace('ws://', 'http://')
    const res = await fetch(httpUrl, {
      method: 'HEAD',
      signal: AbortSignal.timeout(3000),
    })
    vpsHealthy = res.ok || res.status === 404
    vpsCheckedAt = now
    return vpsHealthy
  } catch {
    vpsHealthy = false
    vpsCheckedAt = now
    return false
  }
}

// FIX-77: Server-Auswahl mit echtem Health-Check
async function pickServer(): Promise<{
  url: string; key: string; secret: string; source: 'vps' | 'cloud'
}> {
  if (await isVpsAlive()) {
    return { url: SELF_URL, key: SELF_KEY, secret: SELF_SECRET, source: 'vps' }
  }
  if (CLOUD_KEY && CLOUD_SECRET) {
    console.warn('[LiveKit] VPS nicht erreichbar – Fallback auf Cloud')
    return { url: CLOUD_URL, key: CLOUD_KEY, secret: CLOUD_SECRET, source: 'cloud' }
  }
  throw new Error('Kein LiveKit-Server verfügbar (VPS down, Cloud nicht konfiguriert)')
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
  source: 'vps' | 'cloud'
}

export async function generateLiveKitToken(
  input: LiveKitTokenInput,
): Promise<LiveKitTokenResult> {
  const { url, key, secret, source } = await pickServer()

  // FIX-77: VPS = 24h TTL (volle Kontrolle), Cloud = 4h (Free-Tier)
  const ttl = source === 'vps' ? 60 * 60 * 24 : 60 * 60 * 4

  const at = new AccessToken(key, secret, {
    identity: input.identity,
    name: input.displayName,
    ttl,
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
  return { token, url, roomName: input.roomName, source }
}

// FIX-77: Manueller Health-Reset (z.B. nach VPS-Neustart)
export function resetVpsHealth(): void {
  vpsHealthy = null
  vpsCheckedAt = 0
}
