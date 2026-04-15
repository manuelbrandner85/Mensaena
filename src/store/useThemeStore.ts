import { create } from 'zustand'
import { persist } from 'zustand/middleware'

export type ThemeMode = 'light' | 'dark' | 'system'

interface ThemeState {
  mode: ThemeMode
  setMode: (m: ThemeMode) => void
  toggle: () => void
}

export const useThemeStore = create<ThemeState>()(
  persist(
    (set, get) => ({
      mode: 'system',
      setMode: (m) => set({ mode: m }),
      toggle: () => {
        const curr = get().mode
        // system → light → dark → system
        const next: ThemeMode = curr === 'system' ? 'light' : curr === 'light' ? 'dark' : 'system'
        set({ mode: next })
      },
    }),
    {
      name: 'mensaena-theme',
    }
  )
)

/**
 * Resolve a ThemeMode to a concrete 'light' | 'dark' given the current
 * media query for 'system'.
 */
export function resolveTheme(mode: ThemeMode): 'light' | 'dark' {
  if (mode === 'system') {
    if (typeof window === 'undefined') return 'light'
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
  }
  return mode
}
