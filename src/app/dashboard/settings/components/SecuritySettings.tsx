'use client'

import { useState } from 'react'
import { Lock, Key, Smartphone, Shield, AlertTriangle, Check, Loader2, Save } from 'lucide-react'
import toast from 'react-hot-toast'
import SettingsSection, { SettingRow } from './SettingsSection'
import EmergencyContacts from './EmergencyContacts'
import type { SettingsProfile, EmergencyContact } from '../types'

interface Props {
  settings: SettingsProfile
  onChangePassword: (currentPassword: string, newPassword: string) => Promise<{ success: boolean; error?: string }>
  onSave: (updates: Partial<SettingsProfile>, msg?: string) => Promise<boolean>
  saving: boolean
}

export default function SecuritySettings({ settings, onChangePassword, onSave, saving }: Props) {
  const [currentPassword, setCurrentPassword] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [changingPassword, setChangingPassword] = useState(false)
  const [emergencyContacts, setEmergencyContacts] = useState<EmergencyContact[]>(
    (settings.emergency_contacts as EmergencyContact[]) ?? []
  )

  const handlePasswordChange = async () => {
    if (!currentPassword) {
      toast.error('Bitte aktuelles Passwort eingeben')
      return
    }
    if (!newPassword || newPassword.length < 8) {
      toast.error('Passwort muss mindestens 8 Zeichen haben')
      return
    }
    if (newPassword !== confirmPassword) {
      toast.error('Passwoerter stimmen nicht ueberein')
      return
    }

    setChangingPassword(true)
    const result = await onChangePassword(currentPassword, newPassword)
    setChangingPassword(false)

    if (result.success) {
      toast.success('Passwort erfolgreich geaendert')
      setCurrentPassword('')
      setNewPassword('')
      setConfirmPassword('')
    } else {
      toast.error(result.error ?? 'Fehler beim Speichern. Bitte versuche es erneut.')
    }
  }

  const handleSaveEmergency = () => {
    onSave({ emergency_contacts: emergencyContacts as unknown as EmergencyContact[] }, 'Einstellungen gespeichert \u2713')
  }

  const passwordStrength = (() => {
    if (!newPassword) return null
    let score = 0
    if (newPassword.length >= 8) score++
    if (newPassword.length >= 12) score++
    if (/[A-Z]/.test(newPassword) && /[a-z]/.test(newPassword)) score++
    if (/\d/.test(newPassword)) score++
    if (/[^A-Za-z0-9]/.test(newPassword)) score++
    if (score <= 2) return { label: 'Schwach', color: 'bg-red-500', width: '33%' }
    if (score <= 3) return { label: 'Mittel', color: 'bg-amber-500', width: '66%' }
    return { label: 'Stark', color: 'bg-emerald-500', width: '100%' }
  })()

  return (
    <div className="space-y-5">
      {/* Password Change */}
      <SettingsSection
        icon={<Key className="w-4 h-4 text-emerald-700" />}
        title="Passwort ändern"
        description="Aendere dein Passwort regelmaessig für mehr Sicherheit"
      >
        <div className="space-y-4">
          <div>
            <label className="label">Aktuelles Passwort</label>
            <input
              type="password"
              value={currentPassword}
              onChange={e => setCurrentPassword(e.target.value)}
              placeholder="Dein aktuelles Passwort"
              className="input"
            />
          </div>
          <div>
            <label className="label">Neues Passwort</label>
            <input
              type="password"
              value={newPassword}
              onChange={e => setNewPassword(e.target.value)}
              placeholder="Mindestens 8 Zeichen"
              className="input"
              minLength={8}
            />
            {passwordStrength && (
              <div className="mt-2">
                <div className="w-full h-1.5 bg-gray-200 rounded-full overflow-hidden">
                  <div
                    className={`h-full rounded-full transition-all duration-300 ${passwordStrength.color}`}
                    style={{ width: passwordStrength.width }}
                  />
                </div>
                <p className="text-xs text-gray-500 mt-1">Staerke: {passwordStrength.label}</p>
              </div>
            )}
          </div>
          <div>
            <label className="label">Passwort bestätigen</label>
            <input
              type="password"
              value={confirmPassword}
              onChange={e => setConfirmPassword(e.target.value)}
              placeholder="Neues Passwort wiederholen"
              className="input"
            />
            {confirmPassword && newPassword !== confirmPassword && (
              <p className="text-xs text-red-600 mt-1">Passwoerter stimmen nicht ueberein</p>
            )}
            {confirmPassword && newPassword === confirmPassword && newPassword.length >= 8 && (
              <p className="text-xs text-emerald-600 mt-1 flex items-center gap-1">
                <Check className="w-3 h-3" /> Passwoerter stimmen ueberein
              </p>
            )}
          </div>
          <button
            onClick={handlePasswordChange}
            disabled={changingPassword || !currentPassword || !newPassword || newPassword !== confirmPassword || newPassword.length < 8}
            className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium bg-emerald-600 text-white hover:bg-emerald-700 transition-all disabled:opacity-50 min-h-[44px]"
          >
            {changingPassword ? <Loader2 className="w-4 h-4 animate-spin" /> : <Lock className="w-4 h-4" />}
            Passwort ändern
          </button>
        </div>
      </SettingsSection>

      {/* Verification Status */}
      <SettingsSection
        icon={<Shield className="w-4 h-4 text-emerald-700" />}
        title="Verifizierung"
        description="Dein Verifizierungs-Status bei Mensaena"
      >
        <div className="space-y-1">
          <SettingRow label="E-Mail verifiziert" description={settings.email}>
            <span className={`inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full font-medium ${
              settings.verified_email ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-500'
            }`}>
              {settings.verified_email ? <><Check className="w-3 h-3" /> Verifiziert</> : 'Ausstehend'}
            </span>
          </SettingRow>

          <SettingRow label="Telefon verifiziert" description={settings.phone ? `${settings.phone.slice(0, 6)}...` : 'Nicht hinterlegt'}>
            <span className={`inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full font-medium ${
              settings.verified_phone ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-500'
            }`}>
              {settings.verified_phone ? <><Check className="w-3 h-3" /> Verifiziert</> : 'Ausstehend'}
            </span>
          </SettingRow>

          <SettingRow label="Community verifiziert" description="Durch Nachbarn bestaetigt">
            <span className={`inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full font-medium ${
              settings.verified_community ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-500'
            }`}>
              {settings.verified_community ? <><Check className="w-3 h-3" /> Verifiziert</> : 'Ausstehend'}
            </span>
          </SettingRow>
        </div>

        <div className="mt-4 flex items-start gap-2 bg-amber-50 rounded-xl p-3">
          <AlertTriangle className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
          <p className="text-xs text-amber-700">
            Verifizierte Accounts erhalten einen hoeheren Trust-Score und werden in Suchergebnissen bevorzugt.
          </p>
        </div>
      </SettingsSection>

      {/* Emergency Contacts */}
      <SettingsSection
        icon={<Smartphone className="w-4 h-4 text-emerald-700" />}
        title="Notfall-Kontakte"
        description="Personen, die im Notfall kontaktiert werden können"
      >
        <EmergencyContacts
          contacts={emergencyContacts}
          onChange={setEmergencyContacts}
        />
        {emergencyContacts.length > 0 && (
          <div className="mt-4 flex justify-end">
            <button
              onClick={handleSaveEmergency}
              disabled={saving}
              className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium bg-emerald-600 text-white hover:bg-emerald-700 transition-all disabled:opacity-50 min-h-[44px]"
            >
              {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
              Notfall-Kontakte speichern
            </button>
          </div>
        )}
      </SettingsSection>

      {/* Active Sessions Info */}
      <SettingsSection
        icon={<Lock className="w-4 h-4 text-emerald-700" />}
        title="Aktive Sitzungen"
        description="Übersicht über aktive Anmeldungen"
      >
        <div className="flex items-center gap-3 p-3 rounded-xl bg-emerald-50 border border-emerald-200">
          <div className="w-8 h-8 rounded-full bg-emerald-100 flex items-center justify-center">
            <Check className="w-4 h-4 text-emerald-600" />
          </div>
          <div>
            <p className="text-sm font-medium text-gray-900">Aktuelle Sitzung</p>
            <p className="text-xs text-gray-500">Dieses Geraet · Gerade aktiv</p>
          </div>
        </div>
      </SettingsSection>
    </div>
  )
}
