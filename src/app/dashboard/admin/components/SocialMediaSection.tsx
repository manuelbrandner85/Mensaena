'use client'

import { useCallback, useEffect, useState } from 'react'
import {
  Loader2, CheckCircle2, XCircle, AlertTriangle, Save, Trash2, RefreshCw,
  ExternalLink, ChevronDown, ChevronUp,
} from 'lucide-react'
import toast from 'react-hot-toast'
import type { SocialMediaChannel } from './AdminTypes'

const PLATFORMS = [
  {
    key: 'facebook' as const,
    label: 'Facebook',
    color: 'bg-blue-50 text-blue-700 border-blue-100',
    icon: '📘',
    fields: ['access_token', 'page_id'] as const,
    helpUrl: 'https://developers.facebook.com/docs/pages-api/getting-started',
    helpSteps: [
      'Gehe zu developers.facebook.com und erstelle eine App',
      'Wähle "Business" als App-Typ',
      'Gehe zu Tools → Graph API Explorer',
      'Wähle deine Facebook-Seite und generiere einen Page Access Token',
      'Kopiere den Token und die Page-ID hier ein',
    ],
  },
  {
    key: 'instagram' as const,
    label: 'Instagram',
    color: 'bg-pink-50 text-pink-700 border-pink-100',
    icon: '📷',
    fields: ['access_token', 'page_id'] as const,
    helpUrl: 'https://developers.facebook.com/docs/instagram-api/getting-started',
    helpSteps: [
      'Instagram Business-Account mit einer Facebook-Seite verknüpfen',
      'In der Facebook App unter Instagram → Basic Display',
      'Instagram Business Account ID kopieren (als Page ID)',
      'Den selben Page Access Token wie bei Facebook verwenden',
    ],
  },
  {
    key: 'x' as const,
    label: 'X / Twitter',
    color: 'bg-gray-100 text-gray-800 border-gray-200',
    icon: '𝕏',
    fields: ['access_token'] as const,
    helpUrl: 'https://developer.x.com/en/docs/authentication/oauth-2-0',
    helpSteps: [
      'Gehe zu developer.x.com und erstelle ein Developer-Konto',
      'Erstelle ein neues Projekt und eine App',
      'Unter "Keys and Tokens" → Bearer Token generieren',
      'Für Posting: OAuth 2.0 User Access Token mit write-Scope erstellen',
      'Token hier einfügen',
    ],
  },
  {
    key: 'linkedin' as const,
    label: 'LinkedIn',
    color: 'bg-sky-50 text-sky-700 border-sky-100',
    icon: '💼',
    fields: ['access_token', 'page_id'] as const,
    helpUrl: 'https://learn.microsoft.com/en-us/linkedin/marketing/',
    helpSteps: [
      'Gehe zu linkedin.com/developers und erstelle eine App',
      'Unter "Auth" den Access Token generieren',
      'Organization ID von deiner LinkedIn-Unternehmensseite kopieren (URL: /company/123456)',
      'Token + Organization ID hier einfügen',
    ],
  },
]

