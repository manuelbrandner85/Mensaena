'use client'

import { useEffect, useMemo } from 'react'
import { de, type Messages } from './messages/de'
import { en } from './messages/en'
import { it } from './messages/it'
import { useLocaleStore, type Locale } from '@/store/useLocaleStore'

const MESSAGES: Record<Locale, Messages> = { de, en, it }

/** Dot-path getter, e.g. get(msgs, 'nav.dashboard'). */
function resolve(obj: unknown, path: string): string {
  const parts = path.split('.')
  let cur: unknown = obj
  for (const p of parts) {
    if (cur && typeof cur === 'object' && p in (cur as Record<string, unknown>)) {
      cur = (cur as Record<string, unknown>)[p]
    } else {
      return path
    }
  }
  return typeof cur === 'string' ? cur : path
}

/**
 * React hook returning a `t()` translator function.
 * Falls back to German for missing keys and returns the key itself if
 * nothing is found so missing translations are visible.
 */
export function useT() {
  const locale = useLocaleStore((s) => s.locale)

  const t = useMemo(() => {
    const active = MESSAGES[locale] ?? MESSAGES.de
    return (key: string) => {
      const translated = resolve(active, key)
      if (translated !== key) return translated
      // Fallback to DE if missing
      return resolve(MESSAGES.de, key)
    }
  }, [locale])

  return { t, locale }
}

/**
 * Client-side effect that syncs `<html lang>` with the current locale.
 * Mounted once at app shell level so screen readers & browsers get the
 * correct language hint without a page reload.
 */
export function HtmlLangSync() {
  const locale = useLocaleStore((s) => s.locale)
  useEffect(() => {
    if (typeof document !== 'undefined') {
      document.documentElement.lang = locale
    }
  }, [locale])
  return null
}
