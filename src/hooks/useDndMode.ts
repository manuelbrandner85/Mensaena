// FEATURE: Bitte-nicht-stören-Modus

import { useState } from 'react'

interface DndState {
  enabled: boolean
  until: string | null
}

export function useDndMode() {
  const [dnd, setDndState] = useState<DndState>(() => {
    if (typeof window === 'undefined') return { enabled: false, until: null }
    try {
      const stored = localStorage.getItem('mensaena_dnd_mode')
      if (!stored) return { enabled: false, until: null }
      const parsed = JSON.parse(stored) as DndState
      if (parsed.until && new Date(parsed.until) < new Date()) {
        localStorage.removeItem('mensaena_dnd_mode')
        return { enabled: false, until: null }
      }
      return parsed
    } catch { return { enabled: false, until: null } }
  })

  function enableDnd(durationMinutes?: number) {
    const until = durationMinutes
      ? new Date(Date.now() + durationMinutes * 60000).toISOString()
      : null
    const val: DndState = { enabled: true, until }
    localStorage.setItem('mensaena_dnd_mode', JSON.stringify(val))
    setDndState(val)
  }

  function disableDnd() {
    localStorage.removeItem('mensaena_dnd_mode')
    setDndState({ enabled: false, until: null })
  }

  return { dnd, enableDnd, disableDnd }
}
