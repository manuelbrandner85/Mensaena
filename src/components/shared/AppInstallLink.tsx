'use client'

import { useEffect, useState, type ReactNode, type MouseEvent } from 'react'
import Link from 'next/link'
import { APK_URL, APK_FILENAME } from '@/lib/app-download'
import AppDownloadStatusModal from './AppDownloadStatusModal'

type Props = {
  children: ReactNode
  className?: string
  onClick?: () => void
}

// Plattform-bewusster App-Install-Link.
//
// - Android: Klick startet APK-Download sofort + öffnet Status-Modal mit
//   rotierenden motivierenden Sätzen und Install-Anleitung.
// - Desktop/iOS: Navigiert auf /app (dort steht der QR-Code zum Scannen).
// - SSR / vor Hydration: generischer Link auf /app (sicherer Default, kein FOUC).
//
// Die Klasse 'cta-app-download' wird automatisch angehängt, damit die
// bestehende CSS-Regel `html.is-native .cta-app-download { display: none }`
// den Link in der Capacitor-APK ausblendet.
export default function AppInstallLink({ children, className, onClick }: Props) {
  const [platform, setPlatform] = useState<'unknown' | 'android' | 'other'>('unknown')
  const [showStatus, setShowStatus] = useState(false)

  useEffect(() => {
    setPlatform(/Android/i.test(navigator.userAgent) ? 'android' : 'other')
  }, [])

  const combinedClass = ['cta-app-download', className].filter(Boolean).join(' ')

  const handleAndroidClick = (e: MouseEvent<HTMLAnchorElement>) => {
    // Browser-Download programmatisch anstoßen (zuverlässiger als sich
    // auf das native <a download>-Verhalten zu verlassen, insbesondere
    // wenn der nächste State-Update den Link re-rendert).
    e.preventDefault()
    const trigger = document.createElement('a')
    trigger.href = APK_URL
    trigger.download = APK_FILENAME
    trigger.rel = 'noopener'
    document.body.appendChild(trigger)
    trigger.click()
    trigger.remove()
    setShowStatus(true)
    onClick?.()
  }

  if (platform === 'android') {
    return (
      <>
        <a
          href={APK_URL}
          download={APK_FILENAME}
          rel="noopener"
          onClick={handleAndroidClick}
          className={combinedClass}
        >
          {children}
        </a>
        {showStatus && (
          <AppDownloadStatusModal onClose={() => setShowStatus(false)} />
        )}
      </>
    )
  }

  // Desktop/iOS oder vor Hydration: zur /app Seite (QR-Code zum Scannen).
  return (
    <Link href="/app" className={combinedClass} onClick={onClick}>
      {children}
    </Link>
  )
}
