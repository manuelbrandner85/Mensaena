'use client'

import { useCapacitorPush } from '@/hooks/useCapacitorPush'

/**
 * Dünner Wrapper um den `useCapacitorPush` Hook, damit er im Root-Layout
 * mit ein paar Zeilen eingebunden werden kann. Der Hook macht selbst nichts,
 * wenn
 *   - wir nicht in der nativen Capacitor-APK sind, oder
 *   - kein User eingeloggt ist
 */
export default function CapacitorPushBridge() {
  useCapacitorPush()
  return null
}
