'use client'

import { useEffect, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { ArrowLeft } from 'lucide-react'
import Link from 'next/link'
import { useSettings } from './hooks/useSettings'
import { useStore } from '@/store/useStore'
import SettingsTabs from './components/SettingsTabs'
import ProfileLocationSettings from './components/ProfileLocationSettings'
import NotificationSettings from './components/NotificationSettings'
import PrivacySettings from './components/PrivacySettings'
import SecuritySettings from './components/SecuritySettings'
import AccountSettings from './components/AccountSettings'
import type { SettingsTab } from './types'

/* ── Skeleton ─────────────────────────────────────── */
function SettingsSkeleton() {
  return (
    <div className="max-w-5xl mx-auto animate-pulse px-4 py-8">
      <div className="mb-6">
        <div className="h-4 w-32 bg-gray-200 rounded mb-3" />
        <div className="h-7 w-48 bg-gray-200 rounded mb-1" />
        <div className="h-4 w-80 bg-gray-200 rounded" />
      </div>
      <div className="flex flex-col md:flex-row gap-6">
        {/* Tabs skeleton */}
        <div className="hidden md:block w-[200px] flex-shrink-0">
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-2 space-y-1">
            {Array.from({ length: 5 }).map((_, i) => (
              <div key={i} className="h-11 bg-gray-100 rounded-xl" />
            ))}
          </div>
        </div>
        {/* Content skeleton */}
        <div className="flex-1 space-y-5">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
              <div className="mb-5">
                <div className="h-5 w-40 bg-gray-200 rounded mb-1" />
                <div className="h-3 w-64 bg-gray-100 rounded" />
              </div>
              <div className="space-y-3">
                <div className="h-10 bg-gray-100 rounded-xl" />
                <div className="h-10 bg-gray-100 rounded-xl" />
                <div className="h-10 bg-gray-100 rounded-xl w-2/3" />
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

/* ── Page ─────────────────────────────────────────── */
export default function SettingsPage() {
  const router = useRouter()
  const { userId: storeUserId } = useStore()

  const {
    settings,
    loading,
    saving,
    activeTab,
    setActiveTab,
    userId,
    blockedUsers,
    dirtyTabs,
    markDirty,
    saveSettings,
    changePassword,
    exportAllData,
    requestAccountDeletion,
    confirmAccountDeletion,
    countUserData,
    geocodeAddress,
    unblockUser,
    checkUsername,
    usernameAvailable,
    checkingUsername,
  } = useSettings()

  // Auth guard
  useEffect(() => {
    if (!loading && !userId && !storeUserId) {
      router.push('/login')
    }
  }, [loading, userId, storeUserId, router])

  // beforeunload: Warn when unsaved changes exist
  useEffect(() => {
    const handler = (e: BeforeUnloadEvent) => {
      if (dirtyTabs.size > 0) {
        e.preventDefault()
      }
    }
    window.addEventListener('beforeunload', handler)
    return () => window.removeEventListener('beforeunload', handler)
  }, [dirtyTabs])

  // Tab change with unsaved changes warning
  const handleTabChange = useCallback((tab: SettingsTab) => {
    if (dirtyTabs.has(activeTab)) {
      const confirmed = window.confirm(
        'Du hast ungespeicherte Änderungen. Möchtest du den Tab wirklich wechseln?'
      )
      if (!confirmed) return
    }
    setActiveTab(tab)
  }, [activeTab, dirtyTabs, setActiveTab])

  // Keyboard: Enter to save (global in settings page)
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      // Only if Enter is pressed without Shift and not in a textarea
      if (e.key === 'Enter' && !e.shiftKey && (e.target as HTMLElement)?.tagName !== 'TEXTAREA') {
        // Don't interfere with buttons or selects
        const tag = (e.target as HTMLElement)?.tagName
        if (tag === 'BUTTON' || tag === 'SELECT') return
        // If inside an input, trigger form save could be handled by the component
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [])

  // Loading state with skeleton
  if (loading) return <SettingsSkeleton />
  if (!settings || !userId) return <SettingsSkeleton />

  return (
    <div className="max-w-5xl mx-auto px-4 py-8">
      {/* Header */}
      <div className="mb-6">
        <Link href="/dashboard/profile" className="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700 transition-colors mb-3">
          <ArrowLeft className="w-4 h-4" /> Zurück zum Profil
        </Link>
        <h1 className="text-2xl font-bold text-gray-900">Einstellungen</h1>
        <p className="text-sm text-gray-500 mt-0.5">Verwalte dein Profil, Benachrichtigungen, Privatsphaere und Account</p>
      </div>

      {/* Layout: Sidebar (200px) + Content */}
      <div className="flex flex-col md:flex-row gap-6">
        {/* Sidebar/Tabs with dirty indicators */}
        <SettingsTabs
          activeTab={activeTab}
          onTabChange={handleTabChange}
          dirtyTabs={dirtyTabs}
        />

        {/* Content – full width on mobile */}
        <div className="flex-1 min-w-0">
          {activeTab === 'profile' && (
            <ProfileLocationSettings
              settings={settings}
              onSave={saveSettings}
              geocode={geocodeAddress}
              saving={saving}
              onDirty={() => markDirty('profile')}
              checkUsername={checkUsername}
              usernameAvailable={usernameAvailable}
              checkingUsername={checkingUsername}
            />
          )}

          {activeTab === 'notifications' && (
            <NotificationSettings
              settings={settings}
              userId={userId}
              onSave={saveSettings}
              saving={saving}
              onDirty={() => markDirty('notifications')}
            />
          )}

          {activeTab === 'privacy' && (
            <PrivacySettings
              settings={settings}
              blockedUsers={blockedUsers}
              onSave={saveSettings}
              onUnblock={unblockUser}
              saving={saving}
              onDirty={() => markDirty('privacy')}
            />
          )}

          {activeTab === 'security' && (
            <SecuritySettings
              settings={settings}
              onSave={saveSettings}
              onChangePassword={changePassword}
              saving={saving}
            />
          )}

          {activeTab === 'account' && (
            <AccountSettings
              settings={settings}
              userId={userId}
              onSave={saveSettings}
              onExport={exportAllData}
              onRequestDeletion={requestAccountDeletion}
              onConfirmDeletion={confirmAccountDeletion}
              onCountData={countUserData}
              saving={saving}
            />
          )}
        </div>
      </div>
    </div>
  )
}
