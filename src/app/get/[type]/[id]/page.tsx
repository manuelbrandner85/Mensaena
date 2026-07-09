'use client'

// Smart-Link / Deferred-Deep-Link-Seite.
// Geteilte Inhalte (z. B. Profil) verweisen auf https://www.mensaena.de/get/<typ>/<id>
// — ein KLICKBARER https-Link (Custom-Schemes wie mensaena:// sind in WhatsApp & Co.
// nicht klickbar).
//   • App installiert  → Android App Link öffnet die App direkt (assetlinks.json
//                         verifiziert). Diese Seite wird dann gar nicht geladen.
//     Falls doch (kein App-Link-Auto-Open) versucht das JS unten das
//     mensaena://-Schema → App öffnet sich.
//   • App NICHT da     → nach kurzem Timeout Weiterleitung zum APK-Download.

import { useEffect, useState } from 'react'
import { useParams } from 'next/navigation'

const APK_DIRECT_URL =
  'https://github.com/manuelbrandner85/Mensaena/releases/latest/download/mensaena-release.apk'

export default function SmartLinkPage() {
  const params = useParams<{ type: string; id: string }>()
  const type = String(params?.type ?? '')
  const id = String(params?.id ?? '')
  const [triedApp, setTriedApp] = useState(false)

  const isInvite = type === 'invite'
  // Einladungscode zielt auf die Registrierung (mit "eingeladen von"-Banner),
  // nicht auf einen Dashboard-Screen — eigenes Custom-Scheme-Ziel.
  const deepLink = isInvite
    ? `mensaena://auth?mode=register&ref=${id}`
    : `mensaena://dashboard/${type}/${id}`
  // Fallback ohne App: bei Einladungen NICHT auf den blanken APK-Download
  // schicken (Code-Attribution ginge beim Seitenladen sonst verloren) —
  // stattdessen die Web-Registrierung mit demselben Code öffnen, die den
  // Referral genauso zuordnet.
  const fallbackUrl = isInvite
    ? `/auth?mode=register&ref=${id}`
    : APK_DIRECT_URL

  function openApp() {
    setTriedApp(true)
    let fellBack = false
    const goStore = () => {
      if (fellBack) return
      fellBack = true
      window.location.href = fallbackUrl
    }
    // Wenn die App sich öffnet, wird die Seite in den Hintergrund gelegt →
    // Fallback abbrechen.
    const cancel = () => {
      fellBack = true
    }
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) cancel()
    })
    window.addEventListener('pagehide', cancel)
    window.addEventListener('blur', cancel)
    const t = setTimeout(goStore, 1600)
    void t
    try {
      window.location.href = deepLink
    } catch {
      goStore()
    }
  }

  // Automatischer Versuch beim ersten Laden (mobile). Auf Desktop nur Buttons.
  useEffect(() => {
    if (!type || !id) return
    const isMobile = /android|iphone|ipad|ipod/i.test(
      typeof navigator !== 'undefined' ? navigator.userAgent : '',
    )
    if (isMobile) openApp()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [type, id])

  return (
    <main
      style={{
        minHeight: '100dvh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 20,
        padding: 24,
        textAlign: 'center',
        background: '#0A0F1C',
        color: '#EAF2F2',
        fontFamily: 'system-ui, -apple-system, sans-serif',
      }}
    >
      <img
        src="/apple-touch-icon.png"
        alt="Mensaena"
        width={84}
        height={84}
        style={{ borderRadius: 20 }}
      />
      <h1 style={{ fontSize: 22, margin: 0 }}>Mensaena öffnen</h1>
      <p style={{ maxWidth: 360, opacity: 0.8, lineHeight: 1.5, margin: 0 }}>
        {triedApp
          ? isInvite
            ? 'App nicht installiert? Du wirst gleich zur Registrierung weitergeleitet — dein Einladungscode bleibt erhalten.'
            : 'App nicht installiert? Du wirst gleich zum Download weitergeleitet.'
          : isInvite
            ? 'Öffne deine Einladung direkt in der Mensaena-App.'
            : 'Öffne diesen Inhalt direkt in der Mensaena-App.'}
      </p>
      <button
        onClick={openApp}
        style={{
          background: '#c79363',
          color: '#0A0F1C',
          border: 'none',
          borderRadius: 12,
          padding: '14px 28px',
          fontSize: 16,
          fontWeight: 700,
          cursor: 'pointer',
        }}
      >
        In der App öffnen
      </button>
      <a
        href={APK_DIRECT_URL}
        style={{
          color: '#c79363',
          textDecoration: 'none',
          fontSize: 15,
          fontWeight: 600,
        }}
      >
        App herunterladen (Android APK)
      </a>
    </main>
  )
}
