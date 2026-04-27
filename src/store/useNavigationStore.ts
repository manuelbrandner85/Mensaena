import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface NavigationState {
  // Persisted
  sidebarCollapsed: boolean
  // Ephemeral
  mobileMenuOpen: boolean
  searchOpen: boolean
  activeGroup: string | null
  isInCall: boolean
}

interface NavigationActions {
  toggleSidebar: () => void
  setSidebarCollapsed: (value: boolean) => void
  toggleMobileMenu: () => void
  closeMobileMenu: () => void
  toggleSearch: () => void
  setActiveGroup: (group: string | null) => void
  setIsInCall: (value: boolean) => void
}

export const useNavigationStore = create<NavigationState & NavigationActions>()(
  persist(
    (set) => ({
      sidebarCollapsed: false,
      mobileMenuOpen: false,
      searchOpen: false,
      activeGroup: null,
      isInCall: false,

      toggleSidebar: () => set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed })),
      setSidebarCollapsed: (value) => set({ sidebarCollapsed: value }),
      toggleMobileMenu: () => set((s) => ({ mobileMenuOpen: !s.mobileMenuOpen })),
      closeMobileMenu: () => set({ mobileMenuOpen: false }),
      toggleSearch: () => set((s) => ({ searchOpen: !s.searchOpen })),
      setActiveGroup: (group) => set({ activeGroup: group }),
      setIsInCall: (value) => set({ isInCall: value }),
    }),
    {
      name: 'mensaena-nav',
      // Only persist sidebarCollapsed
      partialize: (state) => ({ sidebarCollapsed: state.sidebarCollapsed }),
    }
  )
)
