'use client'

import { useState } from 'react'
import { Settings, LogOut, Trash2, Download, GraduationCap, Loader2, Save, Check, FileJson } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { formatDate } from '@/lib/utils'
import toast from 'react-hot-toast'
import SettingsSection, { Toggle, SettingRow } from './SettingsSection'
import DeleteAccountModal from './DeleteAccountModal'
import type { SettingsProfile, DataExport } from '../types'

interface Props {
  settings: SettingsProfile
  userId: string
  onSave: (updates: Partial<SettingsProfile>, msg?: string) => Promise<boolean>
  onExport: () => Promise<DataExport | null>
  onRequestDeletion: () => Promise<boolean>
  onConfirmDeletion: () => Promise<boolean>
  onCountData: () => Promise<{
    posts: number
    messages: number
    interactions: number
    saved_posts: number
    trust_ratings: number
    conversations: number
    notifications: number
  }>
  saving: boolean
}

const MENTOR_TOPICS = [
  'Nachbarschaftshilfe', 'Handwerk', 'IT & Technik', 'Kochen & Ernaehrung',
  'Garten & Natur', 'Kinderbetreuung', 'Pflege & Gesundheit', 'Sprachen',
  'Mobiliaet', 'Finanzen & Behoerden', 'Sport & Bewegung', 'Kultur & Kreatives',
]

