import { create } from 'zustand'
import { createClient } from '@/lib/supabase/client'

interface AuthState {
  user: { id: string; email: string } | null
  profile: { display_name?: string; avatar_url?: string } | null
  loading: boolean
  initialized: boolean
  init: () => Promise<void>
  signOut: () => Promise<void>
}

export const useAuthStore = create<AuthState>((set, get) => ({
  user: null,
  profile: null,
  loading: true,
  initialized: false,

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

    // Listen for future auth changes
    supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.user) {
        set({
          user: { id: session.user.id, email: session.user.email ?? '' },
          loading: false,
        })
      } else {
        set({ user: null, profile: null, loading: false })
      }
    })
  },

  signOut: async () => {
    const supabase = createClient()
    await supabase.auth.signOut()
    set({ user: null, profile: null })
  },
}))
