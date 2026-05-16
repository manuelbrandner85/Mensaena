'use client'

import { User, Bell, Shield, Lock, Settings, Accessibility } from 'lucide-react'
import { useTranslations } from 'next-intl'
import { cn } from '@/lib/utils'
import type { SettingsTab } from '../types'

const TABS: { id: SettingsTab; icon: typeof User }[] = [
  { id: 'profile',       icon: User },
  { id: 'notifications', icon: Bell },
  { id: 'privacy',       icon: Shield },
  { id: 'security',      icon: Lock },
  { id: 'account',       icon: Settings },
  { id: 'accessibility', icon: Accessibility },
]

interface SettingsTabsProps {
  activeTab: SettingsTab
  onTabChange: (tab: SettingsTab) => void
  dirtyTabs?: Set<SettingsTab>
}

export default function SettingsTabs({ activeTab, onTabChange, dirtyTabs }: SettingsTabsProps) {
  const t = useTranslations('settings')
  return (
    <>
      {/* Mobile: horizontal scrollable – full width */}
      <div className="md:hidden overflow-x-auto -mx-4 px-4 pb-2">
        <div className="flex gap-1 min-w-max bg-mn-surface rounded-xl p-1">
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
                    ? 'bg-mn-elevated text-mn-ink shadow-sm'
                    : 'text-mn-mute hover:text-mn-ink-soft',
                )}
              >
                <Icon className={cn('w-3.5 h-3.5', active && 'text-mn-bronze')} />
                {t(tab.id)}
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
        <nav className="relative bg-mn-elevated rounded-2xl shadow-cinema-card border border-white/5 p-2 sticky top-24 overflow-hidden">
          <div
            className="absolute top-0 left-0 right-0 h-[3px]"
            style={{ background: 'linear-gradient(90deg, #1EAAA6, #1EAAA633)' }}
          />
          <div className="relative pt-1">
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
                    'min-h-[44px]',
                    active
                      ? 'bg-gradient-to-r from-mn-bronze/8 to-primary-50/50 text-mn-bronze shadow-cinema-card ring-1 ring-primary-100'
                      : 'text-mn-ink-soft hover:bg-mn-surface hover:text-mn-ink',
                  )}
                >
                  <Icon className={cn('w-4 h-4 transition-transform', active ? 'text-mn-bronze scale-110' : 'text-mn-mute')} />
                  {t(tab.id)}
                  {dirty && (
                    <span className="absolute top-2 right-2 w-2.5 h-2.5 rounded-full bg-amber-400 border-2 border-white shadow-cinema-card animate-pulse" />
                  )}
                </button>
              )
            })}
          </div>
        </nav>
      </div>
    </>
  )
}
