'use client'

import { Sun, Moon, Monitor, Languages, PlayCircle } from 'lucide-react'
import { useT } from '@/lib/i18n'
import { useLocaleStore, SUPPORTED_LOCALES, type Locale } from '@/store/useLocaleStore'
import { useThemeStore, type ThemeMode } from '@/store/useThemeStore'

/**
 * Compact appearance/language/onboarding card shown above the settings
 * tabs. Adjusts theme, display language, and lets users replay the
 * cinematic onboarding tour.
 */
export default function AppearanceSection() {
  const { t } = useT()
  const { locale, setLocale } = useLocaleStore()
  const { mode, setMode } = useThemeStore()

  const themeOptions: { value: ThemeMode; label: string; icon: React.ComponentType<{ className?: string }> }[] = [
    { value: 'light',  label: t('settings.themeLight'),  icon: Sun },
    { value: 'dark',   label: t('settings.themeDark'),   icon: Moon },
    { value: 'system', label: t('settings.themeSystem'), icon: Monitor },
  ]

  const replayTour = () => {
    if (typeof window === 'undefined') return
    try {
      localStorage.removeItem('mensaena-onboarding-seen-v1')
    } catch { /* ignore */ }
    window.dispatchEvent(new Event('mensaena:replay-onboarding'))
  }

  return (
    <section className="mb-6 bg-white dark:bg-ink-800 border border-stone-200 dark:border-ink-700 rounded-2xl shadow-sm p-5 md:p-6 transition-colors">
      <header className="mb-5">
        <h2 className="font-display text-lg font-medium text-ink-800 dark:text-stone-100 tracking-tight">
          {t('settings.appearance')}
        </h2>
        <p className="text-xs text-ink-400 dark:text-stone-500 mt-0.5">
          {t('settings.themeHint')}
        </p>
      </header>

      {/* Theme selector */}
      <div className="mb-5">
        <label className="block text-[11px] font-bold uppercase tracking-[0.12em] text-ink-500 dark:text-stone-400 mb-2">
          {t('settings.theme')}
        </label>
        <div className="grid grid-cols-3 gap-2">
          {themeOptions.map((opt) => {
            const active = mode === opt.value
            return (
              <button
                key={opt.value}
                type="button"
                onClick={() => setMode(opt.value)}
                className={`group flex flex-col items-center gap-1.5 px-3 py-3 rounded-xl border-2 text-xs font-medium transition-all ${
                  active
                    ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/30 text-primary-700 dark:text-primary-200 shadow-sm'
                    : 'border-stone-200 dark:border-ink-700 bg-white dark:bg-ink-900 text-ink-600 dark:text-stone-400 hover:border-primary-300 dark:hover:border-primary-700'
                }`}
                aria-pressed={active}
              >
                <opt.icon className={`w-5 h-5 ${active ? 'text-primary-500' : 'text-ink-400 dark:text-stone-500 group-hover:text-primary-500'}`} />
                {opt.label}
              </button>
            )
          })}
        </div>
      </div>

      {/* Language selector */}
      <div className="mb-5">
        <label className="flex items-center gap-1.5 text-[11px] font-bold uppercase tracking-[0.12em] text-ink-500 dark:text-stone-400 mb-2">
          <Languages className="w-3.5 h-3.5" />
          {t('settings.language')}
        </label>
        <div className="grid grid-cols-3 gap-2">
          {SUPPORTED_LOCALES.map((loc) => {
            const active = locale === loc.value
            return (
              <button
                key={loc.value}
                type="button"
                onClick={() => setLocale(loc.value as Locale)}
                className={`flex items-center justify-center gap-2 px-3 py-2.5 rounded-xl border-2 text-xs font-medium transition-all ${
                  active
                    ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/30 text-primary-700 dark:text-primary-200 shadow-sm'
                    : 'border-stone-200 dark:border-ink-700 bg-white dark:bg-ink-900 text-ink-600 dark:text-stone-400 hover:border-primary-300 dark:hover:border-primary-700'
                }`}
                aria-pressed={active}
              >
                <span className="text-base leading-none">{loc.flag}</span>
                {loc.label}
              </button>
            )
          })}
        </div>
        <p className="text-[10px] text-ink-400 dark:text-stone-500 mt-2">
          {t('settings.languageHint')}
        </p>
      </div>

      {/* Replay onboarding */}
      <div className="pt-4 border-t border-stone-200 dark:border-ink-700">
        <button
          type="button"
          onClick={replayTour}
          className="w-full flex items-center gap-3 px-4 py-3 rounded-xl bg-stone-50 dark:bg-ink-900 hover:bg-primary-50 dark:hover:bg-primary-900/20 border border-stone-200 dark:border-ink-700 hover:border-primary-300 dark:hover:border-primary-700 text-left transition-all group"
        >
          <div className="w-9 h-9 rounded-lg bg-white dark:bg-ink-800 border border-stone-200 dark:border-ink-700 flex items-center justify-center flex-shrink-0 group-hover:bg-primary-500 group-hover:border-primary-500 transition-colors">
            <PlayCircle className="w-4.5 h-4.5 text-primary-500 group-hover:text-white transition-colors" />
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-sm font-semibold text-ink-800 dark:text-stone-100 truncate">
              {t('settings.replayOnboarding')}
            </p>
            <p className="text-[11px] text-ink-400 dark:text-stone-500 truncate">
              {t('settings.replayOnboardingHint')}
            </p>
          </div>
        </button>
      </div>
    </section>
  )
}
