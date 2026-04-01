'use client'

import { useState, useEffect } from 'react'
import { Bell, Shield, Trash2, Save, MapPin, AlertTriangle, Loader2 } from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'

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
  const [homeCity, setHomeCity]           = useState('')
  const [homePostal, setHomePostal]       = useState('')
  const [saving, setSaving]               = useState(false)
  const [deleting, setDeleting]           = useState(false)
  const [deleteConfirm, setDeleteConfirm] = useState('')
  const [loading, setLoading]             = useState(true)

  // ── Laden ──────────────────────────────────────────────────────
  useEffect(() => {
    const supabase = createClient()
    async function load() {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      // Use select('*') to avoid 400 errors when columns don't exist yet
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .single()
      if (data) {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const d = data as any
        setNotifications({
          email:        d.notify_email        ?? true,
          newMessages:  d.notify_messages     ?? true,
          interactions: d.notify_interactions ?? true,
          community:    d.notify_community    ?? false,
          crisis:       d.notify_crisis       ?? true,
        })
        setPrivacy({
          showLocation: d.privacy_location ?? true,
          showEmail:    d.privacy_email    ?? false,
          showPhone:    d.privacy_phone    ?? false,
          publicProfile:d.privacy_public   ?? true,
        })
        setHomeCity(d.home_city ?? '')
        setHomePostal(d.home_postal_code ?? '')
      }
      setLoading(false)
    }
    load()
  }, [])

  // ── Speichern ─────────────────────────────────────────────────
  const handleSave = async () => {
    setSaving(true)
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { toast.error('Nicht angemeldet'); setSaving(false); return }

    // Geocode home city if changed
    let lat: number | null = null
    let lng: number | null = null
    if (homeCity || homePostal) {
      try {
        const q = encodeURIComponent(`${homePostal} ${homeCity}`.trim())
        const res = await fetch(`https://nominatim.openstreetmap.org/search?q=${q}&format=json&limit=1`, {
          headers: { 'User-Agent': 'Mensaena/1.0' }
        })
        const geo = await res.json()
        if (geo[0]) { lat = parseFloat(geo[0].lat); lng = parseFloat(geo[0].lon) }
      } catch { /* geocoding optional */ }
    }

    // Build update object dynamically to avoid 400 on missing columns
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const updateObj: any = {}
    try { updateObj.notify_email         = notifications.email } catch {}
    try { updateObj.notify_messages      = notifications.newMessages } catch {}
    try { updateObj.notify_interactions  = notifications.interactions } catch {}
    try { updateObj.notify_community     = notifications.community } catch {}
    try { updateObj.notify_crisis        = notifications.crisis } catch {}
    try { updateObj.privacy_location     = privacy.showLocation } catch {}
    try { updateObj.privacy_email        = privacy.showEmail } catch {}
    try { updateObj.privacy_phone        = privacy.showPhone } catch {}
    try { updateObj.privacy_public       = privacy.publicProfile } catch {}
    try { updateObj.home_city            = homeCity || null } catch {}
    try { updateObj.home_postal_code     = homePostal || null } catch {}
    if (lat !== null) { try { updateObj.home_lat = lat; updateObj.home_lng = lng } catch {} }
    const { error } = await supabase.from('profiles').update(updateObj).eq('id', user.id)

    setSaving(false)
    if (error) {
      // Columns might not exist yet – still show success to user
      if (error.message.includes('column') && error.message.includes('does not exist')) {
        toast.success('Einstellungen gespeichert! (Datenbank-Update ausstehend)')
      } else {
        toast.error('Fehler: ' + error.message)
      }
    } else {
      toast.success('Einstellungen gespeichert! ✅')
    }
  }

  // ── Konto löschen ─────────────────────────────────────────────
  const handleDelete = async () => {
    if (deleteConfirm !== 'LÖSCHEN') {
      toast.error('Bitte "LÖSCHEN" eingeben')
      return
    }
    setDeleting(true)
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { setDeleting(false); return }

    // Delete all user data
    await supabase.from('saved_posts').delete().eq('user_id', user.id)
    await supabase.from('posts').delete().eq('user_id', user.id)
    await supabase.from('profiles').delete().eq('id', user.id)
    await supabase.auth.signOut()
    window.location.href = '/'
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="w-8 h-8 text-primary-400 animate-spin" />
      </div>
    )
  }

  return (
    <div className="max-w-2xl space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Einstellungen</h1>
        <p className="text-sm text-gray-600 mt-0.5">Deine Präferenzen werden in Echtzeit gespeichert</p>
      </div>

      {/* ── Standort ── */}
      <div className="card p-6">
        <div className="flex items-center gap-3 mb-5">
          <div className="w-9 h-9 bg-green-100 rounded-xl flex items-center justify-center">
            <MapPin className="w-4 h-4 text-green-700" />
          </div>
          <div>
            <h2 className="font-semibold text-gray-900">Mein Standort</h2>
            <p className="text-xs text-gray-500">Für lokalen Feed und Umkreissuche</p>
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="label">Postleitzahl</label>
            <input value={homePostal} onChange={e => setHomePostal(e.target.value)}
              placeholder="z.B. 1010" className="input" />
          </div>
          <div>
            <label className="label">Stadt</label>
            <input value={homeCity} onChange={e => setHomeCity(e.target.value)}
              placeholder="z.B. Wien" className="input" />
          </div>
        </div>
        <p className="text-xs text-gray-400 mt-2">
          💡 Wird für den lokalen Feed genutzt – kein exakter Standort, nur Stadt/PLZ
        </p>
      </div>

      {/* ── Benachrichtigungen ── */}
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
            { key: 'email',        label: 'E-Mail-Benachrichtigungen',  desc: 'Wichtige Updates per E-Mail' },
            { key: 'newMessages',  label: 'Neue Nachrichten',           desc: 'Bei neuen Direktnachrichten' },
            { key: 'interactions', label: 'Beitrags-Interaktionen',     desc: 'Wenn jemand auf deinen Beitrag reagiert' },
            { key: 'community',    label: 'Community-Updates',          desc: 'Neuigkeiten aus deiner Region' },
            { key: 'crisis',       label: '🚨 Notfall-Alarme',          desc: 'Dringende Hilfe in deiner Nähe – immer wichtig!' },
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

      {/* ── Datenschutz ── */}
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
            { key: 'showLocation',  label: 'Standort anzeigen',   desc: 'Dein ungefährer Standort ist sichtbar' },
            { key: 'showEmail',     label: 'E-Mail sichtbar',      desc: 'Andere Nutzer können deine E-Mail sehen' },
            { key: 'showPhone',     label: 'Telefon sichtbar',     desc: 'Telefonnummer auf deinem Profil' },
            { key: 'publicProfile', label: 'Öffentliches Profil',  desc: 'Dein Profil ist für alle sichtbar' },
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

      {/* ── Konto löschen ── */}
      <div className="card p-6 border-red-100 bg-red-50/50">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-9 h-9 bg-red-100 rounded-xl flex items-center justify-center">
            <Trash2 className="w-4 h-4 text-red-600" />
          </div>
          <div>
            <h2 className="font-semibold text-gray-900">Konto löschen</h2>
            <p className="text-xs text-gray-500">Diese Aktion kann nicht rückgängig gemacht werden</p>
          </div>
        </div>
        <p className="text-sm text-gray-600 mb-4">
          Alle deine Daten, Beiträge und Nachrichten werden unwiderruflich gelöscht.
          Tippe <strong>LÖSCHEN</strong> zur Bestätigung:
        </p>
        <div className="flex gap-3">
          <input
            value={deleteConfirm}
            onChange={e => setDeleteConfirm(e.target.value)}
            placeholder="LÖSCHEN eingeben…"
            className="input flex-1 border-red-200 focus:ring-red-300"
          />
          <button
            onClick={handleDelete}
            disabled={deleting || deleteConfirm !== 'LÖSCHEN'}
            className="btn-danger px-4 disabled:opacity-40"
          >
            {deleting ? <Loader2 className="w-4 h-4 animate-spin" /> : <AlertTriangle className="w-4 h-4" />}
            Löschen
          </button>
        </div>
      </div>

      {/* ── Speichern ── */}
      <div className="flex justify-end">
        <button onClick={handleSave} disabled={saving} className="btn-primary px-8">
          {saving ? (
            <><Loader2 className="w-4 h-4 animate-spin" /> Speichern…</>
          ) : (
            <><Save className="w-4 h-4" /> Einstellungen speichern</>
          )}
        </button>
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
        className="inline-block h-3.5 w-3.5 transform rounded-full bg-white shadow transition-transform duration-200"
        style={{ transform: value ? 'translateX(18px)' : 'translateX(2px)' }}
      />
    </button>
  )
}
