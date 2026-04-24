'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

// Läuft nur im Client. Wenn die Seite innerhalb der Capacitor-APK
// aufgerufen wird (html.is-native), leitet sie direkt auf /dashboard
// weiter – dort ist der Nutzer ohnehin schon "in der App".
export default function AppPageNativeRedirect() {
  const router = useRouter()

  useEffect(() => {
    if (document.documentElement.classList.contains('is-native')) {
      router.replace('/dashboard')
    }
  }, [router])

  return null
}
