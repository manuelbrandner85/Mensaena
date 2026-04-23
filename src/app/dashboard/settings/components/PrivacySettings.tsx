'use client'

import { useState, useCallback } from 'react'
import { useTranslations } from 'next-intl'
import { Shield, Eye, MessageCircle, UserX, Save, Loader2, Globe, Users, Lock, ShieldCheck } from 'lucide-react'
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
  const t = useTranslations('privacySettings')
  const tSettings = useTranslations('settings')
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

  const handleSave = () => onSave(local, tSettings('saved'))

  const visibilityIcon = local.profile_visibility === 'public'
    ? Globe
    : local.profile_visibility === 'neighbors' ? Users : Lock
  const visibilityLabel = local.profile_visibility === 'public'
    ? t('visibilityPublic')
    : local.profile_visibility === 'neighbors' ? t('visibilityNeighbors') : t('visibilityPrivate')
  const visibilityColor = local.profile_visibility === 'public'
    ? 'text-blue-600 bg-blue-50 border-blue-200'
    : local.profile_visibility === 'neighbors'
      ? 'text-primary-700 bg-primary-50 border-primary-200'
      : 'text-gray-700 bg-gray-100 border-gray-300'
  const messagesLabel = local.allow_messages_from === 'everyone'
    ? t('messagesEveryone')
    : local.allow_messages_from === 'trusted' ? t('messagesTrusted') : t('messagesNobody')
  const VisibilityIcon = visibilityIcon

  return (
    <div className="space-y-5">
      {/* Datenschutz-Zentrum – Übersicht */}
      <div className="bg-gradient-to-br from-primary-50 to-stone-50 border border-primary-100 rounded-2xl p-5">
        <div className="flex items-center gap-2 mb-4">
          <ShieldCheck className="w-5 h-5 text-primary-700" />
          <h3 className="font-bold text-ink-800">{t('centerTitle')}</h3>
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
          <div className={`rounded-xl border p-3 ${visibilityColor}`}>
            <div className="flex items-center gap-1.5 mb-1">
              <VisibilityIcon className="w-3.5 h-3.5" />
              <span className="text-[10px] font-semibold uppercase tracking-wide opacity-70">{t('centerProfile')}</span>
            </div>
            <p className="text-sm font-bold leading-tight">{visibilityLabel}</p>
          </div>
          <div className="rounded-xl border border-stone-200 bg-white p-3">
            <div className="flex items-center gap-1.5 mb-1">
              <MessageCircle className="w-3.5 h-3.5 text-ink-500" />
              <span className="text-[10px] font-semibold uppercase tracking-wide text-ink-400">{t('centerMessages')}</span>
            </div>
            <p className="text-sm font-bold leading-tight text-ink-800">{messagesLabel}</p>
          </div>
          <div className="rounded-xl border border-stone-200 bg-white p-3">
            <div className="flex items-center gap-1.5 mb-1">
              <Eye className="w-3.5 h-3.5 text-ink-500" />
              <span className="text-[10px] font-semibold uppercase tracking-wide text-ink-400">{t('centerOnline')}</span>
            </div>
            <p className="text-sm font-bold leading-tight text-ink-800">
              {local.show_online_status ? t('statusVisible') : t('statusHidden')}
            </p>
          </div>
          <div className="rounded-xl border border-stone-200 bg-white p-3">
            <div className="flex items-center gap-1.5 mb-1">
              <UserX className="w-3.5 h-3.5 text-ink-500" />
              <span className="text-[10px] font-semibold uppercase tracking-wide text-ink-400">{t('centerBlocked')}</span>
            </div>
            <p className="text-sm font-bold leading-tight text-ink-800">
              {t('blockedCountLabel', { count: blockedUsers.length })}
            </p>
          </div>
        </div>
        <p className="text-xs text-ink-500 mt-3 leading-relaxed">{t('centerSummary')}</p>
      </div>

      {/* Profile Visibility */}
      <SettingsSection
        icon={<Eye className="w-4 h-4 text-primary-700" />}
        title={t('sectionVisibilityTitle')}
        description={t('sectionVisibilityDesc')}
      >
        <div className="space-y-3">
          <div>
            <label className="label">{t('profileVisibilityLabel')}</label>
            <select
              value={local.profile_visibility}
              onChange={e => update('profile_visibility', e.target.value)}
              className="input"
            >
              <option value="public">{t('visibilityOptionPublic')}</option>
              <option value="neighbors">{t('visibilityOptionNeighbors')}</option>
              <option value="private">{t('visibilityOptionPrivate')}</option>
            </select>
          </div>

          <SettingRow label={t('showOnlineStatus')} description={t('showOnlineStatusDesc')}>
            <Toggle value={local.show_online_status} onChange={v => update('show_online_status', v)} />
          </SettingRow>

          <SettingRow label={t('showLocation')} description={t('showLocationDesc')}>
            <Toggle value={local.show_location} onChange={v => update('show_location', v)} />
          </SettingRow>

          <SettingRow label={t('showTrustScore')} description={t('showTrustScoreDesc')}>
            <Toggle value={local.show_trust_score} onChange={v => update('show_trust_score', v)} />
          </SettingRow>

          <SettingRow label={t('showActivity')} description={t('showActivityDesc')}>
            <Toggle value={local.show_activity} onChange={v => update('show_activity', v)} />
          </SettingRow>

          <SettingRow label={t('showPhone')} description={t('showPhoneDesc')}>
            <Toggle value={local.show_phone} onChange={v => update('show_phone', v)} />
          </SettingRow>
        </div>
      </SettingsSection>

      {/* Communication */}
      <SettingsSection
        icon={<MessageCircle className="w-4 h-4 text-primary-700" />}
        title={t('sectionCommTitle')}
        description={t('sectionCommDesc')}
      >
        <div className="space-y-3">
          <div>
            <label className="label">{t('messagesFromLabel')}</label>
            <select
              value={local.allow_messages_from}
              onChange={e => update('allow_messages_from', e.target.value)}
              className="input"
            >
              <option value="everyone">{t('messagesOptionEveryone')}</option>
              <option value="trusted">{t('messagesOptionTrusted')}</option>
              <option value="nobody">{t('messagesOptionNobody')}</option>
            </select>
          </div>

          <SettingRow label={t('readReceipts')} description={t('readReceiptsDesc')}>
            <Toggle value={local.read_receipts} onChange={v => update('read_receipts', v)} />
          </SettingRow>

          <SettingRow label={t('allowMatching')} description={t('allowMatchingDesc')}>
            <Toggle value={local.allow_matching} onChange={v => update('allow_matching', v)} />
          </SettingRow>
        </div>
      </SettingsSection>

      {/* Blocked Users */}
      <SettingsSection
        icon={<UserX className="w-4 h-4 text-primary-700" />}
        title={t('sectionBlockedTitle')}
        description={t('sectionBlockedDesc', { count: blockedUsers.length })}
      >
        <BlockedUsersList blockedUsers={blockedUsers} onUnblock={onUnblock} />
      </SettingsSection>

      {/* GDPR Info */}
      <SettingsSection
        icon={<Shield className="w-4 h-4 text-primary-700" />}
        title={t('sectionGdprTitle')}
        description={t('sectionGdprDesc')}
      >
        <div className="space-y-3 text-sm text-gray-600">
          <p>{t('gdprIntro')}</p>
          <ul className="list-disc list-inside space-y-1 text-xs text-gray-500">
            <li><strong>{t('gdprRight1')}</strong> {t('gdprRight1Desc')}</li>
            <li><strong>{t('gdprRight2')}</strong> {t('gdprRight2Desc')}</li>
            <li><strong>{t('gdprRight3')}</strong> {t('gdprRight3Desc')}</li>
            <li><strong>{t('gdprRight4')}</strong> {t('gdprRight4Desc')}</li>
            <li><strong>{t('gdprRight5')}</strong> {t('gdprRight5Desc')}</li>
          </ul>
          <p className="text-xs text-gray-400">{t('gdprContact')}</p>
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
          {t('saveButton')}
        </button>
      </div>
    </div>
  )
}
