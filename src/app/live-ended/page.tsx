'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { Video } from 'lucide-react'

/**
 * Landing page after Jitsi hangup via ?returnTo=.../live-ended
 *
 * Priority:
 * 1. Send videoConferenceLeft to opener (so ChatView modal closes)
 * 2. window.close() — closes popup or tab opened by window.open()
 * 3. Fallback: navigate to /dashboard/chat after 1.5s
 */
export default function LiveEndedPage() {
  const router = useRouter()
  const [countdown, setCountdown] = useState(2)

  useEffect(() => {
    // Tell opener (Mensaena main tab/window) that the call ended
    try {
      if (window.opener && !window.opener.closed) {
        window.opener.postMessage({ event: 'videoConferenceLeft' }, '*')
        window.opener.postMessage({ type:  'videoConferenceLeft' }, '*')
      }
    } catch { /* cross-origin opener — ignore */ }

    // Close this tab/popup (works when opened via window.open())
    window.close()

    // Fallback: if window.close() was blocked (user navigated here directly),
    // count down and redirect to chat
    const tick = setInterval(() => setCountdown(n => n - 1), 1000)
    const redirect = setTimeout(() => {
      clearInterval(tick)
      router.replace('/dashboard/chat')
    }, 2000)

    return () => {
      clearInterval(tick)
      clearTimeout(redirect)
    }
  }, [router])

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#EEF9F9]">
      <div className="text-center space-y-5 px-8">
        <div className="w-16 h-16 rounded-2xl bg-primary-50 border border-primary-100 flex items-center justify-center mx-auto shadow-soft">
          <Video className="w-8 h-8 text-primary-400" />
        </div>
        <div>
          <p className="text-lg font-bold text-ink-900">Live-Raum beendet</p>
          <p className="text-sm text-ink-500 mt-1">
            Weiterleitung in {countdown}…
          </p>
        </div>
      </div>
    </div>
  )
}
