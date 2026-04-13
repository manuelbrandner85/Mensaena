'use client'

import { useState, useCallback } from 'react'
import { Shield, Eye, MessageCircle, UserX, Save, Loader2 } from 'lucide-react'
import SettingsSection, { Toggle, SettingRow } from './SettingsSection'
import BlockedUsersList from './BlockedUsersList'
import type { SettingsProfile, BlockedUser } from '../types'

interface Props {
  settings: SettingsProfile
  blockedUsers: BlockedUser[]
  onSave: (updates: Partial<SettingsProfile>, msg?: string) => Promise<boolean>
  onUnblock: (blockId: string) => Promise<boolean>
  saving: boolean
  onDirty?: () => void
}

export default function PrivacySettings({ settings, blockedUsers, onSave, onUnblock, saving, onDirty }: Props) {
  const [local, setLocal] = useState({
    show_online_status: settings.show_online_status ?? true,
    show_location: settings.show_location ?? true,
    show_trust_score: settings.show_trust_score ?? true,
    show_activity: settings.show_activity ?? true,
    show_phone: settings.show_phone ?? false,
    allow_messages_from: settings.allow_messages_from ?? 'everyone',
    read_receipts: settings.read_receipts ?? true,
    allow_matching: settings.allow_matching ?? true,
    profile_visibility: settings.profile_visibility ?? 'public',
  })

  const markDirty = useCallback(() => { onDirty?.() }, [onDirty])

  const update = (key: string, value: unknown) => {
    setLocal(prev => ({ ...prev, [key]: value }))
    markDirty()
  }

  const handleSave = () => onSave(local, 'Einstellungen gespeichert ✓')

  return (
    <div className="space-y-5">
      {/* Profile Visibility */}
      <SettingsSection
        icon={<Eye className="w-4 h-4 text-primary-700" />}
        title="Profil-Sichtbarkeit"
        description="Wer kann dein Profil sehen?"
      >
        <div className="space-y-3">
          <div>
            <label className="label">Profil-Sichtbarkeit</label>
            <select
              value={local.profile_visibility}
              onChange={e => update('profile_visibility', e.target.value)}
              className="input"
            >
              <option value="public">Öffentlich - Alle können dein Profil sehen</option>
              <option value="neighbors">Nachbarn - Nur Nutzer in deiner Nähe</option>
              <option value="private">Privat - Nur du kannst dein Profil sehen</option>
            </select>
          </div>

          <SettingRow
            label="Online-Status anzeigen"
            description="Andere sehen, ob du gerade online bist"
          >
            <Toggle value={local.show_online_status} onChange={v => update('show_online_status', v)} />
          </SettingRow>

          <SettingRow
            label="Standort anzeigen"
            description="Dein ungefaehrer Standort ist auf deinem Profil sichtbar"
          >
            <Toggle value={local.show_location} onChange={v => update('show_location', v)} />
          </SettingRow>

          <SettingRow
            label="Trust-Score anzeigen"
            description="Dein Vertrauens-Wert ist für andere sichtbar"
          >
            <Toggle value={local.show_trust_score} onChange={v => update('show_trust_score', v)} />
          </SettingRow>

          <SettingRow
            label="Aktivität anzeigen"
            description="Deine Beitrags- und Hilfsstatistiken sind sichtbar"
          >
            <Toggle value={local.show_activity} onChange={v => update('show_activity', v)} />
          </SettingRow>

          <SettingRow
            label="Telefonnummer anzeigen"
            description="Deine Telefonnummer auf dem Profil zeigen"
          >
            <Toggle value={local.show_phone} onChange={v => update('show_phone', v)} />
          </SettingRow>
        </div>
      </SettingsSection>

      {/* Communication */}
      <SettingsSection
        icon={<MessageCircle className="w-4 h-4 text-primary-700" />}
        title="Kommunikation"
        description="Wer kann dich kontaktieren?"
      >
        <div className="space-y-3">
          <div>
            <label className="label">Nachrichten erlauben von</label>
            <select
              value={local.allow_messages_from}
              onChange={e => update('allow_messages_from', e.target.value)}
              className="input"
            >
              <option value="everyone">Alle Nutzer</option>
              <option value="trusted">Nur vertrauenswuerdige Nutzer (Trust-Score &gt; 50)</option>
              <option value="nobody">Niemand (Nachrichten deaktiviert)</option>
            </select>
          </div>

          <SettingRow
            label="Lesebestaetigungen"
            description="Andere sehen, wenn du ihre Nachricht gelesen hast"
          >
            <Toggle value={local.read_receipts} onChange={v => update('read_receipts', v)} />
          </SettingRow>

          <SettingRow
            label="Matching erlauben"
            description="Automatisch mit passenden Hilfsangeboten verbunden werden"
          >
            <Toggle value={local.allow_matching} onChange={v => update('allow_matching', v)} />
          </SettingRow>
        </div>
      </SettingsSection>

      {/* Blocked Users */}
      <SettingsSection
        icon={<UserX className="w-4 h-4 text-primary-700" />}
        title="Blockierte Nutzer"
        description={`${blockedUsers.length} Nutzer blockiert`}
      >
        <BlockedUsersList blockedUsers={blockedUsers} onUnblock={onUnblock} />
      </SettingsSection>

      {/* DSGVO Info */}
      <SettingsSection
        icon={<Shield className="w-4 h-4 text-primary-700" />}
        title="DSGVO-Informationen"
        description="Deine Rechte nach der Datenschutz-Grundverordnung"
      >
        <div className="space-y-3 text-sm text-gray-600">
          <p>
            Gemäß DSGVO Art. 15-20 hast du das Recht auf:
          </p>
          <ul className="list-disc list-inside space-y-1 text-xs text-gray-500">
            <li><strong>Auskunft</strong> über deine gespeicherten Daten (Art. 15)</li>
            <li><strong>Berichtigung</strong> unrichtiger Daten (Art. 16)</li>
            <li><strong>Löschung</strong> deiner Daten (Art. 17) - siehe Account-Tab</li>
            <li><strong>Datenportabilitaet</strong> - Export deiner Daten (Art. 20) - siehe Account-Tab</li>
            <li><strong>Widerspruch</strong> gegen Verarbeitung (Art. 21)</li>
          </ul>
          <p className="text-xs text-gray-400">
            Bei Fragen zum Datenschutz wende dich an: info@mensaena.de
          </p>
        </div>
      </SettingsSection>

      {/* Save */}
      <div className="flex justify-end">
        <button
          onClick={handleSave}
          disabled={saving}
          className="flex items-center gap-2 px-6 py-2.5 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all disabled:opacity-50 min-h-[44px]"
        >
          {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
          Privatsphaere speichern
        </button>
      </div>
    </div>
  )
}
