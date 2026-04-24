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
      openGroups: ['personal'],
      mobileOpen: false,

      toggleGroup: (id) =>
        set((s) => ({
          openGroups: s.openGroups.includes(id)
            ? s.openGroups.filter((g) => g !== id)
            : [...s.openGroups, id],
        })),

      openGroup: (id) =>
        set((s) => ({
          openGroups: s.openGroups.includes(id) ? s.openGroups : [...s.openGroups, id],
        })),

      setMobileOpen: (open) => set({ mobileOpen: open }),
    }),
    {
      name: 'mensaena-sidebar',
      partialize: (state) => ({ openGroups: state.openGroups }),
    }
  )
)
