'use client'

import { useState } from 'react'
import { useTranslations } from 'next-intl'
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
  const t = useTranslations('securitySettings')
  const tSettings = useTranslations('settings')
  const [currentPassword, setCurrentPassword] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [changingPassword, setChangingPassword] = useState(false)
  const [emergencyContacts, setEmergencyContacts] = useState<EmergencyContact[]>(
    (settings.emergency_contacts as EmergencyContact[]) ?? []
  )

  const handlePasswordChange = async () => {
    if (!currentPassword) {
      toast.error(t('toastNoCurrentPassword'))
      return
    }
    if (!newPassword || newPassword.length < 8) {
      toast.error(t('toastPasswordTooShort'))
      return
    }
    if (newPassword !== confirmPassword) {
      toast.error(t('toastPasswordMismatch'))
      return
    }

    setChangingPassword(true)
    const result = await onChangePassword(currentPassword, newPassword)
    setChangingPassword(false)

    if (result.success) {
      toast.success(t('toastPasswordChanged'))
      setCurrentPassword('')
      setNewPassword('')
      setConfirmPassword('')
    } else {
      toast.error(result.error ?? t('toastSaveError'))
    }
  }

  const handleSaveEmergency = () => {
    onSave({ emergency_contacts: emergencyContacts as unknown as EmergencyContact[] }, tSettings('saved'))
  }

  const passwordStrength = (() => {
    if (!newPassword) return null
    let score = 0
    if (newPassword.length >= 8) score++
    if (newPassword.length >= 12) score++
    if (/[A-Z]/.test(newPassword) && /[a-z]/.test(newPassword)) score++
    if (/\d/.test(newPassword)) score++
    if (/[^A-Za-z0-9]/.test(newPassword)) score++
    if (score <= 2) return { label: t('strengthWeak'), color: 'bg-red-500', width: '33%' }
    if (score <= 3) return { label: t('strengthFair'), color: 'bg-amber-500', width: '66%' }
    return { label: t('strengthStrong'), color: 'bg-primary-500', width: '100%' }
  })()

  return (
    <div className="space-y-5">
      {/* Password Change */}
      <SettingsSection
        icon={<Key className="w-4 h-4 text-primary-700" />}
        title={t('sectionPasswordTitle')}
        description={t('sectionPasswordDesc')}
      >
        <div className="space-y-4">
          <div>
            <label className="label">{t('currentPassword')}</label>
            <input
              type="password"
              value={currentPassword}
              onChange={e => setCurrentPassword(e.target.value)}
              placeholder={t('currentPasswordPlaceholder')}
              className="input"
            />
          </div>
          <div>
            <label className="label">{t('newPassword')}</label>
            <input
              type="password"
              value={newPassword}
              onChange={e => setNewPassword(e.target.value)}
              placeholder={t('newPasswordPlaceholder')}
              className="input"
              minLength={8}
            />
            {passwordStrength && (
              <div className="mt-2">
                <div className="w-full h-1.5 bg-stone-200 rounded-full overflow-hidden">
                  <div
                    className={`h-full rounded-full transition-all duration-300 ${passwordStrength.color}`}
                    style={{ width: passwordStrength.width }}
                  />
                </div>
                <p className="text-xs text-ink-500 mt-1">{t('strengthLabel', { label: passwordStrength.label })}</p>
              </div>
            )}
          </div>
          <div>
            <label className="label">{t('confirmPassword')}</label>
            <input
              type="password"
              value={confirmPassword}
              onChange={e => setConfirmPassword(e.target.value)}
              placeholder={t('confirmPasswordPlaceholder')}
              className="input"
            />
            {confirmPassword && newPassword !== confirmPassword && (
              <p className="text-xs text-red-600 mt-1">{t('passwordMismatch')}</p>
            )}
            {confirmPassword && newPassword === confirmPassword && newPassword.length >= 8 && (
              <p className="text-xs text-primary-600 mt-1 flex items-center gap-1">
                <Check className="w-3 h-3" /> {t('passwordMatch')}
              </p>
            )}
          </div>
          <button
            onClick={handlePasswordChange}
            disabled={changingPassword || !currentPassword || !newPassword || newPassword !== confirmPassword || newPassword.length < 8}
            className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all disabled:opacity-50 min-h-[44px]"
          >
            {changingPassword ? <Loader2 className="w-4 h-4 animate-spin" /> : <Lock className="w-4 h-4" />}
            {t('changePasswordButton')}
          </button>
        </div>
      </SettingsSection>

      {/* Verification Status */}
      <SettingsSection
        icon={<Shield className="w-4 h-4 text-primary-700" />}
        title={t('sectionVerifyTitle')}
        description={t('sectionVerifyDesc')}
      >
        <div className="space-y-1">
          <SettingRow label={t('emailVerified')} description={settings.email}>
            <span className={`inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full font-medium ${
              settings.verified_email ? 'bg-primary-100 text-primary-700' : 'bg-stone-100 text-ink-500'
            }`}>
              {settings.verified_email ? <><Check className="w-3 h-3" /> {t('verified')}</> : t('pending')}
            </span>
          </SettingRow>

          <SettingRow label={t('phoneVerified')} description={settings.phone ? `${settings.phone.slice(0, 6)}...` : t('phoneNotSet')}>
            <span className={`inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full font-medium ${
              settings.verified_phone ? 'bg-primary-100 text-primary-700' : 'bg-stone-100 text-ink-500'
            }`}>
              {settings.verified_phone ? <><Check className="w-3 h-3" /> {t('verified')}</> : t('pending')}
            </span>
          </SettingRow>

          <SettingRow label={t('communityVerified')} description={t('communityVerifiedDesc')}>
            <span className={`inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full font-medium ${
              settings.verified_community ? 'bg-primary-100 text-primary-700' : 'bg-stone-100 text-ink-500'
            }`}>
              {settings.verified_community ? <><Check className="w-3 h-3" /> {t('verified')}</> : t('pending')}
            </span>
          </SettingRow>
        </div>

        <div className="mt-4 flex items-start gap-2 bg-amber-50 rounded-xl p-3">
          <AlertTriangle className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
          <p className="text-xs text-amber-700">{t('verifyInfo')}</p>
        </div>
      </SettingsSection>

      {/* Emergency Contacts */}
      <SettingsSection
        icon={<Smartphone className="w-4 h-4 text-primary-700" />}
        title={t('sectionEmergencyTitle')}
        description={t('sectionEmergencyDesc')}
      >
        <EmergencyContacts contacts={emergencyContacts} onChange={setEmergencyContacts} />
        {emergencyContacts.length > 0 && (
          <div className="mt-4 flex justify-end">
            <button
              onClick={handleSaveEmergency}
              disabled={saving}
              className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all disabled:opacity-50 min-h-[44px]"
            >
              {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
              {t('saveEmergencyButton')}
            </button>
          </div>
        )}
      </SettingsSection>

      {/* Active Sessions */}
      <SettingsSection
        icon={<Lock className="w-4 h-4 text-primary-700" />}
        title={t('sectionSessionsTitle')}
        description={t('sectionSessionsDesc')}
      >
        <div className="flex items-center gap-3 p-3 rounded-xl bg-primary-50 border border-primary-200">
          <div className="w-8 h-8 rounded-full bg-primary-100 flex items-center justify-center">
            <Check className="w-4 h-4 text-primary-600" />
          </div>
          <div>
            <p className="text-sm font-medium text-ink-900">{t('currentSession')}</p>
            <p className="text-xs text-ink-500">{t('currentSessionDesc')}</p>
          </div>
        </div>
      </SettingsSection>
    </div>
  )
}
