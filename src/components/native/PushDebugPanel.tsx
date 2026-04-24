'use client'

import { useEffect, useState } from 'react'
import { readFcmStatus, type FcmStatus } from '@/hooks/useCapacitorPush'

interface FcmState {
  status: FcmStatus
  token?: string
  error?: string
  updatedAt: string
}

/**
 * Zeigt den Live-Status der FCM-Push-Registrierung.
 * Nur sichtbar in der Capacitor-APK. Im Browser wird der Panel gar nicht gerendert.
 */
export default function PushDebugPanel() {
  const [state, setState] = useState<FcmState | null>(null)
  const [isNative, setIsNative] = useState(false)

  useEffect(() => {
    // Native-Check
    if (typeof navigator !== 'undefined') {
      setIsNative(/MensaenaApp/i.test(navigator.userAgent))
    }

    // Initial-State
    setState(readFcmStatus())

    // Updates live übernehmen
    const handler = (e: Event) => {
      const detail = (e as CustomEvent<FcmState>).detail
      if (detail) setState(detail)
    }
    window.addEventListener('mensaena:fcm-status', handler)

    // Polling alle 2s als Fallback (localStorage cross-tab)
    const poll = setInterval(() => setState(readFcmStatus()), 2000)

    return () => {
      window.removeEventListener('mensaena:fcm-status', handler)
      clearInterval(poll)
    }
  }, [])

  if (!isNative) return null

  const statusInfo = describe(state?.status ?? 'idle')

  return (
    <div className="rounded-xl border border-stone-200 bg-stone-50 p-4 space-y-2">
      <div className="flex items-center justify-between">
        <span className="text-xs font-semibold uppercase tracking-wider text-ink-500">
          📱 Push-Status (APK)
        </span>
        <span
          className={`text-xs font-medium ${statusInfo.color}`}
          aria-label={statusInfo.label}
        >
          {statusInfo.icon} {statusInfo.label}
        </span>
      </div>

      <p className="text-sm text-ink-700">{statusInfo.description}</p>

      {state?.error && (
        <details className="text-xs text-red-700">
          <summary className="cursor-pointer font-medium">
            Fehler-Details anzeigen
          </summary>
          <pre className="mt-2 whitespace-pre-wrap break-all bg-red-50 p-2 rounded text-[11px] border border-red-200">
            {state.error}
          </pre>
        </details>
      )}

      {state?.token && state?.status === 'token_saved' && (
        <div className="text-[11px] font-mono text-ink-400 break-all">
          Token: {state.token}
        </div>
      )}

      {state?.updatedAt && (
        <div className="text-[10px] text-ink-400">
          Zuletzt aktualisiert: {new Date(state.updatedAt).toLocaleString('de-DE')}
        </div>
      )}

      {statusInfo.action && (
        <div className="pt-2 border-t border-stone-200 text-xs text-ink-600">
          💡 {statusInfo.action}
        </div>
      )}
    </div>
  )
}

function describe(status: FcmStatus): {
  icon: string
  label: string
  description: string
  color: string
  action?: string
} {
  switch (status) {
    case 'idle':
      return {
        icon: '⏸',
        label: 'Noch nicht initialisiert',
        description:
          'Die Push-Registrierung startet automatisch nach dem Login.',
        color: 'text-ink-400',
      }
    case 'unsupported':
      return {
        icon: 'ℹ️',
        label: 'Nicht unterstützt',
        description:
          'Push läuft im Browser über Web Push (siehe Browser-Benachrichtigungen oben).',
        color: 'text-ink-400',
      }
    case 'requesting':
      return {
        icon: '⏳',
        label: 'Berechtigung wird angefragt',
        description:
          'Android zeigt gleich den Dialog „Darf Mensaena Benachrichtigungen senden?".',
        color: 'text-ink-500',
      }
    case 'permission_denied':
      return {
        icon: '🔕',
        label: 'Verweigert',
        description:
          'Du hast Benachrichtigungen für Mensaena deaktiviert.',
        color: 'text-amber-700',
        action:
          'Android-Einstellungen → Apps → Mensaena → Benachrichtigungen → aktivieren. Dann App neu öffnen.',
      }
    case 'registering':
      return {
        icon: '⏳',
        label: 'Registriert bei Firebase...',
        description: 'FCM generiert gleich deinen Device-Token.',
        color: 'text-primary-600',
      }
    case 'registration_error':
      return {
        icon: '✗',
        label: 'Firebase-Fehler',
        description:
          'FCM konnte kein Token vergeben. Meist: google-services.json im Build fehlerhaft oder keine Play-Services auf dem Gerät.',
        color: 'text-red-700',
        action:
          'App deinstallieren, neu laden von github.com/manuelbrandner85/Mensaena/releases/latest, installieren, öffnen.',
      }
    case 'token_save_error':
      return {
        icon: '⚠️',
        label: 'DB-Fehler',
        description:
          'Token wurde von Firebase vergeben aber nicht in Supabase gespeichert. Meist: RLS-Policy oder Verbindungsproblem.',
        color: 'text-red-700',
      }
    case 'token_saved':
      return {
        icon: '✓',
        label: 'Aktiv',
        description:
          'Push-Benachrichtigungen sind eingerichtet. Test: jemand kann dir nun eine Nachricht schicken oder der Admin kann über Supabase eine Test-Notification erstellen.',
        color: 'text-green-700',
      }
  }
}
