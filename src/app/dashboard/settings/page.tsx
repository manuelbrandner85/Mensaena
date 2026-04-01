'use client'
export const runtime = 'edge'

import { useState } from 'react'
import { Bell, Shield, Eye, Smartphone, Globe, Trash2, Save } from 'lucide-react'
import toast from 'react-hot-toast'

export default function SettingsPage() {
  const [notifications, setNotifications] = useState({
    email: true,
    newMessages: true,
    interactions: true,
    community: false,
    crisis: true,
  })
  const [privacy, setPrivacy] = useState({
    showLocation: true,
    showEmail: false,
    showPhone: false,
    publicProfile: true,
  })
  const [saving, setSaving] = useState(false)

  const handleSave = async () => {
    setSaving(true)
    await new Promise((r) => setTimeout(r, 800))
    toast.success('Einstellungen gespeichert!')
    setSaving(false)
  }

  return (
    <div className="max-w-2xl">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Einstellungen</h1>
        <p className="text-sm text-gray-600 mt-0.5">Verwalte deine Präferenzen und Privatsphäre</p>
      </div>

      <div className="space-y-6">
        {/* Notifications */}
        <div className="card p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="w-9 h-9 bg-primary-100 rounded-xl flex items-center justify-center">
              <Bell className="w-4 h-4 text-primary-700" />
            </div>
            <div>
              <h2 className="font-semibold text-gray-900">Benachrichtigungen</h2>
              <p className="text-xs text-gray-500">Lege fest, worüber du informiert werden möchtest</p>
            </div>
          </div>
          <div className="space-y-4">
            {[
              { key: 'email', label: 'E-Mail-Benachrichtigungen', desc: 'Wichtige Updates per E-Mail erhalten' },
              { key: 'newMessages', label: 'Neue Nachrichten', desc: 'Benachrichtigung bei neuen Direktnachrichten' },
              { key: 'interactions', label: 'Beitrags-Interaktionen', desc: 'Wenn jemand auf deinen Beitrag reagiert' },
              { key: 'community', label: 'Community-Updates', desc: 'Neuigkeiten aus deiner Region' },
              { key: 'crisis', label: 'Notfall-Alarme', desc: 'Dringende Hilfe in deiner Nähe' },
            ].map((item) => (
              <div key={item.key} className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-900">{item.label}</p>
                  <p className="text-xs text-gray-500">{item.desc}</p>
                </div>
                <Toggle
                  value={notifications[item.key as keyof typeof notifications]}
                  onChange={(v) => setNotifications((n) => ({ ...n, [item.key]: v }))}
                />
              </div>
            ))}
          </div>
        </div>

        {/* Privacy */}
        <div className="card p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="w-9 h-9 bg-trust-100 rounded-xl flex items-center justify-center">
              <Shield className="w-4 h-4 text-trust-400" />
            </div>
            <div>
              <h2 className="font-semibold text-gray-900">Datenschutz</h2>
              <p className="text-xs text-gray-500">Steuere, was andere über dich sehen können</p>
            </div>
          </div>
          <div className="space-y-4">
            {[
              { key: 'showLocation', label: 'Standort anzeigen', desc: 'Dein ungefährer Standort ist sichtbar' },
              { key: 'showEmail', label: 'E-Mail sichtbar', desc: 'Andere Nutzer können deine E-Mail sehen' },
              { key: 'showPhone', label: 'Telefon sichtbar', desc: 'Telefonnummer auf deinem Profil anzeigen' },
              { key: 'publicProfile', label: 'Öffentliches Profil', desc: 'Dein Profil ist für alle sichtbar' },
            ].map((item) => (
              <div key={item.key} className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-900">{item.label}</p>
                  <p className="text-xs text-gray-500">{item.desc}</p>
                </div>
                <Toggle
                  value={privacy[item.key as keyof typeof privacy]}
                  onChange={(v) => setPrivacy((p) => ({ ...p, [item.key]: v }))}
                />
              </div>
            ))}
          </div>
        </div>

        {/* Danger Zone */}
        <div className="card p-6 border-red-100 bg-red-50/50">
          <div className="flex items-center gap-3 mb-5">
            <div className="w-9 h-9 bg-red-100 rounded-xl flex items-center justify-center">
              <Trash2 className="w-4 h-4 text-red-600" />
            </div>
            <div>
              <h2 className="font-semibold text-gray-900">Konto löschen</h2>
              <p className="text-xs text-gray-500">Diese Aktion kann nicht rückgängig gemacht werden</p>
            </div>
          </div>
          <p className="text-sm text-gray-600 mb-4">
            Wenn du dein Konto löschst, werden alle deine Daten, Beiträge und Nachrichten unwiderruflich entfernt.
          </p>
          <button className="btn-danger text-sm px-4 py-2">
            Konto dauerhaft löschen
          </button>
        </div>

        {/* Save */}
        <div className="flex justify-end">
          <button onClick={handleSave} disabled={saving} className="btn-primary px-8">
            {saving ? (
              <>
                <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                Speichern…
              </>
            ) : (
              <>
                <Save className="w-4 h-4" />
                Einstellungen speichern
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}

function Toggle({ value, onChange }: { value: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      type="button"
      onClick={() => onChange(!value)}
      className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors duration-200 focus:outline-none
        ${value ? 'bg-primary-600' : 'bg-gray-200'}`}
    >
      <span
        className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white shadow transition-transform duration-200
          ${value ? 'translate-x-4.5' : 'translate-x-0.5'}`}
        style={{ transform: value ? 'translateX(18px)' : 'translateX(2px)' }}
      />
    </button>
  )
}
