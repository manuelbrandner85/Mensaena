'use client'

import { useState, useCallback, useEffect } from 'react'
import { useTranslations } from 'next-intl'
import { Bell, Mail, MapPin, Info, Save, Loader2, Volume2, VolumeX, Smartphone, Send, Newspaper } from 'lucide-react'
import toast from 'react-hot-toast'
import SettingsSection, { Toggle, SettingRow } from './SettingsSection'
import type { SettingsProfile } from '../types'
import { usePushNotifications } from '@/hooks/usePushNotifications'
import { invalidateNotificationPrefs } from '@/lib/notifications'
import QuietHoursSettings from '@/components/features/QuietHoursSettings'
import PushDebugPanel from '@/components/native/PushDebugPanel'
import { createClient } from '@/lib/supabase/client'

interface Props {
  settings: SettingsProfile
  userId?: string
  onSave: (updates: Partial<SettingsProfile>, msg?: string) => Promise<boolean>
  saving: boolean
  onDirty?: () => void
}

/**
 * Sync the sound preference to localStorage so that DashboardShell
 * can read it immediately without a DB call.
 */
function syncSoundToLocalStorage(enabled: boolean) {
  if (typeof window === 'undefined') return
  localStorage.setItem('mensaena_notify_sound', String(enabled))
}

