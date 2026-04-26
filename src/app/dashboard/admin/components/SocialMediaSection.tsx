'use client'

import { useCallback, useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  Loader2, CheckCircle2, XCircle, AlertTriangle, Save, Trash2, RefreshCw,
  ExternalLink, ChevronDown, ChevronUp, Sparkles, Send, Edit3, Eye,
  Settings, FileText,
} from 'lucide-react'
import toast from 'react-hot-toast'
import type { SocialMediaChannel, SocialMediaPost } from './AdminTypes'

async function authFetch(url: string, init?: RequestInit): Promise<Response> {
  const supabase = createClient()
  const { data: { session } } = await supabase.auth.getSession()
  const headers: Record<string, string> = {
    ...(init?.headers as Record<string, string> || {}),
  }
  if (session?.access_token) {
    headers['Authorization'] = `Bearer ${session.access_token}`
  }
  return fetch(url, { ...init, headers })
}

type SocialView = 'channels' | 'posts'

const PLATFORMS = [
  {
    key: 'facebook' as const,
    label: 'Facebook',
    color: 'bg-blue-50 text-blue-700 border-blue-100',
    icon: '📘',
    fields: ['access_token', 'page_id'] as const,
    helpUrl: 'https://developers.facebook.com/tools/explorer/',
    fieldLabels: { access_token: 'Page Access Token', page_id: 'Page ID (Seiten-ID)' },
    fieldHints: {
      access_token: 'Langer Token-String, beginnt meist mit "EAA..."',
      page_id: 'Nur Zahlen, z.B. 102345678901234',
    },
    helpSteps: [
      'Öffne developers.facebook.com und melde dich mit deinem Facebook-Konto an',
      'Klicke oben rechts auf "Meine Apps" → "App erstellen"',
      'Wähle den Typ "Business" und gib einen App-Namen ein (z.B. "Mensaena Social")',
      'Öffne den Graph API Explorer: developers.facebook.com/tools/explorer',
      'Wähle oben links deine neu erstellte App aus dem Dropdown',
      'Klicke auf "Generate Access Token" → es öffnet sich ein Popup',
      'Aktiviere die Berechtigungen: pages_manage_posts, pages_read_engagement',
      'Klicke auf "Generate Access Token" und bestätige mit "Weiter" / "OK"',
      'Gib oben im Feld "me/accounts" ein und klicke auf "Absenden"',
      'In der Antwort findest du deine Seite mit "id" (= Page ID) und "access_token" (= Page Access Token)',
      'Kopiere beide Werte und füge sie unten ein',
    ],
    helpNote: 'Der Token ist zunächst 1 Stunde gültig. Für einen langlebigen Token (60 Tage) gibt es einen Verlängerungs-Endpoint.',
  },
  {
    key: 'instagram' as const,
    label: 'Instagram',
    color: 'bg-pink-50 text-pink-700 border-pink-100',
    icon: '📷',
    fields: ['access_token', 'page_id'] as const,
    helpUrl: 'https://developers.facebook.com/docs/instagram-platform/instagram-api-with-instagram-login/get-started/',
    fieldLabels: { access_token: 'Page Access Token (von Facebook)', page_id: 'Instagram Business Account ID' },
    fieldHints: {
      access_token: 'Gleicher Token wie bei Facebook (wenn Seite verknüpft)',
      page_id: 'Die Instagram Business Account ID (Zahlen), NICHT dein Benutzername',
    },
    helpSteps: [
      'Stelle sicher, dass dein Instagram-Konto ein Business- oder Creator-Konto ist (Instagram App → Einstellungen → Konto → Zu professionellem Konto wechseln)',
      'Verknüpfe dein Instagram-Konto mit einer Facebook-Seite (Instagram App → Einstellungen → Konto → Verknüpfte Konten → Facebook)',
      'Erstelle eine Facebook-App wie bei Facebook beschrieben (falls noch nicht geschehen)',
      'Öffne den Graph API Explorer: developers.facebook.com/tools/explorer',
      'Generiere einen User Access Token mit den Berechtigungen: instagram_basic, instagram_content_publish, pages_manage_posts',
      'Gib im Feld ein: me/accounts und klicke "Absenden" → notiere die Page-ID deiner Facebook-Seite',
      'Gib im Feld ein: {deine-page-id}?fields=instagram_business_account und klicke "Absenden"',
      'Die Antwort enthält die "instagram_business_account.id" → das ist deine Instagram Business Account ID',
      'Kopiere den Access Token und die Instagram Business Account ID unten ein',
    ],
    helpNote: 'Instagram erfordert immer ein Bild für Posts. Reine Text-Posts sind nicht möglich.',
  },
  {
    key: 'x' as const,
    label: 'X / Twitter',
    color: 'bg-stone-100 text-ink-800 border-stone-200',
    icon: '𝕏',
    fields: ['access_token', 'api_key', 'api_secret'] as const,
    helpUrl: 'https://developer.x.com/en/docs/x-api/getting-started/getting-access-to-the-x-api',
    fieldLabels: { access_token: 'Access Token', api_key: 'API Key (Consumer Key)', api_secret: 'API Secret (Consumer Secret)' },
    fieldHints: {
      access_token: 'OAuth 1.0a Access Token aus dem Developer Portal',
      api_key: 'Auch "Consumer Key" oder "API Key" genannt',
      api_secret: 'Auch "Consumer Secret" oder "API Key Secret" genannt',
    },
    helpSteps: [
      'Öffne developer.x.com und melde dich mit deinem X-Konto an',
      'Klicke auf "Sign up for Free Account" (kostenlos: 1.500 Posts/Monat)',
      'Fülle das Formular aus: Beschreibe kurz, wofür du die API nutzt (z.B. "Automatisierte Posts für Community-Plattform")',
      'Nach der Freischaltung: Klicke auf "Projects & Apps" im Dashboard',
      'Erstelle ein neues Projekt (z.B. "Mensaena") und eine App darin',
      'Gehe zu deiner App → "Settings" → "User authentication settings" → "Set up"',
      'Wähle "Read and Write" bei App permissions (wichtig zum Posten!)',
      'Wähle "Web App, Automated App or Bot" als App-Typ',
      'Callback URL: https://www.mensaena.de (Pflichtfeld, wird nicht aktiv genutzt)',
      'Website URL: https://www.mensaena.de',
      'Speichere die Einstellungen',
      'Gehe zu "Keys and Tokens" → generiere "API Key and Secret" → kopiere beide',
      'Darunter: generiere "Access Token and Secret" → kopiere den Access Token',
      'Füge alle drei Werte unten ein',
    ],
    helpNote: 'Free Tier erlaubt 1.500 Posts/Monat. Tweets werden auf 280 Zeichen begrenzt.',
  },
  {
    key: 'linkedin' as const,
    label: 'LinkedIn',
    color: 'bg-sky-50 text-sky-700 border-sky-100',
    icon: '💼',
    fields: ['access_token', 'page_id'] as const,
    helpUrl: 'https://learn.microsoft.com/en-us/linkedin/marketing/quick-start',
    fieldLabels: { access_token: 'Access Token', page_id: 'Organization ID (Unternehmens-ID)' },
    fieldHints: {
      access_token: 'OAuth 2.0 Token aus dem LinkedIn Developer Portal',
      page_id: 'Nur Zahlen, findest du in der URL deiner Unternehmensseite',
    },
    helpSteps: [
      'Öffne linkedin.com/developers und melde dich an',
      'Klicke auf "Create App" (App erstellen)',
      'Fülle aus: App Name (z.B. "Mensaena"), LinkedIn Page (deine Unternehmensseite auswählen), Logo hochladen',
      'Nach dem Erstellen: Gehe zum Tab "Products"',
      'Klicke bei "Community Management API" auf "Request Access" → bestätige',
      'Gehe zum Tab "Auth" → dort siehst du Client ID und Client Secret',
      'Scrolle runter zu "OAuth 2.0 tools" → klicke auf "Generate token"',
      'Wähle die Scopes: w_member_social, w_organization_social',
      'Autorisiere und kopiere den generierten Access Token',
      'Für die Organization ID: Öffne deine LinkedIn-Unternehmensseite im Browser',
      'Die URL sieht so aus: linkedin.com/company/12345678 → die Zahl ist deine Organization ID',
      'Füge Token und Organization ID unten ein',
    ],
    helpNote: 'Der LinkedIn Access Token ist 60 Tage gültig und muss danach erneuert werden.',
  },
  {
    key: 'pinterest' as const,
    label: 'Pinterest',
    color: 'bg-red-50 text-red-700 border-red-100',
    icon: '📌',
    fields: ['access_token', 'page_id'] as const,
    helpUrl: 'https://developers.pinterest.com/docs/getting-started/set-up-app/',
    fieldLabels: { access_token: 'Access Token', page_id: 'Board ID' },
    fieldHints: {
      access_token: 'OAuth 2.0 Token aus dem Pinterest Developer Portal',
      page_id: 'ID des Boards auf das gepostet werden soll',
    },
    helpSteps: [
      'Öffne developers.pinterest.com und melde dich an',
      'Klicke auf "My Apps" → "Create App"',
      'App Name und Website (mensaena.de) eingeben',
      'Unter "Manage" → "Generate Token" klicken',
      'Scope "pins:read" und "pins:write" aktivieren',
      'Token kopieren und hier einfügen',
      'Board ID: Öffne dein Pinterest-Board → die ID steht in der URL',
    ],
    helpNote: 'Pinterest erfordert ein Bild für jeden Pin. Pins verlinken automatisch auf mensaena.de.',
  },
  {
    key: 'tiktok' as const,
    label: 'TikTok',
    color: 'bg-gray-900 text-white border-gray-700',
    icon: '🎵',
    fields: ['access_token'] as const,
    helpUrl: 'https://developers.tiktok.com/doc/content-posting-api-get-started/',
    fieldLabels: { access_token: 'Access Token' },
    fieldHints: { access_token: 'OAuth Token aus dem TikTok Developer Portal' },
    helpSteps: [
      'Öffne developers.tiktok.com und erstelle ein Developer-Konto',
      'Erstelle eine neue App unter "Manage Apps"',
      'Beantrage Zugriff auf die "Content Posting API"',
      'Nach Genehmigung: OAuth-Flow durchführen und Token generieren',
      'Token hier einfügen',
    ],
    helpNote: 'TikTok Content Posting API erfordert eine App-Überprüfung durch TikTok (kann einige Tage dauern).',
  },
  {
    key: 'threads' as const,
    label: 'Threads',
    color: 'bg-stone-100 text-ink-800 border-stone-200',
    icon: '🧵',
    fields: ['access_token', 'page_id'] as const,
    helpUrl: 'https://developers.facebook.com/docs/threads/',
    fieldLabels: { access_token: 'Access Token (Meta)', page_id: 'Threads User ID' },
    fieldHints: {
      access_token: 'Gleicher Meta/Facebook Token mit threads_* Berechtigungen',
      page_id: 'Deine Threads User ID (Zahlen)',
    },
    helpSteps: [
      'Threads nutzt die Meta/Facebook API — gleiche App wie bei Facebook/Instagram',
      'Öffne den Graph API Explorer auf developers.facebook.com',
      'Generiere einen Token mit den Berechtigungen: threads_basic, threads_content_publish',
      'Gib im Feld ein: me?fields=id und klicke "Absenden" → das ist deine Threads User ID',
      'Token und User ID hier einfügen',
    ],
    helpNote: 'Threads erlaubt nur Text-Posts (bis 500 Zeichen). Kein Bild-Upload über die API.',
  },
  {
    key: 'mastodon' as const,
    label: 'Mastodon',
    color: 'bg-purple-50 text-purple-700 border-purple-100',
    icon: '🐘',
    fields: ['access_token', 'page_id'] as const,
    helpUrl: 'https://docs.joinmastodon.org/client/token/',
    fieldLabels: { access_token: 'Access Token', page_id: 'Instanz-Domain (z.B. mastodon.social)' },
    fieldHints: {
      access_token: 'OAuth Token von deiner Mastodon-Instanz',
      page_id: 'z.B. mastodon.social, troet.cafe, chaos.social',
    },
    helpSteps: [
      'Öffne deine Mastodon-Instanz (z.B. mastodon.social)',
      'Gehe zu Einstellungen → Entwicklung → Neue Anwendung',
      'Name: "Mensaena" — Berechtigungen: "write:statuses" aktivieren',
      'Klicke "Absenden" → dann auf den App-Namen klicken',
      'Kopiere den "Zugriffstoken" und füge ihn hier ein',
      'Als Instanz-Domain deine Mastodon-Domain eingeben (z.B. mastodon.social)',
    ],
    helpNote: 'Mastodon ist kostenlos und dezentral. Kein API-Key von Drittanbietern nötig — alles direkt auf deiner Instanz.',
  },
  {
    key: 'telegram' as const,
    label: 'Telegram',
    color: 'bg-blue-50 text-blue-600 border-blue-100',
    icon: '✈️',
    fields: ['access_token', 'page_id'] as const,
    helpUrl: 'https://core.telegram.org/bots#how-do-i-create-a-bot',
    fieldLabels: { access_token: 'Bot Token', page_id: 'Channel ID (@name oder -100xxx)' },
    fieldHints: {
      access_token: 'Token vom BotFather (z.B. 123456:ABC-DEF...)',
      page_id: '@dein_channel_name oder numerische Channel-ID',
    },
    helpSteps: [
      'Öffne Telegram und suche nach @BotFather',
      'Sende /newbot und folge den Anweisungen (Name + Username wählen)',
      'BotFather gibt dir den Bot Token → kopiere ihn',
      'Erstelle einen Telegram-Channel (oder nutze einen bestehenden)',
      'Füge deinen Bot als Admin zum Channel hinzu',
      'Channel ID: Nutze @kanalname (z.B. @mensaena_news) oder leite eine Nachricht an @userinfobot weiter',
      'Bot Token und Channel ID hier einfügen',
    ],
    helpNote: 'Telegram ist komplett kostenlos, keine API-Limits. Der Bot muss Admin im Channel sein.',
  },
]

