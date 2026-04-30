'use client'

// UPDATE-SYSTEM: Vollbild-Update-Screen für Web-OTA-Updates (Browser/PWA)
import { useEffect, useState } from 'react'
import Image from 'next/image'
import type { ReleaseNotes } from '@/hooks/useAppUpdate'

interface WebUpdateScreenProps {
  releaseNotes: ReleaseNotes
  newVersion: string
  isUpdating: boolean
  onUpdate: () => void
  onDismiss: () => void
}

export default function WebUpdateScreen({
  releaseNotes,
  newVersion,
  isUpdating,
  onUpdate,
  onDismiss,
}: WebUpdateScreenProps) {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    // Kurze Verzögerung für Eintritts-Animation
    const t = setTimeout(() => setVisible(true), 30)
    return () => clearTimeout(t)
  }, [])

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="App-Update verfügbar"
      className={[
        'fixed inset-0 z-[9999] overflow-y-auto',
        'bg-gradient-to-b from-[#EEF9F9] via-white to-[#EEF9F9]',
        'dark:from-stone-900 dark:via-stone-950 dark:to-stone-900',
        'transition-opacity duration-500',
        visible ? 'opacity-100' : 'opacity-0',
      ].join(' ')}
    >
      <div
        className={[
          'min-h-full flex flex-col items-center justify-center px-6 py-12 gap-6 max-w-md mx-auto',
          'transition-transform duration-500',
          visible ? 'translate-y-0' : 'translate-y-5',
        ].join(' ')}
      >
        {/* Logo */}
        <div
          className={[
            'transition-all duration-500 delay-0',
            visible ? 'opacity-100 scale-100' : 'opacity-0 scale-90',
          ].join(' ')}
        >
          <div className="relative w-20 h-20 rounded-2xl ring-4 ring-primary-200 dark:ring-primary-800 shadow-glow animate-pulse overflow-hidden">
            <Image
              src="/mensaena-logo.png"
              alt="Mensaena"
              fill
              className="object-cover"
              priority
            />
          </div>
        </div>

        {/* Headline */}
        <div
          className={[
            'text-center transition-all duration-500 delay-100',
            visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-3',
          ].join(' ')}
        >
          <h1 className="text-2xl font-display font-bold text-ink-900 dark:text-stone-100 mb-2">
            ✨ {releaseNotes.headline}
          </h1>
          <p className="text-base text-ink-500 dark:text-stone-400">
            {releaseNotes.subtitle}
          </p>
        </div>

        {/* Feature-Karten */}
        <div className="w-full flex flex-col gap-3">
          {releaseNotes.features.map((feature, idx) => (
            <div
              key={idx}
              className={[
                'bg-white dark:bg-stone-800 rounded-2xl p-4 shadow-sm border border-stone-100 dark:border-stone-700',
                'flex items-start gap-4',
                'transition-all duration-500',
                visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-3',
              ].join(' ')}
              style={{ transitionDelay: `${200 + idx * 100}ms` }}
            >
              <span className="text-3xl flex-shrink-0 leading-none mt-0.5" aria-hidden="true">
                {feature.emoji}
              </span>
              <div>
                <p className="font-semibold text-ink-900 dark:text-stone-100 text-sm">
                  {feature.title}
                </p>
                <p className="text-sm text-ink-500 dark:text-stone-400 mt-0.5">
                  {feature.description}
                </p>
              </div>
            </div>
          ))}
        </div>

        {/* Footer-Text */}
        <p
          className={[
            'text-sm text-ink-400 dark:text-stone-500 italic text-center transition-all duration-500 delay-[400ms]',
            visible ? 'opacity-100' : 'opacity-0',
          ].join(' ')}
        >
          {releaseNotes.footer}
        </p>

        {/* Update-Button */}
        <div
          className={[
            'w-full transition-all duration-500 delay-[500ms]',
            visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-3',
          ].join(' ')}
        >
          <button
            onClick={onUpdate}
            disabled={isUpdating}
            className={[
              'w-full py-4 rounded-2xl text-white text-lg font-bold shadow-glow',
              'bg-gradient-to-r from-primary-500 to-primary-600',
              'hover:scale-[1.02] active:scale-[0.98] transition-transform duration-150',
              'disabled:opacity-70 disabled:cursor-not-allowed disabled:scale-100',
              'focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-400',
            ].join(' ')}
          >
            {isUpdating ? (
              <span className="flex items-center justify-center gap-3">
                <svg className="w-5 h-5 animate-spin" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
                Wird aktualisiert…
              </span>
            ) : (
              <span>
                🚀 Jetzt aktualisieren
                <span className="block text-xs font-normal opacity-80 mt-0.5">
                  Version {newVersion}
                </span>
              </span>
            )}
          </button>
        </div>

        {/* Später-Link */}
        <button
          onClick={onDismiss}
          className={[
            'text-sm text-ink-400 dark:text-stone-500 underline underline-offset-2',
            'hover:text-ink-600 dark:hover:text-stone-300 transition-colors',
            'transition-all duration-500 delay-[600ms]',
            visible ? 'opacity-100' : 'opacity-0',
          ].join(' ')}
        >
          Später erinnern
        </button>
      </div>
    </div>
  )
}
