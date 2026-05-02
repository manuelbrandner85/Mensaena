// FIX-125: Firebase Admin SDK fuer FCM Data-Only Push (incoming calls).
// Initialisiert sich lazy beim ersten Aufruf, cached App-Instance.

import type { App } from 'firebase-admin/app'
import type { Messaging } from 'firebase-admin/messaging'

let cachedApp: App | null = null
let cachedMessaging: Messaging | null = null

async function getMessaging(): Promise<Messaging | null> {
  if (cachedMessaging) return cachedMessaging
  try {
    const projectId   = process.env.FIREBASE_PROJECT_ID
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL
    const privateKeyRaw = process.env.FIREBASE_PRIVATE_KEY
    if (!projectId || !clientEmail || !privateKeyRaw) {
      console.warn('[firebase-admin] FIREBASE_PROJECT_ID/CLIENT_EMAIL/PRIVATE_KEY fehlt – Push deaktiviert')
      return null
    }
    // PRIVATE_KEY oft mit literalem \n in env – ersetzen
    const privateKey = privateKeyRaw.replace(/\\n/g, '\n')

    const { initializeApp, getApps, cert } = await import('firebase-admin/app')
    const { getMessaging: gm } = await import('firebase-admin/messaging')

    cachedApp = getApps()[0] ?? initializeApp({
      credential: cert({ projectId, clientEmail, privateKey }),
    })
    cachedMessaging = gm(cachedApp)
    return cachedMessaging
  } catch (e) {
    console.error('[firebase-admin] init failed:', e)
    return null
  }
}

/**
 * Sendet eine Data-Only FCM Message an einen einzelnen Token.
 * Data-Only triggert auf Android im Hintergrund/killed wakeup.
 */
export async function sendDataPush(fcmToken: string, data: Record<string, string>): Promise<boolean> {
  const messaging = await getMessaging()
  if (!messaging) return false
  try {
    await messaging.send({
      token: fcmToken,
      data,
      android: { priority: 'high' },
      apns: { headers: { 'apns-priority': '10', 'apns-push-type': 'background' } },
    })
    return true
  } catch (e) {
    console.error('[firebase-admin] send failed:', e)
    return false
  }
}

/**
 * Sendet Data-Only Push an mehrere Tokens. Best-effort, Errors werden
 * pro Token geloggt aber blockieren nicht.
 */
export async function sendDataPushMulti(tokens: string[], data: Record<string, string>): Promise<{ success: number; failure: number }> {
  if (!tokens.length) return { success: 0, failure: 0 }
  const messaging = await getMessaging()
  if (!messaging) return { success: 0, failure: tokens.length }
  let success = 0, failure = 0
  await Promise.all(tokens.map(async tok => {
    try {
      await messaging.send({
        token: tok,
        data,
        android: { priority: 'high' },
        apns: { headers: { 'apns-priority': '10', 'apns-push-type': 'background' } },
      })
      success++
    } catch {
      failure++
    }
  }))
  return { success, failure }
}
