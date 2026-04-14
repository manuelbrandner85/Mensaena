/* ═══════════════════════════════════════════════════════════════════════
   PUSH  MANAGER  –  Manage push subscriptions via the Push API
   ═══════════════════════════════════════════════════════════════════════ */

import { urlBase64ToUint8Array, isPushSupported } from './pwa-utils'

// Hardcoded fallback: VAPID public keys are public by design (like Firebase
// API keys). Hardcoding avoids the need for manual Cloudflare Pages env vars.
const VAPID_PUBLIC_KEY =
  process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY ||
  'BAlrzL9LS7n7XoLCKU2qMcVFIjPH8ptAqqCSQyQD462KTvqgwqj4Qi2CcVIzxHpb05IO-XCbRRUvCkRloBzzfH0'

// ── Types ────────────────────────────────────────────────────────────

export interface PushSubscriptionData {
  endpoint: string
  p256dh: string
  auth: string
}

// ── Helpers ──────────────────────────────────────────────────────────

function subscriptionToData(sub: PushSubscription): PushSubscriptionData {
  const p256dhKey = sub.getKey('p256dh')
  const authKey = sub.getKey('auth')
  return {
    endpoint: sub.endpoint,
    p256dh: p256dhKey
      ? btoa(String.fromCharCode(...new Uint8Array(p256dhKey)))
      : '',
    auth: authKey
      ? btoa(String.fromCharCode(...new Uint8Array(authKey)))
      : '',
  }
}

// ── Public API ───────────────────────────────────────────────────────

/**
 * Get the current push subscription (if any) from the active SW registration.
 */
export async function getExistingSubscription(): Promise<PushSubscription | null> {
  if (!isPushSupported()) return null
  try {
    const reg = await navigator.serviceWorker.ready
    return await reg.pushManager.getSubscription()
  } catch {
    return null
  }
}

/**
 * Subscribe the user to push notifications.
 * Requires Notification.permission === 'granted'.
 * Returns the PushSubscriptionData to store server-side, or null on failure.
 */
export async function subscribeToPush(): Promise<PushSubscriptionData | null> {
  if (!isPushSupported()) return null
  if (!VAPID_PUBLIC_KEY) {
    console.warn('[PushManager] VAPID key not configured')
    return null
  }

  try {
    const reg = await navigator.serviceWorker.ready

    // Check for an existing subscription first
    let subscription = await reg.pushManager.getSubscription()

    if (!subscription) {
      const applicationServerKey = urlBase64ToUint8Array(VAPID_PUBLIC_KEY) as BufferSource
      subscription = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey,
      })
    }

    return subscriptionToData(subscription)
  } catch (err) {
    console.warn('[PushManager] Subscribe failed:', err)
    return null
  }
}

/**
 * Unsubscribe from push notifications.
 */
export async function unsubscribeFromPush(): Promise<boolean> {
  try {
    const subscription = await getExistingSubscription()
    if (subscription) {
      return await subscription.unsubscribe()
    }
    return true
  } catch {
    return false
  }
}

/**
 * Save the push subscription to Supabase (via dynamic import to avoid circular deps).
 */
export async function saveSubscriptionToServer(
  userId: string,
  subData: PushSubscriptionData,
): Promise<boolean> {
  try {
    const { createClient } = await import('@/lib/supabase/client')
    const supabase = createClient()
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (supabase.from('push_subscriptions') as any).upsert(
      {
        user_id: userId,
        endpoint: subData.endpoint,
        p256dh: subData.p256dh,
        auth: subData.auth,
        user_agent: navigator.userAgent,
        active: true,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'endpoint' },
    )
    if (error) {
      console.warn('[PushManager] Save subscription failed:', error.message)
      return false
    }
    return true
  } catch {
    return false
  }
}

/**
 * Remove the push subscription from the server.
 */
export async function removeSubscriptionFromServer(
  endpoint: string,
): Promise<boolean> {
  try {
    const { createClient } = await import('@/lib/supabase/client')
    const supabase = createClient()
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (supabase.from('push_subscriptions') as any)
      .update({ active: false })
      .eq('endpoint', endpoint)
    return !error
  } catch {
    return false
  }
}
