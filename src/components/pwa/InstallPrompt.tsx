'use client'

import { useState, useEffect } from 'react'
import { X, Download, Share, Plus } from 'lucide-react'
import { usePWA } from '@/hooks/usePWA'
import { shouldShowInstallPrompt, dismissInstallPrompt, permanentlyDismissInstallPrompt } from '@/lib/pwa/install-prompt'

/**
 * Detect iOS Safari (shows manual "Add to Home Screen" guide).
 */
function isIOSSafari(): boolean {
  if (typeof navigator === 'undefined') return false
  const ua = navigator.userAgent
  const isIOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
  const isSafari = /Safari/.test(ua) && !/CriOS|FxiOS|OPiOS|EdgiOS/.test(ua)
  return isIOS && isSafari
}

export default function InstallPrompt() {
  const { canInstall, isInstalled, promptInstall } = usePWA()
  const [visible, setVisible] = useState(false)
  const [showIOSGuide, setShowIOSGuide] = useState(false)

  useEffect(() => {
    // Don't show if already installed or prompt shouldn't appear
    if (isInstalled) return
    if (!shouldShowInstallPrompt()) return

    // Show after a short delay (user has had time to interact)
    const timer = setTimeout(() => {
      if (canInstall || isIOSSafari()) {
        setVisible(true)
        setShowIOSGuide(isIOSSafari() && !canInstall)
      }
    }, 5000) // 5 seconds delay

    return () => clearTimeout(timer)
  }, [canInstall, isInstalled])

  if (!visible) return null

  const handleInstall = async () => {
    const accepted = await promptInstall()
    if (accepted) {
      setVisible(false)
    } else {
      handleDismiss()
    }
  }

  const handleDismiss = () => {
    dismissInstallPrompt()
    setVisible(false)
  }

  const handleNeverShow = () => {
    permanentlyDismissInstallPrompt()
    setVisible(false)
  }

  return (
    <div className="fixed bottom-6 left-4 right-4 lg:left-auto lg:right-6 lg:w-[380px] z-50 animate-slide-up">
      <div className="bg-white rounded-2xl shadow-2xl border border-gray-100 overflow-hidden">
        {/* ── Header ── */}
        <div className="bg-gradient-to-r from-primary-600 to-teal-600 px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 bg-white/20 rounded-lg flex items-center justify-center">
              <Download className="w-4 h-4 text-white" />
            </div>
            <span className="text-white font-semibold text-sm">Mensaena installieren</span>
          </div>
          <button
            onClick={handleDismiss}
            className="p-1 rounded-lg hover:bg-white/20 text-white/80 hover:text-white transition-all"
            aria-label="Schließen"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* ── Body ── */}
        <div className="p-4">
          {showIOSGuide ? (
            <>
              <p className="text-sm text-gray-600 mb-3">
                Installiere Mensaena auf deinem iPhone/iPad:
              </p>
              <ol className="text-sm text-gray-700 space-y-2 mb-4">
                <li className="flex items-start gap-2">
                  <span className="flex-shrink-0 w-5 h-5 bg-primary-100 text-primary-700 rounded-full flex items-center justify-center text-xs font-bold">1</span>
                  <span>
                    Tippe auf{' '}
                    <Share className="inline w-4 h-4 text-blue-500 -mt-0.5" />{' '}
                    <strong>Teilen</strong>
                  </span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="flex-shrink-0 w-5 h-5 bg-primary-100 text-primary-700 rounded-full flex items-center justify-center text-xs font-bold">2</span>
                  <span>
                    Scrolle und tippe auf{' '}
                    <Plus className="inline w-4 h-4 text-gray-700 -mt-0.5" />{' '}
                    <strong>Zum Home-Bildschirm</strong>
                  </span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="flex-shrink-0 w-5 h-5 bg-primary-100 text-primary-700 rounded-full flex items-center justify-center text-xs font-bold">3</span>
                  <span>
                    Tippe auf <strong>Hinzufügen</strong>
                  </span>
                </li>
              </ol>
            </>
          ) : (
            <p className="text-sm text-gray-600 mb-4">
              Installiere Mensaena als App auf deinem Gerät. Schnellerer Zugriff, Offline-Unterstützung und Push-Benachrichtigungen.
            </p>
          )}

          {/* ── Actions ── */}
          <div className="flex gap-2">
            {!showIOSGuide && (
              <button
                onClick={handleInstall}
                className="flex-1 bg-primary-600 hover:bg-primary-700 text-white text-sm font-semibold py-2.5 px-4 rounded-xl transition-colors flex items-center justify-center gap-2"
              >
                <Download className="w-4 h-4" />
                Installieren
              </button>
            )}
            <button
              onClick={handleNeverShow}
              className="text-xs text-gray-400 hover:text-gray-600 transition-colors px-2"
            >
              Nicht mehr anzeigen
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
