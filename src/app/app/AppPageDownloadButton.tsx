'use client'

import { useState } from 'react'
import { Download } from 'lucide-react'
import { APK_URL, APK_FILENAME } from '@/lib/app-download'
import AppDownloadStatusModal from '@/components/shared/AppDownloadStatusModal'

// Download-Button auf der /app Seite.
// Klick startet APK-Download + öffnet Status-Modal mit rotierenden
// motivierenden Sätzen (konsistent mit AppInstallLink auf dem Landing).
export default function AppPageDownloadButton() {
  const [showStatus, setShowStatus] = useState(false)

  const onClick = (e: React.MouseEvent<HTMLAnchorElement>) => {
    e.preventDefault()
    const trigger = document.createElement('a')
    trigger.href = APK_URL
    trigger.download = APK_FILENAME
    trigger.rel = 'noopener'
    document.body.appendChild(trigger)
    trigger.click()
    trigger.remove()
    setShowStatus(true)
  }

  return (
    <>
      <a
        href={APK_URL}
        download={APK_FILENAME}
        rel="noopener"
        onClick={onClick}
        className="btn-primary w-full sm:w-auto inline-flex items-center justify-center gap-2 px-6 py-3.5 text-base"
      >
        <Download className="w-5 h-5" aria-hidden="true" />
        Mensaena.apk laden
      </a>
      {showStatus && (
        <AppDownloadStatusModal onClose={() => setShowStatus(false)} />
      )}
    </>
  )
}
