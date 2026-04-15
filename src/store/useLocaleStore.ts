import { create } from 'zustand'
import { persist } from 'zustand/middleware'

export type Locale = 'de' | 'en' | 'it'

export const SUPPORTED_LOCALES: { value: Locale; label: string; flag: string }[] = [
  { value: 'de', label: 'Deutsch',  flag: '🇩🇪' },
  { value: 'en', label: 'English',  flag: '🇬🇧' },
  { value: 'it', label: 'Italiano', flag: '🇮🇹' },
]

interface LocaleState {
  locale: Locale
  setLocale: (l: Locale) => void
}

function detectInitialLocale(): Locale {
  if (typeof window === 'undefined') return 'de'
  const nav = (navigator.language || 'de').toLowerCase()
  if (nav.startsWith('en')) return 'en'
  if (nav.startsWith('it')) return 'it'
  return 'de'
}

export const useLocaleStore = create<LocaleState>()(
  persist(
    (set) => ({
      locale: detectInitialLocale(),
      setLocale: (l) => set({ locale: l }),
    }),
    {
      name: 'mensaena-locale',
    }
  )
)