export default function SocialMediaSection() {
  const [view, setView] = useState<SocialView>('posts')

  return (
    <div className="space-y-4">
      {/* Sub-Tabs */}
      <div className="flex items-center gap-2 border-b border-stone-100 pb-3">
        <button
          onClick={() => setView('posts')}
          className={`flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-medium transition-all ${
            view === 'posts' ? 'bg-primary-100 text-primary-700' : 'text-ink-500 hover:bg-stone-100'
          }`}
        >
          <FileText className="w-3.5 h-3.5" /> Beiträge
        </button>
        <button
          onClick={() => setView('channels')}
          className={`flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-medium transition-all ${
            view === 'channels' ? 'bg-primary-100 text-primary-700' : 'text-ink-500 hover:bg-stone-100'
          }`}
        >
          <Settings className="w-3.5 h-3.5" /> Kanäle verbinden
        </button>
      </div>

      {view === 'channels' && <ChannelsView />}
      {view === 'posts' && <PostsView />}
    </div>
  )
}

// ============================================================
// Posts View – KI-Generierung + Entwürfe + Veröffentlichen
// ============================================================
function PostsView() {
  const [posts, setPosts] = useState<SocialMediaPost[]>([])
  const [loading, setLoading] = useState(true)
  const [generating, setGenerating] = useState(false)
  const [topic, setTopic] = useState('')
  const [selectedPlatforms, setSelectedPlatforms] = useState<string[]>(['facebook', 'instagram', 'x', 'linkedin'])
  const [editPost, setEditPost] = useState<SocialMediaPost | null>(null)
  const [editContent, setEditContent] = useState('')
  const [editScheduledAt, setEditScheduledAt] = useState('')
  const [editHashtags, setEditHashtags] = useState('')
  const [suggestingHashtags, setSuggestingHashtags] = useState(false)
  // Bild-Picker State
  const [imageMode, setImageMode] = useState<'none' | 'ai' | 'unsplash' | 'upload'>('none')
  const [imagePrompt, setImagePrompt] = useState('')
  const [unsplashQuery, setUnsplashQuery] = useState('')
  const [generatingImage, setGeneratingImage] = useState(false)
  const [searchingPhotos, setSearchingPhotos] = useState(false)
  const [unsplashPhotos, setUnsplashPhotos] = useState<Array<{ id: string; url: string; thumb: string; author: string }>>([])
  const [selectedImageUrl, setSelectedImageUrl] = useState('')
  const [aiImageUrl, setAiImageUrl] = useState('')
  const [publishing, setPublishing] = useState<string | null>(null)

  const loadPosts = useCallback(async () => {
    setLoading(true)
    try {
      const res = await authFetch('/api/social-media/posts')
      if (!res.ok) throw new Error()
      setPosts(await res.json() as SocialMediaPost[])
    } catch {
      toast.error('Posts laden fehlgeschlagen')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { loadPosts() }, [loadPosts])

  const togglePlatform = (p: string) => {
    setSelectedPlatforms(prev =>
      prev.includes(p) ? prev.filter(x => x !== p) : [...prev, p]
    )
  }

  const handleGenerate = async () => {
    if (!selectedPlatforms.length) {
      toast.error('Wähle mindestens eine Plattform')
      return
    }
    setGenerating(true)
    try {
      const res = await authFetch('/api/social-media/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ platforms: selectedPlatforms, topic: topic || undefined }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Generierung fehlgeschlagen')

      // Jeden generierten Post als Entwurf speichern
      let saved = 0
      for (const post of (data.posts || [])) {
        const saveRes = await authFetch('/api/social-media/posts', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            content: post.content,
            platforms: [post.platform],
            hashtags: post.hashtags || [],
            media_urls: selectedImageUrl ? [selectedImageUrl] : [],
            auto_generated: true,
            ai_prompt: topic || 'auto',
          }),
        })
        if (saveRes.ok) saved++
      }
      toast.success(`${saved} Entwürfe generiert`)
      setTopic('')
      await loadPosts()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Fehler')
    } finally {
      setGenerating(false)
    }
  }

  const handlePublish = async (postId: string) => {
    if (!confirm('Post jetzt an alle ausgewählten Plattformen senden?')) return
    setPublishing(postId)
    try {
      const res = await authFetch(`/api/social-media/posts/${postId}/publish`, { method: 'POST' })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Veröffentlichung fehlgeschlagen')
      toast.success(`Veröffentlicht: ${data.published}/${data.total} erfolgreich`)
      await loadPosts()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Fehler')
    } finally {
      setPublishing(null)
    }
  }

  const handleSaveEdit = async () => {
    if (!editPost) return
    try {
      const res = await authFetch(`/api/social-media/posts/${editPost.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          content: editContent,
          hashtags: editHashtags ? editHashtags.split(/[,;]+/).map(h => h.trim().replace(/^#/, '')).filter(Boolean) : [],
          scheduled_at: editScheduledAt ? new Date(editScheduledAt).toISOString() : null,
        }),
      })
      if (!res.ok) throw new Error()
      toast.success(editScheduledAt ? 'Veröffentlichung geplant' : 'Gespeichert')
      setEditPost(null)
      await loadPosts()
    } catch {
      toast.error('Speichern fehlgeschlagen')
    }
  }

  const handleDelete = async (postId: string) => {
    if (!confirm('Entwurf löschen?')) return
    try {
      await authFetch(`/api/social-media/posts/${postId}`, { method: 'DELETE' })
      toast.success('Gelöscht')
      await loadPosts()
    } catch {
      toast.error('Löschen fehlgeschlagen')
    }
  }

  const platformLabel: Record<string, string> = {
    facebook: '📘 Facebook', instagram: '📷 Instagram',
    x: '𝕏 X', linkedin: '💼 LinkedIn',
    pinterest: '📌 Pinterest', tiktok: '🎵 TikTok',
    threads: '🧵 Threads', mastodon: '🐘 Mastodon',
    telegram: '✈️ Telegram',
  }

  const statusBadge = (status: string) => {
    const map: Record<string, string> = {
      draft: 'bg-stone-100 text-ink-600',
      scheduled: 'bg-blue-50 text-blue-600',
      publishing: 'bg-amber-50 text-amber-600',
      published: 'bg-green-50 text-green-600',
      failed: 'bg-red-50 text-red-600',
    }
    const labels: Record<string, string> = {
      draft: 'Entwurf', scheduled: 'Geplant', publishing: 'Wird gesendet',
      published: 'Veröffentlicht', failed: 'Fehlgeschlagen',
    }
    return (
      <span className={`px-2 py-0.5 rounded-lg text-xs font-medium ${map[status] || 'bg-stone-100'}`}>
        {labels[status] || status}
      </span>
    )
  }

  const drafts = posts.filter(p => p.status === 'draft' || p.status === 'scheduled')
  const published = posts.filter(p => p.status === 'published' || p.status === 'failed')

  return (
    <div className="space-y-5">
      {/* KI-Generator */}
      <div className="bg-gradient-to-br from-primary-50 to-white border border-primary-100 rounded-2xl p-5">
        <div className="flex items-center gap-2 mb-3">
          <Sparkles className="w-4 h-4 text-primary-600" />
          <h3 className="text-sm font-bold text-ink-900">KI-Content-Generator</h3>
        </div>
        <p className="text-xs text-ink-600 mb-4">
          Generiert professionelle Social-Media-Beiträge basierend auf der Plattform-Aktivität der letzten 7 Tage.
        </p>

        {/* Plattform-Auswahl */}
        <div className="flex flex-wrap gap-2 mb-3">
          {Object.entries(platformLabel).map(([key, label]) => (
            <button
              key={key}
              onClick={() => togglePlatform(key)}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium border transition-all ${
                selectedPlatforms.includes(key)
                  ? 'bg-primary-500 text-white border-primary-500'
                  : 'bg-white text-ink-600 border-stone-200 hover:border-primary-300'
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        {/* Optionales Thema */}
        <div className="flex gap-2">
          <input
            type="text"
            value={topic}
            onChange={e => setTopic(e.target.value)}
            placeholder="Optionales Thema (z.B. 'Sommeraktion', 'Neue Features')"
            className="flex-1 px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
          />
          <button
            onClick={handleGenerate}
            disabled={generating}
            className="inline-flex items-center gap-2 px-5 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-xl text-sm font-medium shadow-sm disabled:opacity-50 transition-colors whitespace-nowrap"
          >
            {generating ? <Loader2 className="w-4 h-4 animate-spin" /> : <Sparkles className="w-4 h-4" />}
            Generieren
          </button>
        </div>
      </div>

      {/* Bild-Picker */}
      <div className="bg-white border border-stone-100 rounded-2xl p-5 shadow-sm">
        <h3 className="text-sm font-bold text-ink-900 mb-3 flex items-center gap-2">
          <Eye className="w-4 h-4 text-ink-400" /> Bild für Posts
        </h3>

        {/* Modus-Auswahl */}
        <div className="flex flex-wrap gap-2 mb-4">
          {([
            { key: 'ai' as const, label: 'KI-Bild generieren', icon: '🤖' },
            { key: 'unsplash' as const, label: 'Stock-Foto suchen', icon: '📸' },
            { key: 'upload' as const, label: 'Eigenes Bild', icon: '📁' },
          ]).map(m => (
            <button
              key={m.key}
              onClick={() => setImageMode(imageMode === m.key ? 'none' : m.key)}
              className={`px-3 py-2 rounded-xl text-xs font-medium border transition-all ${
                imageMode === m.key
                  ? 'bg-primary-500 text-white border-primary-500'
                  : 'bg-white text-ink-600 border-stone-200 hover:border-primary-300'
              }`}
            >
              {m.icon} {m.label}
            </button>
          ))}
        </div>

        {/* KI-Bild */}
        {imageMode === 'ai' && (
          <div className="space-y-3">
            <div className="flex gap-2">
              <input
                type="text"
                value={imagePrompt}
                onChange={e => setImagePrompt(e.target.value)}
                placeholder="Bildbeschreibung (z.B. 'Nachbarn helfen sich gegenseitig im Garten')"
                className="flex-1 px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
              />
              <button
                onClick={async () => {
                  setGeneratingImage(true)
                  try {
                    const res = await authFetch('/api/social-media/images', {
                      method: 'POST',
                      headers: { 'Content-Type': 'application/json' },
                      body: JSON.stringify({ mode: 'ai', prompt: imagePrompt || topic || 'community neighborhood help' }),
                    })
                    const data = await res.json()
                    if (!res.ok) throw new Error(data.error)
                    setAiImageUrl(data.url)
                    setSelectedImageUrl(data.url)
                    toast.success('Bild generiert!')
                  } catch (e) {
                    toast.error(e instanceof Error ? e.message : 'Bildgenerierung fehlgeschlagen')
                  } finally {
                    setGeneratingImage(false)
                  }
                }}
                disabled={generatingImage}
                className="px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-xl text-xs font-medium disabled:opacity-50 whitespace-nowrap"
              >
                {generatingImage ? <Loader2 className="w-4 h-4 animate-spin" /> : '🎨 Generieren'}
              </button>
            </div>
            {aiImageUrl && (
              <div className="relative">
                <img src={aiImageUrl} alt="KI-generiert" className="w-full max-w-xs rounded-xl border border-stone-200" />
                <span className="absolute top-2 left-2 bg-black/50 text-white text-xs px-2 py-0.5 rounded-lg">KI-generiert</span>
              </div>
            )}
          </div>
        )}

        {/* Unsplash */}
        {imageMode === 'unsplash' && (
          <div className="space-y-3">
            <div className="flex gap-2">
              <input
                type="text"
                value={unsplashQuery}
                onChange={e => setUnsplashQuery(e.target.value)}
                placeholder="Suchbegriff (z.B. 'community', 'neighborhood', 'helping')"
                className="flex-1 px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
              />
              <button
                onClick={async () => {
                  setSearchingPhotos(true)
                  try {
                    const res = await authFetch('/api/social-media/images', {
                      method: 'POST',
                      headers: { 'Content-Type': 'application/json' },
                      body: JSON.stringify({ mode: 'unsplash', query: unsplashQuery || 'community neighborhood' }),
                    })
                    const data = await res.json()
                    if (!res.ok) throw new Error(data.error)
                    setUnsplashPhotos(data.photos || [])
                  } catch (e) {
                    toast.error(e instanceof Error ? e.message : 'Suche fehlgeschlagen')
                  } finally {
                    setSearchingPhotos(false)
                  }
                }}
                disabled={searchingPhotos}
                className="px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-xl text-xs font-medium disabled:opacity-50 whitespace-nowrap"
              >
                {searchingPhotos ? <Loader2 className="w-4 h-4 animate-spin" /> : '🔍 Suchen'}
              </button>
            </div>
            {unsplashPhotos.length > 0 && (
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {unsplashPhotos.map(photo => (
                  <button
                    key={photo.id}
                    onClick={() => setSelectedImageUrl(photo.url)}
                    className={`relative rounded-xl overflow-hidden border-2 transition-all ${
                      selectedImageUrl === photo.url ? 'border-primary-500 ring-2 ring-primary-200' : 'border-transparent hover:border-stone-300'
                    }`}
                  >
                    <img src={photo.thumb} alt={`Stock-Foto von ${photo.author}`} className="w-full aspect-square object-cover" />
                    {selectedImageUrl === photo.url && (
                      <div className="absolute inset-0 bg-primary-500/20 flex items-center justify-center">
                        <CheckCircle2 className="w-6 h-6 text-white drop-shadow-lg" />
                      </div>
                    )}
                  </button>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Upload */}
        {imageMode === 'upload' && (
          <div className="space-y-3">
            <label className="flex flex-col items-center justify-center w-full h-32 border-2 border-dashed border-stone-300 rounded-xl cursor-pointer hover:border-primary-400 hover:bg-primary-50/30 transition-all">
              <div className="flex flex-col items-center">
                <span className="text-2xl mb-1">📁</span>
                <span className="text-xs text-ink-500 font-medium">Klicke zum Hochladen</span>
                <span className="text-xs text-ink-400">JPG, PNG, WebP · max. 10 MB</span>
              </div>
              <input
                type="file"
                accept="image/*"
                className="hidden"
                onChange={async (e) => {
                  const file = e.target.files?.[0]
                  if (!file) return
                  setGeneratingImage(true)
                  try {
                    const form = new FormData()
                    form.append('file', file)
                    const res = await authFetch('/api/social-media/upload', {
                      method: 'POST',
                      body: form,
                    })
                    const data = await res.json()
                    if (!res.ok) throw new Error(data.error)
                    setSelectedImageUrl(data.url)
                    toast.success('Bild hochgeladen!')
                  } catch (err) {
                    toast.error(err instanceof Error ? err.message : 'Upload fehlgeschlagen')
                  } finally {
                    setGeneratingImage(false)
                  }
                }}
              />
            </label>
            {generatingImage && (
              <div className="flex items-center gap-2 text-xs text-ink-500">
                <Loader2 className="w-4 h-4 animate-spin" /> Wird hochgeladen...
              </div>
            )}
            {selectedImageUrl && selectedImageUrl.startsWith('http') && (
              <img src={selectedImageUrl} alt="Upload" className="w-full max-w-xs rounded-xl border border-stone-200" />
            )}
          </div>
        )}

        {/* Ausgewähltes Bild anzeigen */}
        {selectedImageUrl && imageMode !== 'none' && (
          <div className="mt-3 flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 text-green-500" />
            <span className="text-xs text-green-700">Bild ausgewählt — wird beim nächsten Generieren an die Posts angehängt</span>
            <button onClick={() => { setSelectedImageUrl(''); setAiImageUrl('') }} className="text-xs text-ink-400 hover:text-red-500 ml-auto">✕ Entfernen</button>
          </div>
        )}
      </div>

      {/* Entwürfe */}
      <div>
        <h3 className="text-sm font-bold text-ink-900 mb-3 flex items-center gap-2">
          <Edit3 className="w-4 h-4 text-ink-400" /> Entwürfe ({drafts.length})
        </h3>
        {loading ? (
          <div className="flex justify-center py-8"><Loader2 className="w-5 h-5 text-gray-300 animate-spin" /></div>
        ) : drafts.length === 0 ? (
          <p className="text-xs text-ink-400 italic bg-stone-50 rounded-xl p-4 text-center">
            Keine Entwürfe. Klicke oben auf &quot;Generieren&quot;.
          </p>
        ) : (
          <div className="space-y-3">
            {drafts.map(post => (
              <div key={post.id} className="bg-white border border-stone-100 rounded-xl p-4 shadow-sm">
                <div className="flex items-start justify-between gap-3">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-2 flex-wrap">
                      {statusBadge(post.status)}
                      {post.platforms.map(p => (
                        <span key={p} className="text-xs text-ink-500">{platformLabel[p] || p}</span>
                      ))}
                      {post.auto_generated && (
                        <span className="text-xs text-primary-500 flex items-center gap-0.5">
                          <Sparkles className="w-3 h-3" /> KI
                        </span>
                      )}
                    </div>
                    <p className="text-sm text-ink-800 whitespace-pre-wrap line-clamp-4">{post.content}</p>
                    {post.media_urls?.length > 0 && (
                      <div className="mt-2 flex gap-2">
                        {post.media_urls.map((url, i) => (
                          <img key={i} src={url} alt="" className="w-16 h-16 rounded-lg object-cover border border-stone-200" />
                        ))}
                      </div>
                    )}
                    {post.hashtags?.length > 0 && (
                      <p className="text-xs text-primary-600 mt-2">
                        {post.hashtags.map(h => `#${h.replace(/^#/, '')}`).join(' ')}
                      </p>
                    )}
                  </div>
                  <div className="flex flex-col gap-1.5 flex-shrink-0">
                    <button
                      onClick={() => { setEditPost(post); setEditContent(post.content); setEditScheduledAt(post.scheduled_at ? post.scheduled_at.slice(0, 16) : ''); setEditHashtags((post.hashtags || []).join(', ')) }}
                      className="p-2 text-ink-400 hover:text-ink-700 hover:bg-stone-100 rounded-lg transition-colors"
                      title="Bearbeiten"
                    >
                      <Edit3 className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => handlePublish(post.id)}
                      disabled={publishing === post.id}
                      className="p-2 text-primary-500 hover:text-primary-700 hover:bg-primary-50 rounded-lg transition-colors disabled:opacity-50"
                      title="Jetzt posten"
                    >
                      {publishing === post.id ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
                    </button>
                    <button
                      onClick={() => handleDelete(post.id)}
                      className="p-2 text-ink-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                      title="Löschen"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
                <p className="text-xs text-ink-400 mt-2">
                  {new Date(post.created_at).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
                </p>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Veröffentlichte */}
      {published.length > 0 && (
        <div>
          <h3 className="text-sm font-bold text-ink-900 mb-3 flex items-center gap-2">
            <Send className="w-4 h-4 text-ink-400" /> Veröffentlicht ({published.length})
          </h3>
          <div className="space-y-2">
            {published.map(post => (
              <div key={post.id} className="bg-stone-50 border border-stone-100 rounded-xl p-3">
                <div className="flex items-center gap-2 mb-1.5 flex-wrap">
                  {statusBadge(post.status)}
                  {post.platforms.map(p => (
                    <span key={p} className="text-xs text-ink-500">{platformLabel[p] || p}</span>
                  ))}
                </div>
                <p className="text-xs text-ink-600 line-clamp-2">{post.content}</p>
                {post.social_media_post_logs && post.social_media_post_logs.length > 0 && (
                  <div className="mt-2 flex flex-wrap gap-1">
                    {post.social_media_post_logs.map(log => (
                      <span key={log.id} className={`text-xs px-1.5 py-0.5 rounded ${
                        log.status === 'sent' ? 'bg-green-50 text-green-600' : 'bg-red-50 text-red-600'
                      }`}>
                        {platformLabel[log.platform] || log.platform}: {log.status === 'sent' ? 'OK' : log.error_msg?.slice(0, 30) || 'Fehler'}
                      </span>
                    ))}
                  </div>
                )}
                <p className="text-xs text-ink-400 mt-1.5">
                  {post.published_at
                    ? new Date(post.published_at).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })
                    : new Date(post.created_at).toLocaleDateString('de-DE')
                  }
                </p>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Edit Modal */}
      {editPost && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-xl">
            <div className="flex items-center justify-between p-5 border-b border-stone-100">
              <h3 className="text-sm font-bold text-ink-900">Beitrag bearbeiten</h3>
              <button onClick={() => setEditPost(null)} className="text-ink-400 hover:text-ink-900 text-xl">×</button>
            </div>
            <div className="p-5">
              <div className="flex flex-wrap gap-1.5 mb-3">
                {editPost.platforms.map(p => (
                  <span key={p} className="text-xs bg-stone-100 text-ink-600 px-2 py-1 rounded-lg">{platformLabel[p] || p}</span>
                ))}
              </div>
              <textarea
                value={editContent}
                onChange={e => setEditContent(e.target.value)}
                className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
                rows={8}
              />
              <p className="text-xs text-ink-400 mt-1 text-right">{editContent.length} Zeichen</p>
              {/* Hashtags */}
              <div className="mt-3">
                <div className="flex items-center justify-between mb-1">
                  <label className="text-xs font-bold text-ink-700">Hashtags</label>
                  <button
                    onClick={async () => {
                      setSuggestingHashtags(true)
                      try {
                        const res = await authFetch('/api/social-media/generate', {
                          method: 'POST',
                          headers: { 'Content-Type': 'application/json' },
                          body: JSON.stringify({ platforms: editPost?.platforms || ['instagram'], topic: `Hashtag-Vorschläge für: ${editContent.slice(0, 200)}` }),
                        })
                        const data = await res.json()
                        if (data.posts?.[0]?.hashtags) {
                          setEditHashtags(data.posts[0].hashtags.join(', '))
                          toast.success('Hashtags vorgeschlagen!')
                        }
                      } catch { toast.error('Hashtag-Vorschläge fehlgeschlagen') }
                      finally { setSuggestingHashtags(false) }
                    }}
                    disabled={suggestingHashtags}
                    className="text-xs text-primary-600 hover:underline flex items-center gap-1"
                  >
                    {suggestingHashtags ? <Loader2 className="w-3 h-3 animate-spin" /> : <Sparkles className="w-3 h-3" />}
                    KI-Vorschlag
                  </button>
                </div>
                <input
                  type="text"
                  value={editHashtags}
                  onChange={e => setEditHashtags(e.target.value)}
                  placeholder="nachbarschaftshilfe, mensaena, community"
                  className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
                />
              </div>
              {/* Geplante Veröffentlichung */}
              <div className="mt-3 border-t border-stone-100 pt-3">
                <label className="flex items-center gap-2 text-xs text-ink-700">
                  <input
                    type="checkbox"
                    checked={!!editScheduledAt}
                    onChange={e => setEditScheduledAt(e.target.checked ? new Date(Date.now() + 3600000).toISOString().slice(0, 16) : '')}
                    className="accent-primary-500"
                  />
                  <span className="font-medium">Veröffentlichung planen</span>
                </label>
                {editScheduledAt && (
                  <input
                    type="datetime-local"
                    value={editScheduledAt}
                    onChange={e => setEditScheduledAt(e.target.value)}
                    min={new Date().toISOString().slice(0, 16)}
                    className="mt-2 w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
                  />
                )}
              </div>
            </div>
            <div className="p-5 border-t border-stone-100 flex justify-end gap-2">
              <button onClick={() => setEditPost(null)} className="px-4 py-2 text-ink-600 hover:bg-stone-100 rounded-xl text-sm">Abbrechen</button>
              <button onClick={handleSaveEdit} className="px-5 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-xl text-sm font-medium shadow-sm">
                {editScheduledAt ? 'Planen' : 'Speichern'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

// ============================================================
// Channels View – Token-Verwaltung
// ============================================================
function ChannelsView() {
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
      const res = await authFetch('/api/social-media/channels')
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
      const res = await authFetch('/api/social-media/channels', {
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
      const res = await authFetch('/api/social-media/channels/verify', {
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
      const res = await authFetch(`/api/social-media/channels?platform=${platform}`, { method: 'DELETE' })
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
          <div key={platform.key} className="bg-white border border-stone-100 rounded-2xl overflow-hidden shadow-sm">
            {/* Header */}
            <button
              onClick={() => setExpandedPlatform(isExpanded ? null : platform.key)}
              className="w-full flex items-center justify-between p-4 hover:bg-stone-50 transition-colors"
            >
              <div className="flex items-center gap-3">
                <div className={`w-10 h-10 rounded-xl border flex items-center justify-center text-lg ${platform.color}`}>
                  {platform.icon}
                </div>
                <div className="text-left">
                  <p className="text-sm font-bold text-ink-900">{platform.label}</p>
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
                      <span className="flex items-center gap-1 text-xs text-ink-400">
                        <XCircle className="w-3 h-3" /> Nicht konfiguriert
                      </span>
                    )}
                    {channel?.last_verified && (
                      <span className="text-xs text-ink-400">
                        · Geprüft: {new Date(channel.last_verified).toLocaleDateString('de-DE')}
                      </span>
                    )}
                  </div>
                </div>
              </div>
              {isExpanded ? <ChevronUp className="w-4 h-4 text-ink-400" /> : <ChevronDown className="w-4 h-4 text-ink-400" />}
            </button>

            {/* Expanded: Anleitung + Token-Eingabe */}
            {isExpanded && (
              <div className="border-t border-stone-100 p-4 space-y-4">
                {/* Anleitung */}
                <div className="bg-stone-50 rounded-xl p-4">
                  <p className="text-xs font-bold text-ink-700 mb-2">Schritt-für-Schritt Anleitung:</p>
                  <ol className="space-y-2">
                    {platform.helpSteps.map((step, i) => (
                      <li key={i} className="text-xs text-ink-600 flex gap-2.5 leading-relaxed">
                        <span className="w-5 h-5 rounded-full bg-primary-100 text-primary-700 font-bold flex items-center justify-center flex-shrink-0 text-[10px]">{i + 1}</span>
                        <span>{step}</span>
                      </li>
                    ))}
                  </ol>
                  {platform.helpNote && (
                    <div className="mt-3 bg-amber-50 border border-amber-100 rounded-lg p-2.5">
                      <p className="text-xs text-amber-800 leading-relaxed">
                        <span className="font-bold">Hinweis:</span> {platform.helpNote}
                      </p>
                    </div>
                  )}
                  <a
                    href={platform.helpUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1 text-xs text-primary-600 hover:underline mt-3 font-medium"
                  >
                    <ExternalLink className="w-3 h-3" /> Offizielle Dokumentation
                  </a>
                </div>

                {/* Token-Felder */}
                <div className="space-y-3">
                  {platform.fields.map(field => (
                    <div key={field}>
                      <label className="block text-xs font-bold text-ink-700 mb-1">
                        {platform.fieldLabels?.[field] || field}
                        {channel?.[field as keyof SocialMediaChannel] && (
                          <span className="font-normal text-ink-400 ml-1">
                            (gespeichert: {String(channel[field as keyof SocialMediaChannel]).slice(0, 8)}...)
                          </span>
                        )}
                      </label>
                      <input
                        type={field.includes('token') || field.includes('secret') ? 'password' : 'text'}
                        value={getFormValue(platform.key, field)}
                        onChange={e => setFormValue(platform.key, field, e.target.value)}
                        className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
                        placeholder={platform.fieldHints?.[field] || `${platform.fieldLabels?.[field] || field} einfügen...`}
                      />
                    </div>
                  ))}
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
                        className="inline-flex items-center gap-1.5 px-4 py-2 bg-white border border-stone-200 hover:bg-stone-50 text-ink-700 rounded-xl text-xs font-medium disabled:opacity-50 transition-colors"
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
