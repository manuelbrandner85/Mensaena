import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface NavigationState {
  // Persisted
  sidebarCollapsed: boolean
  // Ephemeral
  mobileMenuOpen: boolean
  searchOpen: boolean
  activeGroup: string | null
}

interface NavigationActions {
  toggleSidebar: () => void
  setSidebarCollapsed: (value: boolean) => void
  toggleMobileMenu: () => void
  closeMobileMenu: () => void
  toggleSearch: () => void
  setActiveGroup: (group: string | null) => void
}

export const useNavigationStore = create<NavigationState & NavigationActions>()(
  persist(
    (set) => ({
      sidebarCollapsed: false,
      mobileMenuOpen: false,
      searchOpen: false,
      activeGroup: null,

      toggleSidebar: () => set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed })),
      setSidebarCollapsed: (value) => set({ sidebarCollapsed: value }),
      toggleMobileMenu: () => set((s) => ({ mobileMenuOpen: !s.mobileMenuOpen })),
      closeMobileMenu: () => set({ mobileMenuOpen: false }),
      toggleSearch: () => set((s) => ({ searchOpen: !s.searchOpen })),
      setActiveGroup: (group) => set({ activeGroup: group }),
    }),
    {
      name: 'mensaena-nav',
      // Only persist sidebarCollapsed
      partialize: (state) => ({ sidebarCollapsed: state.sidebarCollapsed }),
    }
  )
)