export default function SocialMediaSection() {
  const [channels, setChannels] = useState<SocialMediaChannel[]>([])
  const [loading, setLoading] = useState(true)
  const [expandedPlatform, setExpandedPlatform] = useState<string | null>(null)
  const [verifying, setVerifying] = useState<string | null>(null)
  const [saving, setSaving] = useState<string | null>(null)

  // Form-State für jede Plattform
  const [formData, setFormData] = useState<Record<string, {
    access_token: string
    page_id: string
    api_key: string
    api_secret: string
  }>>({})

  const loadChannels = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch('/api/social-media/channels')
      if (!res.ok) throw new Error()
      const data = await res.json()
      setChannels(data as SocialMediaChannel[])
    } catch {
      toast.error('Kanäle konnten nicht geladen werden')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { loadChannels() }, [loadChannels])

  const getChannel = (platform: string) => channels.find(c => c.platform === platform)

  const getFormValue = (platform: string, field: string) => {
    return formData[platform]?.[field as keyof typeof formData[string]] || ''
  }

  const setFormValue = (platform: string, field: string, value: string) => {
    setFormData(prev => ({
      ...prev,
      [platform]: { ...prev[platform], [field]: value },
    }))
  }

  const handleSave = async (platform: string) => {
    setSaving(platform)
    try {
      const data = formData[platform] || {}
      const res = await fetch('/api/social-media/channels', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          platform,
          label: PLATFORMS.find(p => p.key === platform)?.label || platform,
          access_token: data.access_token || undefined,
          page_id: data.page_id || undefined,
          api_key: data.api_key || undefined,
          api_secret: data.api_secret || undefined,
        }),
      })
      if (!res.ok) throw new Error()
      toast.success('Gespeichert')
      await loadChannels()
      // Form leeren
      setFormData(prev => ({ ...prev, [platform]: { access_token: '', page_id: '', api_key: '', api_secret: '' } }))
    } catch {
      toast.error('Speichern fehlgeschlagen')
    } finally {
      setSaving(null)
    }
  }

  const handleVerify = async (platform: string) => {
    setVerifying(platform)
    try {
      const res = await fetch('/api/social-media/channels/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ platform }),
      })
      const data = await res.json()
      if (data.ok) {
        toast.success(`${platform} verbunden${data.info ? ` (${data.info})` : ''}`)
      } else {
        toast.error(data.error || 'Verbindung fehlgeschlagen')
      }
      await loadChannels()
    } catch {
      toast.error('Verifikation fehlgeschlagen')
    } finally {
      setVerifying(null)
    }
  }

  const handleDelete = async (platform: string) => {
    if (!confirm(`${platform} Kanal wirklich entfernen?`)) return
    try {
      const res = await fetch(`/api/social-media/channels?platform=${platform}`, { method: 'DELETE' })
      if (!res.ok) throw new Error()
      toast.success('Kanal entfernt')
      await loadChannels()
    } catch {
      toast.error('Löschen fehlgeschlagen')
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-16">
        <Loader2 className="w-6 h-6 text-primary-500 animate-spin" />
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {/* Info */}
      <div className="bg-primary-50 border border-primary-100 rounded-2xl p-4">
        <p className="text-xs text-primary-800 leading-relaxed">
          Verbinde deine Social-Media-Kanäle mit API-Tokens. Klicke auf eine Plattform, um die Schritt-für-Schritt-Anleitung zu sehen und deinen Token einzugeben.
        </p>
      </div>

      {/* Platform Cards */}
      {PLATFORMS.map(platform => {
        const channel = getChannel(platform.key)
        const isExpanded = expandedPlatform === platform.key

        return (
          <div key={platform.key} className="bg-white border border-gray-100 rounded-2xl overflow-hidden shadow-sm">
            {/* Header */}
            <button
              onClick={() => setExpandedPlatform(isExpanded ? null : platform.key)}
              className="w-full flex items-center justify-between p-4 hover:bg-gray-50 transition-colors"
            >
              <div className="flex items-center gap-3">
                <div className={`w-10 h-10 rounded-xl border flex items-center justify-center text-lg ${platform.color}`}>
                  {platform.icon}
                </div>
                <div className="text-left">
                  <p className="text-sm font-bold text-gray-900">{platform.label}</p>
                  <div className="flex items-center gap-2 mt-0.5">
                    {channel?.is_connected ? (
                      <span className="flex items-center gap-1 text-xs text-green-600">
                        <CheckCircle2 className="w-3 h-3" /> Verbunden
                      </span>
                    ) : channel ? (
                      <span className="flex items-center gap-1 text-xs text-amber-600">
                        <AlertTriangle className="w-3 h-3" /> Token gespeichert, nicht verifiziert
                      </span>
                    ) : (
                      <span className="flex items-center gap-1 text-xs text-gray-400">
                        <XCircle className="w-3 h-3" /> Nicht konfiguriert
                      </span>
                    )}
                    {channel?.last_verified && (
                      <span className="text-xs text-gray-400">
                        · Geprüft: {new Date(channel.last_verified).toLocaleDateString('de-DE')}
                      </span>
                    )}
                  </div>
                </div>
              </div>
              {isExpanded ? <ChevronUp className="w-4 h-4 text-gray-400" /> : <ChevronDown className="w-4 h-4 text-gray-400" />}
            </button>

            {/* Expanded: Anleitung + Token-Eingabe */}
            {isExpanded && (
              <div className="border-t border-gray-100 p-4 space-y-4">
                {/* Anleitung */}
                <div className="bg-gray-50 rounded-xl p-4">
                  <p className="text-xs font-bold text-gray-700 mb-2">Schritt-für-Schritt Anleitung:</p>
                  <ol className="space-y-1.5">
                    {platform.helpSteps.map((step, i) => (
                      <li key={i} className="text-xs text-gray-600 flex gap-2">
                        <span className="text-primary-600 font-bold flex-shrink-0">{i + 1}.</span>
                        {step}
                      </li>
                    ))}
                  </ol>
                  <a
                    href={platform.helpUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1 text-xs text-primary-600 hover:underline mt-3"
                  >
                    <ExternalLink className="w-3 h-3" /> Offizielle Dokumentation
                  </a>
                </div>

                {/* Token-Felder */}
                <div className="space-y-3">
                  {platform.fields.includes('access_token') && (
                    <div>
                      <label className="block text-xs font-bold text-gray-700 mb-1">
                        Access Token {channel?.access_token && <span className="font-normal text-gray-400">({channel.access_token})</span>}
                      </label>
                      <input
                        type="password"
                        value={getFormValue(platform.key, 'access_token')}
                        onChange={e => setFormValue(platform.key, 'access_token', e.target.value)}
                        className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
                        placeholder="Neuen Token einfügen..."
                      />
                    </div>
                  )}
                  {platform.fields.includes('page_id') && (
                    <div>
                      <label className="block text-xs font-bold text-gray-700 mb-1">
                        Page / Account ID {channel?.page_id && <span className="font-normal text-gray-400">({channel.page_id})</span>}
                      </label>
                      <input
                        type="text"
                        value={getFormValue(platform.key, 'page_id')}
                        onChange={e => setFormValue(platform.key, 'page_id', e.target.value)}
                        className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
                        placeholder="z.B. 123456789..."
                      />
                    </div>
                  )}
                </div>

                {/* Actions */}
                <div className="flex items-center gap-2 flex-wrap">
                  <button
                    onClick={() => handleSave(platform.key)}
                    disabled={saving === platform.key}
                    className="inline-flex items-center gap-1.5 px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-xl text-xs font-medium shadow-sm disabled:opacity-50 transition-colors"
                  >
                    {saving === platform.key ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Save className="w-3.5 h-3.5" />}
                    Speichern
                  </button>
                  {channel && (
                    <>
                      <button
                        onClick={() => handleVerify(platform.key)}
                        disabled={verifying === platform.key}
                        className="inline-flex items-center gap-1.5 px-4 py-2 bg-white border border-gray-200 hover:bg-gray-50 text-gray-700 rounded-xl text-xs font-medium disabled:opacity-50 transition-colors"
                      >
                        {verifying === platform.key ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <RefreshCw className="w-3.5 h-3.5" />}
                        Verbindung testen
                      </button>
                      <button
                        onClick={() => handleDelete(platform.key)}
                        className="inline-flex items-center gap-1.5 px-4 py-2 text-red-600 hover:bg-red-50 rounded-xl text-xs font-medium transition-colors"
                      >
                        <Trash2 className="w-3.5 h-3.5" /> Entfernen
                      </button>
                    </>
                  )}
                </div>
              </div>
            )}
          </div>
        )
      })}
    </div>
  )
}
