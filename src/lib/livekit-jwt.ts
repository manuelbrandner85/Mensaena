// Lightweight LiveKit JWT generator — replaces livekit-server-sdk (~2 MB).
// Uses Node.js built-in crypto (HMAC-SHA256) to create HS256 tokens.
// Compatible with CF Workers via nodejs_compat flag.

import { createHmac } from 'crypto'

function b64url(data: string | Buffer): string {
  const buf = typeof data === 'string' ? Buffer.from(data) : data
  return buf.toString('base64url')
}

interface LivekitGrant {
  roomJoin?: boolean
  room?: string
  canPublish?: boolean
  canSubscribe?: boolean
  canPublishData?: boolean
  hidden?: boolean
}

interface TokenOptions {
  identity: string
  name?: string
  ttl?: number // seconds, default 4h
  metadata?: string
  grant?: LivekitGrant
}

export async function createLivekitToken(
  apiKey: string,
  apiSecret: string,
  opts: TokenOptions,
): Promise<string> {
  const ttl = opts.ttl ?? 4 * 3600
  const now = Math.floor(Date.now() / 1000)

  const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
  const payload = b64url(
    JSON.stringify({
      iss: apiKey,
      sub: opts.identity,
      iat: now,
      exp: now + ttl,
      ...(opts.name     && { name: opts.name }),
      ...(opts.metadata && { metadata: opts.metadata }),
      ...(opts.grant    && { video: opts.grant }),
    }),
  )

  const sigInput  = `${header}.${payload}`
  const signature = createHmac('sha256', apiSecret).update(sigInput).digest()
  return `${sigInput}.${b64url(signature)}`
}
