import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface SidebarState {
  openGroups: string[]
  mobileOpen: boolean
}

interface SidebarActions {
  toggleGroup: (id: string) => void
  openGroup: (id: string) => void
  setMobileOpen: (open: boolean) => void
}

export const useSidebarStore = create<SidebarState & SidebarActions>()(
  persist(
    (set) => ({
      openGroups: [],
      mobileOpen: false,

      // Manual toggle: open/close without affecting siblings
      toggleGroup: (id) =>
        set((s) => ({
          openGroups: s.openGroups.includes(id)
            ? s.openGroups.filter((g) => g !== id)
            : [...s.openGroups, id],
        })),

      // Auto-open on navigation: accordion — only the active group stays open
      openGroup: (id) => set({ openGroups: [id] }),

      setMobileOpen: (open) => set({ mobileOpen: open }),
    }),
    {
      name: 'mensaena-sidebar-v2',
      partialize: (state) => ({ openGroups: state.openGroups }),
    }
  )
)
