'use client'

import { useEffect, useState } from 'react'
import QRCode from 'qrcode'
import { APK_URL } from '@/lib/app-download'

// Generiert den QR-Code client-seitig. Server-seitige Generierung mit
// 'qrcode' lässt die Seite in Cloudflare Workers auf Client-Rendering
// zurückfallen (BAILOUT_TO_CLIENT_SIDE_RENDERING), weil das Package
// Node-spezifische APIs nutzt, die im Workers-Bundle nicht verfügbar sind.
export default function AppPageQRCode() {
  const [svg, setSvg] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    QRCode.toString(APK_URL, {
      type: 'svg',
      margin: 1,
      width: 280,
      color: { dark: '#0E1A19', light: '#FFFFFF' },
      errorCorrectionLevel: 'M',
    })
      .then((generated) => {
        if (!cancelled) setSvg(generated)
      })
      .catch(() => {
        if (!cancelled) setSvg(null)
      })
    return () => {
      cancelled = true
    }
  }, [])

  if (!svg) {
    // Skeleton mit gleichen Dimensionen, damit kein Layout-Shift
    return (
      <div
        aria-label="QR-Code wird geladen"
        className="bg-white rounded-2xl border-2 border-primary-100 p-4 w-[260px] h-[260px] flex items-center justify-center"
      >
        <div className="w-[230px] h-[230px] bg-gray-100 rounded-lg animate-pulse" />
      </div>
    )
  }

  return (
    <div
      role="img"
      aria-label="QR-Code zum APK-Download"
      className="bg-white rounded-2xl border-2 border-primary-100 p-4 w-[260px] h-[260px] flex items-center justify-center"
      dangerouslySetInnerHTML={{ __html: svg }}
    />
  )
}
