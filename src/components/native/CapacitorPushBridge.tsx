'use client'

import { useEffect } from 'react'
import { useCapacitorPush } from '@/hooks/useCapacitorPush'

/**
 * Dünner Wrapper um den `useCapacitorPush` Hook + Native Incoming Call Handler.
 * FIX-125: Initialisiert beim App-Start den Native-Call-Listener.
 */
export default function CapacitorPushBridge() {
  useCapacitorPush()

  useEffect(() => {
    // FIX-125: Lazy import damit Browser-Builds das Plugin nicht laden
    void import('@/lib/native/incoming-call-handler').then(m => m.initIncomingCallHandler())
  }, [])

  return null
}
