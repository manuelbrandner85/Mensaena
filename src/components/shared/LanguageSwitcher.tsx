'use client'

import { useState, useEffect, useRef } from 'react'
import { Globe } from 'lucide-react'
import { useTranslations } from 'next-intl'
import { cn } from '@/lib/utils'

const LOCALES = [
  { code: 'de', label: 'Deutsch', flag: '🇩🇪' },
  { code: 'en', label: 'English', flag: '🇬🇧' },
  { code: 'it', label: 'Italiano', flag: '🇮🇹' },
  { code: 'tr', label: 'Türkçe', flag: '🇹🇷' },
  { code: 'uk', label: 'Українська', flag: '🇺🇦' },
  { code: 'ar', label: 'العربية', flag: '🇸🇦' },
]

function getCookieLocale(): string {
  if (typeof document === 'undefined') return 'de'
  const match = document.cookie.match(/(?:^|;\s*)NEXT_LOCALE=([^;]+)/)
  return match ? match[1] : 'de'
}

export default function LanguageSwitcher({ className, dropUp = false }: { className?: string; dropUp?: boolean }) {
  const t = useTranslations('nav')
  const [isOpen, setIsOpen] = useState(false)
  const [currentLocale, setCurrentLocale] = useState('de')
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    setCurrentLocale(getCookieLocale())
  }, [])

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setIsOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  function selectLocale(code: string) {
    document.cookie = `NEXT_LOCALE=${code};path=/;max-age=31536000;SameSite=Lax`
    document.documentElement.dir = code === 'ar' ? 'rtl' : 'ltr'
    setCurrentLocale(code)
    setIsOpen(false)
    window.location.reload()
  }

  const active = LOCALES.find((l) => l.code === currentLocale) ?? LOCALES[0]

  return (
    <div ref={ref} className={cn('relative', className)}>
      <button
        onClick={() => setIsOpen((o) => !o)}
        className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-sm font-medium text-ink-700 hover:bg-primary-50 hover:text-primary-600 transition-colors"
        aria-label={t('language_aria')}
        aria-expanded={isOpen}
      >
        <Globe className="w-4 h-4 text-primary-500" />
        <span>{active.flag}</span>
        <span className="uppercase text-xs tracking-wide">{active.code}</span>
      </button>

      {isOpen && (
        <div className={cn('absolute right-0 w-44 bg-white dark:bg-stone-900 rounded-xl shadow-card border border-stone-100 dark:border-stone-700 py-1 z-50', dropUp ? 'bottom-full mb-1' : 'mt-1')}>
          {LOCALES.map((locale) => (
            <button
              key={locale.code}
              onClick={() => selectLocale(locale.code)}
              className={cn(
                'w-full flex items-center gap-2.5 px-3 py-2 text-sm transition-colors',
                locale.code === currentLocale
                  ? 'bg-primary-50 text-primary-700 font-semibold'
                  : 'text-ink-700 hover:bg-stone-50'
              )}
            >
              <span className="text-base">{locale.flag}</span>
              <span>{locale.label}</span>
              {locale.code === currentLocale && (
                <span className="ml-auto w-1.5 h-1.5 rounded-full bg-primary-500" />
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
