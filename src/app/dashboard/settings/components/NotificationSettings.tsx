'use client'

import { useState, useCallback, useEffect } from 'react'
import { Bell, Mail, MapPin, Info, Save, Loader2, Volume2, VolumeX, Smartphone } from 'lucide-react'
import toast from 'react-hot-toast'
import SettingsSection, { Toggle, SettingRow } from './SettingsSection'
import type { SettingsProfile } from '../types'
import { usePushNotifications } from '@/hooks/usePushNotifications'

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
  const [local, setLocal] = useState({
    notify_new_messages: settings.notify_new_messages ?? true,
    notify_new_interactions: settings.notify_new_interactions ?? true,
    notify_nearby_posts: settings.notify_nearby_posts ?? true,
    notify_trust_ratings: settings.notify_trust_ratings ?? true,
    notify_system: settings.notify_system ?? true,
    notify_email: settings.notify_email ?? false,
    notify_push: settings.notify_push ?? false,
    notify_sound: settings.notify_sound ?? true,
    notification_radius_km: settings.notification_radius_km ?? 10,
    notify_inactivity_reminder: settings.notify_inactivity_reminder ?? true,
  })

  const { permission, isSubscribed, loading: pushLoading, subscribe, unsubscribe } = usePushNotifications()

  // Sync sound preference on mount
  useEffect(() => {
    syncSoundToLocalStorage(local.notify_sound)
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

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
  const handlePushToggle = async (enabled: boolean) => {
    if (enabled) {
      if (permission === 'denied') {
        toast.error('Push-Benachrichtigungen sind in den Browser-Einstellungen blockiert. Bitte dort aktivieren.')
        return
      }
      await subscribe(userId)
      update('notify_push', true)
    } else {
      await unsubscribe()
      update('notify_push', false)
    }
  }

  // Play test sound
  const playTestSound = () => {
    try {
      const audio = new Audio('/sounds/notification.mp3')
      audio.volume = 0.3
      audio.play().catch(() => toast.error('Sound konnte nicht abgespielt werden'))
    } catch {
      toast.error('Sound-Datei nicht verfuegbar')
    }
  }

  const handleSave = async () => {
    // Sync sound to localStorage before saving to ensure consistency
    syncSoundToLocalStorage(local.notify_sound)
    await onSave(local, 'Einstellungen gespeichert ✓')
  }

  // Radius label helper
  const getRadiusLabel = (km: number) => {
    if (km <= 5) return 'Nachbarschaft'
    if (km <= 15) return 'Umgebung'
    if (km <= 30) return 'Stadt / Kreis'
    if (km <= 75) return 'Regional'
    if (km <= 100) return 'Ueberregional'
    return 'Weitreichend'
  }

  return (
    <div className="space-y-5">
      {/* In-App Notifications */}
      <SettingsSection
        icon={<Bell className="w-4 h-4 text-emerald-700" />}
        title="In-App Benachrichtigungen"
        description="Welche Benachrichtigungen moechtest du erhalten?"
      >
        <div>
          <SettingRow
            label="Neue Nachrichten"
            description="Bei neuen Direktnachrichten benachrichtigen"
          >
            <Toggle value={local.notify_new_messages} onChange={v => update('notify_new_messages', v)} />
          </SettingRow>

          <SettingRow
            label="Beitrags-Interaktionen"
            description="Wenn jemand auf deinen Beitrag reagiert oder kommentiert"
          >
            <Toggle value={local.notify_new_interactions} onChange={v => update('notify_new_interactions', v)} />
          </SettingRow>

          <SettingRow
            label="Beitraege in der Naehe"
            description="Neue Hilfeanfragen und Angebote in deinem Umkreis"
          >
            <Toggle value={local.notify_nearby_posts} onChange={v => update('notify_nearby_posts', v)} />
          </SettingRow>

          <SettingRow
            label="Vertrauens-Bewertungen"
            description="Wenn du eine neue Vertrauensbewertung erhaeltst"
          >
            <Toggle value={local.notify_trust_ratings} onChange={v => update('notify_trust_ratings', v)} />
          </SettingRow>

          <SettingRow
            label="System-Benachrichtigungen"
            description="Wichtige Updates und Ankuendigungen von Mensaena"
          >
            <Toggle value={local.notify_system} onChange={v => update('notify_system', v)} />
          </SettingRow>

          <SettingRow
            label="Inaktivitaets-Erinnerung"
            description="Erinnere mich, wenn ich laengere Zeit inaktiv war"
          >
            <Toggle value={local.notify_inactivity_reminder} onChange={v => update('notify_inactivity_reminder', v)} />
          </SettingRow>
        </div>
      </SettingsSection>

      {/* Notification Channels */}
      <SettingsSection
        icon={<Mail className="w-4 h-4 text-emerald-700" />}
        title="Benachrichtigungs-Kanaele"
        description="Wie moechtest du benachrichtigt werden?"
      >
        <div>
          <SettingRow
            label="E-Mail Benachrichtigungen"
            description="Wichtige Updates per E-Mail erhalten"
          >
            <Toggle value={local.notify_email} onChange={v => update('notify_email', v)} />
          </SettingRow>

          <SettingRow
            label="Push-Benachrichtigungen"
            description="Browser-Push bei neuen Nachrichten, Interaktionen und Krisen"
          >
            <div className="flex items-center gap-2">
              <Toggle value={local.notify_push} onChange={handlePushToggle} />
              {pushLoading && <Loader2 className="w-4 h-4 animate-spin text-gray-400" />}
              {local.notify_push && isSubscribed && (
                <span className="text-xs text-emerald-600 flex items-center gap-1">
                  <Smartphone className="w-3 h-3" /> Aktiv
                </span>
              )}
              {local.notify_push && !isSubscribed && permission !== 'denied' && (
                <button
                  onClick={() => subscribe(userId)}
                  className="text-xs text-emerald-600 hover:text-emerald-700 font-medium"
                >
                  Erlaubnis erteilen
                </button>
              )}
              {permission === 'denied' && (
                <span className="text-xs text-red-500">Blockiert</span>
              )}
            </div>
          </SettingRow>

          <SettingRow
            label="Sound-Benachrichtigungen"
            description="Akustisches Signal bei neuen Benachrichtigungen"
          >
            <div className="flex items-center gap-2">
              <Toggle value={local.notify_sound} onChange={v => update('notify_sound', v)} />
              {local.notify_sound && (
                <button
                  onClick={playTestSound}
                  className="flex items-center gap-1 text-xs text-emerald-600 hover:text-emerald-700 font-medium"
                  title="Test-Sound abspielen"
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

      {/* Notification Radius */}
      <SettingsSection
        icon={<MapPin className="w-4 h-4 text-emerald-700" />}
        title="Benachrichtigungs-Radius"
        description="Umkreis für standortbasierte Benachrichtigungen"
      >
        <div>
          <label className="label">
            Radius: {local.notification_radius_km} km
            <span className="text-gray-400 font-normal ml-2">({getRadiusLabel(local.notification_radius_km)})</span>
          </label>
          <input
            type="range"
            min={1}
            max={150}
            value={local.notification_radius_km}
            onChange={e => update('notification_radius_km', parseInt(e.target.value))}
            className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-emerald-600"
          />
          <div className="flex justify-between text-xs text-gray-400 mt-1">
            <span>1 km</span>
            <span>25 km</span>
            <span>75 km</span>
            <span>150 km</span>
          </div>
          <div className="mt-3 flex items-start gap-2 bg-emerald-50 rounded-xl p-3">
            <Info className="w-4 h-4 text-emerald-600 flex-shrink-0 mt-0.5" />
            <p className="text-xs text-emerald-700">
              Beitraege und Hilfeanfragen innerhalb dieses Radius loesen Benachrichtigungen aus.
              Ein groesserer Radius bedeutet mehr Benachrichtigungen.
            </p>
          </div>
        </div>
      </SettingsSection>

      {/* Save */}
      <div className="flex justify-end">
        <button
          onClick={handleSave}
          disabled={saving}
          className="flex items-center gap-2 px-6 py-2.5 rounded-xl text-sm font-medium bg-emerald-600 text-white hover:bg-emerald-700 transition-all disabled:opacity-50 min-h-[44px]"
        >
          {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
          Benachrichtigungen speichern
        </button>
      </div>
    </div>
  )
}
