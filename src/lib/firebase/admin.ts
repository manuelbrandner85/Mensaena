// FCM push via REST API v1 — replaces firebase-admin SDK (~10 MB).
// Uses service account JWT (RS256) + Google OAuth2 to get access tokens.
// Compatible with CF Workers via nodejs_compat (uses Node.js crypto).

import { createSign } from 'crypto'

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'
const TOKEN_URL = 'https://oauth2.googleapis.com/token'

let cachedToken: { value: string; expiresAt: number } | null = null

function b64url(data: string | Buffer): string {
  const buf = typeof data === 'string' ? Buffer.from(data) : data
  return buf.toString('base64url')
}

async function getAccessToken(): Promise<string | null> {
  if (cachedToken && Date.now() < cachedToken.expiresAt) return cachedToken.value

  const projectId   = process.env.FIREBASE_PROJECT_ID
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL
  const privateKeyRaw = process.env.FIREBASE_PRIVATE_KEY
  if (!projectId || !clientEmail || !privateKeyRaw) {
    console.warn('[fcm] FIREBASE_* env vars fehlen – Push deaktiviert')
    return null
  }
  const privateKey = privateKeyRaw.replace(/\\n/g, '\n')

  try {
    const now = Math.floor(Date.now() / 1000)
    const header  = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
    const payload = b64url(
      JSON.stringify({
        iss: clientEmail,
        sub: clientEmail,
        aud: TOKEN_URL,
        iat: now,
        exp: now + 3600,
        scope: FCM_SCOPE,
      }),
    )

    const sigInput = `${header}.${payload}`
    const sign = createSign('RSA-SHA256')
    sign.update(sigInput)
    const sig = b64url(sign.sign(privateKey))
    const assertion = `${sigInput}.${sig}`

    const body = new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    })

    const res = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    })
    if (!res.ok) throw new Error(`Token fetch ${res.status}`)
    const json = await res.json() as { access_token: string; expires_in: number }
    cachedToken = { value: json.access_token, expiresAt: Date.now() + (json.expires_in - 60) * 1000 }
    return cachedToken.value
  } catch (e) {
    console.error('[fcm] Access-Token-Fehler:', e)
    return null
  }
}

async function sendFcm(token: string, data: Record<string, string>): Promise<boolean> {
  const projectId = process.env.FIREBASE_PROJECT_ID
  if (!projectId) return false
  const accessToken = await getAccessToken()
  if (!accessToken) return false

  try {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token,
            data,
            android: { priority: 'high' },
            apns: { headers: { 'apns-priority': '10', 'apns-push-type': 'background' } },
          },
        }),
      },
    )
    return res.ok
  } catch (e) {
    console.error('[fcm] send failed:', e)
    return false
  }
}

export async function sendDataPush(fcmToken: string, data: Record<string, string>): Promise<boolean> {
  return sendFcm(fcmToken, data)
}

export async function sendDataPushMulti(
  tokens: string[],
  data: Record<string, string>,
): Promise<{ success: number; failure: number }> {
  if (!tokens.length) return { success: 0, failure: 0 }
  let success = 0, failure = 0
  await Promise.all(
    tokens.map(async (tok) => {
      if (await sendFcm(tok, data)) success++
      else failure++
    }),
  )
  return { success, failure }
}