export default function AccountSettings({
  settings, userId, onSave, onExport, onRequestDeletion, onConfirmDeletion, onCountData, saving,
}: Props) {
  const [showDeleteModal, setShowDeleteModal] = useState(false)
  const [isMentor, setIsMentor] = useState(settings.is_mentor ?? false)
  const [mentorTopics, setMentorTopics] = useState<string[]>(settings.mentor_topics ?? [])
  const [loggingOut, setLoggingOut] = useState(false)
  const [exporting, setExporting] = useState(false)

  const toggleTopic = (topic: string) => {
    setMentorTopics(prev =>
      prev.includes(topic) ? prev.filter(t => t !== topic) : [...prev, topic]
    )
  }

  const handleSaveMentor = () => {
    onSave({ is_mentor: isMentor, mentor_topics: mentorTopics }, 'Einstellungen gespeichert ✓')
  }

  const handleExport = async () => {
    setExporting(true)
    toast('Daten werden exportiert...', { icon: 'ℹ️' })
    await onExport()
    setExporting(false)
  }

  const handleLogout = async () => {
    setLoggingOut(true)
    const supabase = createClient()
    await supabase.auth.signOut()
    window.location.href = '/'
  }

  return (
    <div className="space-y-5">
      {/* Account Info */}
      <SettingsSection
        icon={<Settings className="w-4 h-4 text-primary-700" />}
        title="Account-Informationen"
        description="Dein Mensaena-Account"
      >
        <div className="space-y-1">
          <SettingRow label="E-Mail" description="Deine registrierte E-Mail-Adresse">
            <span className="text-sm text-gray-700">{settings.email}</span>
          </SettingRow>
          <SettingRow label="Mitglied seit" description="Registrierungsdatum">
            <span className="text-sm text-gray-700">{settings.created_at ? formatDate(settings.created_at) : 'Unbekannt'}</span>
          </SettingRow>
          <SettingRow label="Letztes Update" description="Letzte Profil-Änderung">
            <span className="text-sm text-gray-700">{settings.updated_at ? formatDate(settings.updated_at) : 'Nie'}</span>
          </SettingRow>
          <SettingRow label="Account-ID" description="Deine eindeutige Kennung">
            <span className="text-xs text-gray-400 font-mono">{userId.slice(0, 8)}...</span>
          </SettingRow>
        </div>
      </SettingsSection>

      {/* Mentor Settings */}
      <SettingsSection
        icon={<GraduationCap className="w-4 h-4 text-primary-700" />}
        title="Mentor-Programm"
        description="Als Mentor anderen Nachbarn helfen"
      >
        <div className="space-y-4">
          <SettingRow
            label="Als Mentor verfügbar"
            description="Andere Nutzer können dich als Mentor anfragen"
          >
            <Toggle value={isMentor} onChange={v => setIsMentor(v)} />
          </SettingRow>

          {isMentor && (
            <div>
              <label className="label">Themengebiete</label>
              <div className="flex flex-wrap gap-2">
                {MENTOR_TOPICS.map(topic => (
                  <button
                    key={topic}
                    onClick={() => toggleTopic(topic)}
                    className={`text-xs px-3 py-1.5 rounded-full font-medium border transition-all min-h-[36px] ${
                      mentorTopics.includes(topic)
                        ? 'bg-primary-100 text-primary-700 border-primary-300'
                        : 'bg-white text-gray-500 border-gray-200 hover:border-gray-300'
                    }`}
                  >
                    {mentorTopics.includes(topic) && <Check className="w-3 h-3 inline mr-1" />}
                    {topic}
                  </button>
                ))}
              </div>
            </div>
          )}

          <div className="flex justify-end">
            <button
              onClick={handleSaveMentor}
              disabled={saving}
              className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all disabled:opacity-50 min-h-[44px]"
            >
              {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
              Speichern
            </button>
          </div>
        </div>
      </SettingsSection>

      {/* Data Export (DSGVO) */}
      <SettingsSection
        icon={<Download className="w-4 h-4 text-primary-700" />}
        title="Daten-Export"
        description="DSGVO Art. 20 - Recht auf Datenportabilitaet"
      >
        <div className="flex items-center gap-4 p-4 rounded-xl bg-primary-50 border border-primary-200">
          <div className="w-10 h-10 rounded-xl bg-primary-100 flex items-center justify-center flex-shrink-0">
            <FileJson className="w-5 h-5 text-primary-600" />
          </div>
          <div className="flex-1">
            <p className="text-sm font-medium text-gray-900">Daten exportieren (DSGVO Art. 20)</p>
            <p className="text-xs text-gray-500">Lade alle deine gespeicherten Daten als JSON-Datei herunter</p>
          </div>
          <button
            onClick={handleExport}
            disabled={exporting}
            className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all disabled:opacity-50 min-h-[44px]"
          >
            {exporting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Download className="w-4 h-4" />}
            {exporting ? 'Exportiere...' : 'Exportieren'}
          </button>
        </div>
      </SettingsSection>

      {/* Logout */}
      <SettingsSection
        icon={<LogOut className="w-4 h-4 text-primary-700" />}
        title="Abmelden"
        description="Von diesem Geraet abmelden"
      >
        <button
          onClick={handleLogout}
          disabled={loggingOut}
          className="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium border border-gray-200 text-gray-700 hover:bg-gray-50 transition-all disabled:opacity-50 min-h-[44px]"
        >
          {loggingOut ? <Loader2 className="w-4 h-4 animate-spin" /> : <LogOut className="w-4 h-4" />}
          Abmelden
        </button>
      </SettingsSection>

      {/* Delete Account – DANGER ZONE (red only) */}
      <SettingsSection
        icon={<Trash2 className="w-4 h-4 text-red-600" />}
        title="Account löschen"
        description="Alle deine Daten werden unwiderruflich gelöscht"
        danger
      >
        <div className="space-y-3">
          {settings.deletion_requested_at && !settings.deletion_confirmed ? (
            <div className="bg-amber-50 border border-amber-200 rounded-xl p-4">
              <p className="text-sm text-amber-800 font-medium mb-1">
                Löschung vorgemerkt
              </p>
              <p className="text-xs text-amber-700">
                Dein Account ist zur Löschung vorgemerkt seit {formatDate(settings.deletion_requested_at)}.
                Du hast 14 Tage um die Löschung zu widerrufen.
              </p>
              <div className="flex gap-2 mt-3">
                <button
                  onClick={() => onSave({ deletion_requested_at: null as unknown as string, deletion_confirmed: false }, 'Löschung widerrufen')}
                  className="text-xs px-3 py-1.5 rounded-lg font-medium bg-white text-amber-700 border border-amber-300 hover:bg-amber-100 transition-colors min-h-[36px]"
                >
                  Widerrufen
                </button>
                <button
                  onClick={() => setShowDeleteModal(true)}
                  className="text-xs px-3 py-1.5 rounded-lg font-medium bg-red-600 text-white hover:bg-red-700 transition-colors min-h-[36px]"
                >
                  Endgültig löschen
                </button>
              </div>
            </div>
          ) : (
            <>
              <p className="text-sm text-gray-600">
                Gemäß DSGVO Art. 17 hast du das Recht, die Löschung deiner personenbezogenen Daten zu verlangen.
                Deine Beiträge werden anonymisiert, nicht gelöscht, um die Community-Integrität zu wahren.
              </p>
              <button
                onClick={() => setShowDeleteModal(true)}
                className="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium bg-red-600 text-white hover:bg-red-700 transition-all min-h-[44px]"
              >
                <Trash2 className="w-4 h-4" />
                Account löschen...
              </button>
            </>
          )}
        </div>
      </SettingsSection>

      {/* Delete Modal */}
      <DeleteAccountModal
        userId={userId}
        open={showDeleteModal}
        onClose={() => setShowDeleteModal(false)}
        onRequestDeletion={onRequestDeletion}
        onConfirmDeletion={onConfirmDeletion}
        onCountData={onCountData}
      />
    </div>
  )
}