export default function NotificationSettings({ settings, userId, onSave, saving, onDirty }: Props) {
  const t = useTranslations('notifSettings')
  const tSettings = useTranslations('settings')
  const [local, setLocal] = useState({
    notify_new_messages: settings.notify_new_messages ?? true,
    notify_new_interactions: settings.notify_new_interactions ?? true,
    notify_nearby_posts: settings.notify_nearby_posts ?? true,
    notify_trust_ratings: settings.notify_trust_ratings ?? true,
    notify_system: settings.notify_system ?? true,
    notify_email: settings.notify_email ?? false,
    notify_push: settings.notify_push ?? true,
    notify_sound: settings.notify_sound ?? true,
    notification_radius_km: settings.notification_radius_km ?? 10,
    notify_inactivity_reminder: settings.notify_inactivity_reminder ?? true,
  })

  const { permission, isSubscribed, loading: pushLoading, subscribe, unsubscribe } = usePushNotifications()

  const handlePushToggle = async (enabled: boolean) => {
    if (enabled) {
      if (permission === 'denied') {
        toast.error(t('toastPushBlocked'))
        return
      }
      await subscribe(userId)
      update('notify_push', true)
    } else {
      await unsubscribe()
      update('notify_push', false)
    }
  }

  // Sync sound preference on mount
  useEffect(() => {
    syncSoundToLocalStorage(local.notify_sound)
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Newsletter-Abonnement ───────────────────────────────────
  const [newsletterSubscribed, setNewsletterSubscribed] = useState<boolean | null>(null)
  const [newsletterSaving, setNewsletterSaving] = useState(false)

  useEffect(() => {
    if (!userId) return
    const supabase = createClient()
    supabase
      .from('email_subscriptions')
      .select('subscribed')
      .eq('user_id', userId)
      .maybeSingle()
      .then(({ data }) => {
        setNewsletterSubscribed(data?.subscribed ?? true)
      })
  }, [userId])

  const toggleNewsletter = async (value: boolean) => {
    setNewsletterSaving(true)
    setNewsletterSubscribed(value)
    try {
      const res = await fetch('/api/emails/unsubscribe', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subscribed: value }),
      })
      if (!res.ok) throw new Error('Update failed')
      toast.success(value ? t('toastNewsletterSubscribed') : t('toastNewsletterUnsubscribed'))
    } catch (e) {
      setNewsletterSubscribed(!value)
      toast.error(t('toastSaveError'))
    } finally {
      setNewsletterSaving(false)
    }
  }

  const markDirty = useCallback(() => { onDirty?.() }, [onDirty])

  const update = (key: string, value: boolean | number) => {
    setLocal(prev => ({ ...prev, [key]: value }))
    markDirty()
    // Immediately sync sound preference to localStorage
    if (key === 'notify_sound') {
      syncSoundToLocalStorage(value as boolean)
    }
  }

  // Handle push toggle with browser permission flow
  // Play test sound
  const playTestSound = () => {
    try {
      const audio = new Audio('/sounds/notification.mp3')
      audio.volume = 0.3
      audio.play().catch(() => toast.error(t('toastSoundError')))
    } catch {
      toast.error(t('toastSoundUnavailable'))
    }
  }

  const handleSave = async () => {
    syncSoundToLocalStorage(local.notify_sound)
    const ok = await onSave(local, tSettings('saved'))
    if (ok && userId) invalidateNotificationPrefs(userId)
  }

  const getRadiusLabel = (km: number) => {
    if (km <= 5) return t('radiusNeighborhood')
    if (km <= 15) return t('radiusSurroundings')
    if (km <= 30) return t('radiusCity')
    if (km <= 75) return t('radiusRegional')
    if (km <= 100) return t('radiusBeyondRegion')
    return t('radiusWide')
  }

  return (
    <div className="space-y-5">
      {/* FCM Debug Panel – nur in der Capacitor-APK sichtbar */}
      <PushDebugPanel />

      {/* In-App Notifications */}
      <SettingsSection
        icon={<Bell className="w-4 h-4 text-primary-700" />}
        title={t('sectionInAppTitle')}
        description={t('sectionInAppDesc')}
      >
        <div>
          <SettingRow label={t('newMessages')} description={t('newMessagesDesc')}>
            <Toggle value={local.notify_new_messages} onChange={v => update('notify_new_messages', v)} />
          </SettingRow>

          <SettingRow label={t('interactions')} description={t('interactionsDesc')}>
            <Toggle value={local.notify_new_interactions} onChange={v => update('notify_new_interactions', v)} />
          </SettingRow>

          <SettingRow label={t('nearbyPosts')} description={t('nearbyPostsDesc')}>
            <Toggle value={local.notify_nearby_posts} onChange={v => update('notify_nearby_posts', v)} />
          </SettingRow>

          <SettingRow label={t('trustRatings')} description={t('trustRatingsDesc')}>
            <Toggle value={local.notify_trust_ratings} onChange={v => update('notify_trust_ratings', v)} />
          </SettingRow>

          <SettingRow label={t('system')} description={t('systemDesc')}>
            <Toggle value={local.notify_system} onChange={v => update('notify_system', v)} />
          </SettingRow>

          <SettingRow label={t('inactivityReminder')} description={t('inactivityReminderDesc')}>
            <Toggle value={local.notify_inactivity_reminder} onChange={v => update('notify_inactivity_reminder', v)} />
          </SettingRow>
        </div>
      </SettingsSection>

      {/* Notification Channels */}
      <SettingsSection
        icon={<Mail className="w-4 h-4 text-primary-700" />}
        title={t('sectionChannelsTitle')}
        description={t('sectionChannelsDesc')}
      >
        <div>
          <SettingRow label={t('emailNotif')} description={t('emailNotifDesc')}>
            <Toggle value={local.notify_email} onChange={v => update('notify_email', v)} />
          </SettingRow>

          <SettingRow label={t('pushNotif')} description={t('pushNotifDesc')}>
            <div className="flex items-center gap-2">
              <Toggle value={local.notify_push} onChange={handlePushToggle} />
              {pushLoading && <Loader2 className="w-4 h-4 animate-spin text-gray-400" />}
              {local.notify_push && isSubscribed && (
                <span className="text-xs text-primary-600 flex items-center gap-1">
                  <Smartphone className="w-3 h-3" /> {t('pushActive')}
                </span>
              )}
              {permission === 'denied' && (
                <span className="text-xs text-red-500">{t('pushBlocked')}</span>
              )}
            </div>
          </SettingRow>

          <SettingRow label={t('soundNotif')} description={t('soundNotifDesc')}>
            <div className="flex items-center gap-2">
              <Toggle value={local.notify_sound} onChange={v => update('notify_sound', v)} />
              {local.notify_sound && (
                <button
                  onClick={playTestSound}
                  className="flex items-center gap-1 text-xs text-primary-600 hover:text-primary-700 font-medium"
                  title={t('soundTest')}
                >
                  <Volume2 className="w-3.5 h-3.5" /> Test
                </button>
              )}
              {!local.notify_sound && (
                <VolumeX className="w-3.5 h-3.5 text-gray-400" />
              )}
            </div>
          </SettingRow>
        </div>
      </SettingsSection>

      {/* Newsletter */}
      <SettingsSection
        icon={<Newspaper className="w-4 h-4 text-primary-700" />}
        title={t('sectionNewsletterTitle')}
        description={t('sectionNewsletterDesc')}
      >
        <div>
          <SettingRow label={t('newsletter')} description={t('newsletterDesc')}>
            <div className="flex items-center gap-2">
              {newsletterSubscribed === null ? (
                <Loader2 className="w-4 h-4 text-gray-300 animate-spin" />
              ) : (
                <Toggle value={newsletterSubscribed} onChange={toggleNewsletter} />
              )}
              {newsletterSaving && <Loader2 className="w-4 h-4 animate-spin text-gray-400" />}
            </div>
          </SettingRow>
        </div>
      </SettingsSection>

      {/* Notification Radius */}
      <SettingsSection
        icon={<MapPin className="w-4 h-4 text-primary-700" />}
        title={t('sectionRadiusTitle')}
        description={t('sectionRadiusDesc')}
      >
        <div>
          <label className="label">
            {t('radiusLabel', { km: local.notification_radius_km })}
            <span className="text-gray-400 font-normal ml-2">({getRadiusLabel(local.notification_radius_km)})</span>
          </label>
          <input
            type="range"
            min={1}
            max={150}
            value={local.notification_radius_km}
            onChange={e => update('notification_radius_km', parseInt(e.target.value))}
            className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-primary-600"
          />
          <div className="flex justify-between text-xs text-gray-400 mt-1">
            <span>1 km</span>
            <span>25 km</span>
            <span>75 km</span>
            <span>150 km</span>
          </div>
          <div className="mt-3 flex items-start gap-2 bg-primary-50 rounded-xl p-3">
            <Info className="w-4 h-4 text-primary-600 flex-shrink-0 mt-0.5" />
            <p className="text-xs text-primary-700">{t('radiusInfo')}</p>
          </div>
        </div>
      </SettingsSection>

      {/* Quiet Hours */}
      {userId && <QuietHoursSettings userId={userId} />}

      {/* Save */}
      <div className="flex justify-end">
        <button
          onClick={handleSave}
          disabled={saving}
          className="flex items-center gap-2 px-6 py-2.5 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all disabled:opacity-50 min-h-[44px]"
        >
          {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
          {t('saveButton')}
        </button>
      </div>
    </div>
  )
}
