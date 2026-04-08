'use client'

import { User, Bell, Shield, Lock, Settings } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { SettingsTab } from '../types'

const TABS: { id: SettingsTab; label: string; icon: typeof User }[] = [
  { id: 'profile',       label: 'Profil & Standort', icon: User },
  { id: 'notifications', label: 'Benachrichtigungen', icon: Bell },
  { id: 'privacy',       label: 'Privatsphaere',      icon: Shield },
  { id: 'security',      label: 'Sicherheit',         icon: Lock },
  { id: 'account',       label: 'Account',            icon: Settings },
]

interface SettingsTabsProps {
  activeTab: SettingsTab
  onTabChange: (tab: SettingsTab) => void
  dirtyTabs?: Set<SettingsTab>
}

export default function SettingsTabs({ activeTab, onTabChange, dirtyTabs }: SettingsTabsProps) {
  return (
    <>
      {/* Mobile: horizontal scrollable – full width */}
      <div className="md:hidden overflow-x-auto -mx-4 px-4 pb-2">
        <div className="flex gap-1 min-w-max bg-gray-50 rounded-xl p-1">
          {TABS.map(tab => {
            const Icon = tab.icon
            const active = activeTab === tab.id
            const dirty = dirtyTabs?.has(tab.id)
            return (
              <button
                key={tab.id}
                onClick={() => onTabChange(tab.id)}
                className={cn(
                  'relative flex items-center gap-1.5 px-3 py-2.5 rounded-lg text-xs font-medium whitespace-nowrap transition-all',
                  'min-h-[44px] min-w-[44px]', // 44px touch target
                  active
                    ? 'bg-white text-gray-900 shadow-sm'
                    : 'text-gray-500 hover:text-gray-700',
                )}
              >
                <Icon className={cn('w-3.5 h-3.5', active && 'text-emerald-600')} />
                {tab.label}
                {dirty && (
                  <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-amber-400" />
                )}
              </button>
            )
          })}
        </div>
      </div>

      {/* Desktop: vertical sidebar (200px) */}
      <div className="hidden md:block w-[200px] flex-shrink-0">
        <nav className="bg-white rounded-2xl shadow-sm border border-gray-100 p-2 sticky top-24">
          {TABS.map(tab => {
            const Icon = tab.icon
            const active = activeTab === tab.id
            const dirty = dirtyTabs?.has(tab.id)
            return (
              <button
                key={tab.id}
                onClick={() => onTabChange(tab.id)}
                className={cn(
                  'relative w-full flex items-center gap-2.5 px-3 py-2.5 rounded-xl text-sm font-medium transition-all text-left mb-0.5',
                  'min-h-[44px]', // 44px touch target
                  active
                    ? 'bg-emerald-50 text-emerald-700'
                    : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900',
                )}
              >
                <Icon className={cn('w-4 h-4', active ? 'text-emerald-600' : 'text-gray-400')} />
                {tab.label}
                {dirty && (
                  <span className="absolute top-2 right-2 w-2.5 h-2.5 rounded-full bg-amber-400 border-2 border-white" />
                )}
              </button>
            )
          })}
        </nav>
      </div>
    </>
  )
}
