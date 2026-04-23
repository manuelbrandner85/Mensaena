import { create } from 'zustand'

interface AccessibilityState {
  largeFont: boolean
  highContrast: boolean
  simplifiedView: boolean
  reducedMotion: boolean
  init: () => void
  toggleLargeFont: () => void
  toggleHighContrast: () => void
  toggleSimplifiedView: () => void
  toggleReducedMotion: () => void
}

function applyClasses(state: Pick<AccessibilityState, 'largeFont' | 'highContrast' | 'simplifiedView' | 'reducedMotion'>) {
  if (typeof window === 'undefined') return
  const { classList } = document.documentElement
  classList.toggle('a11y-large-font', state.largeFont)
  classList.toggle('a11y-high-contrast', state.highContrast)
  classList.toggle('a11y-simplified', state.simplifiedView)
  classList.toggle('a11y-reduced-motion', state.reducedMotion)
}

function loadBool(key: string): boolean {
  if (typeof window === 'undefined') return false
  return localStorage.getItem(key) === 'true'
}

function saveBool(key: string, value: boolean) {
  if (typeof window === 'undefined') return
  localStorage.setItem(key, String(value))
}

export const useAccessibilityStore = create<AccessibilityState>((set, get) => ({
  largeFont: false,
  highContrast: false,
  simplifiedView: false,
  reducedMotion: false,

  init() {
    const state = {
      largeFont: loadBool('a11y-large-font'),
      highContrast: loadBool('a11y-high-contrast'),
      simplifiedView: loadBool('a11y-simplified'),
      reducedMotion: loadBool('a11y-reduced-motion'),
    }
    set(state)
    applyClasses(state)
  },

  toggleLargeFont() {
    const value = !get().largeFont
    saveBool('a11y-large-font', value)
    set({ largeFont: value })
    applyClasses({ ...get(), largeFont: value })
  },

  toggleHighContrast() {
    const value = !get().highContrast
    saveBool('a11y-high-contrast', value)
    set({ highContrast: value })
    applyClasses({ ...get(), highContrast: value })
  },

  toggleSimplifiedView() {
    const value = !get().simplifiedView
    saveBool('a11y-simplified', value)
    set({ simplifiedView: value })
    applyClasses({ ...get(), simplifiedView: value })
  },

  toggleReducedMotion() {
    const value = !get().reducedMotion
    saveBool('a11y-reduced-motion', value)
    set({ reducedMotion: value })
    applyClasses({ ...get(), reducedMotion: value })
  },
}))
