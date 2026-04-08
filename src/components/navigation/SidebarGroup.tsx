'use client'

import { ChevronDown } from 'lucide-react'
import { cn } from '@/lib/utils'

interface SidebarGroupProps {
  title: string
  collapsed: boolean
  open: boolean
  onToggle: () => void
  children: React.ReactNode
}

export default function SidebarGroup({ title, collapsed, open, onToggle, children }: SidebarGroupProps) {
  if (collapsed) {
    // In collapsed mode: show a divider line, always show items
    return (
      <div className="mt-2">
        <div className="mx-3 h-px bg-gray-100" />
        <div className="mt-1 space-y-0.5">{children}</div>
      </div>
    )
  }

  return (
    <div className="mt-3">
      {/* Group header – clickable to toggle */}
      <button
        onClick={onToggle}
        className="w-full flex items-center gap-2 px-3 py-1.5 group hover:bg-gray-50 rounded-lg transition-colors"
      >
        <span className="text-[10px] font-black uppercase tracking-wider text-gray-400 select-none whitespace-nowrap">
          {title}
        </span>
        <div className="flex-1 h-px bg-gradient-to-r from-gray-200 to-transparent" />
        <ChevronDown
          className={cn(
            'w-3 h-3 text-gray-400 transition-transform duration-200 flex-shrink-0',
            open ? 'rotate-0' : '-rotate-90',
          )}
        />
      </button>

      {/* Items – collapsible */}
      <div
        className={cn(
          'overflow-hidden transition-all duration-200 ease-out',
          open ? 'max-h-[600px] opacity-100 mt-0.5' : 'max-h-0 opacity-0',
        )}
      >
        <div className="space-y-0.5 px-1">{children}</div>
      </div>
    </div>
  )
}
