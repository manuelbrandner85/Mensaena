import { create } from 'zustand'
import { createClient } from '@/lib/supabase/client'
import type { Subscription } from '@supabase/supabase-js'

interface AuthState {
  user: { id: string; email: string } | null
  profile: { display_name?: string; avatar_url?: string } | null
  loading: boolean
  initialized: boolean
  _authSubscription: Subscription | null
  init: () => Promise<void>
  signOut: () => Promise<void>
}

export const useAuthStore = create<AuthState>((set, get) => ({
  user: null,
  profile: null,
  loading: true,
  initialized: false,
  _authSubscription: null,

  init: async () => {
    if (get().initialized) return
    const supabase = createClient()
    try {
      const { data: { session } } = await supabase.auth.getSession()
      if (session?.user) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('id', session.user.id)
          .maybeSingle()
        set({
          user: { id: session.user.id, email: session.user.email ?? '' },
          profile: profile ?? null,
          loading: false,
          initialized: true,
        })
      } else {
        set({ user: null, profile: null, loading: false, initialized: true })
      }
    } catch {
      set({ user: null, profile: null, loading: false, initialized: true })
    }

    // Vorhandene Subscription entfernen, falls init() doch ein zweites Mal
    // durchläuft (z.B. nach unsauberem signOut).
    get()._authSubscription?.unsubscribe()

    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.user) {
        set({
          user: { id: session.user.id, email: session.user.email ?? '' },
          loading: false,
        })
      } else {
        set({ user: null, profile: null, loading: false })
      }
    })
    set({ _authSubscription: data.subscription })
  },

  signOut: async () => {
    const supabase = createClient()
    get()._authSubscription?.unsubscribe()
    await supabase.auth.signOut()
    set({ user: null, profile: null, initialized: false, _authSubscription: null })

    // Persistente Zustand-Stores leeren, damit auf Shared Devices keine
    // Sidebar-/Layout-Preferences von User A zu User B leaken.
    if (typeof window !== 'undefined') {
      try {
        localStorage.removeItem('mensaena-nav')
        localStorage.removeItem('mensaena-sidebar')
        localStorage.removeItem('mensaena-accessibility')
      } catch { /* localStorage-Quota oder iframe-Restriction → ignorieren */ }
    }
  },
}))
