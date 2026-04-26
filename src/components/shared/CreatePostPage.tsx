'use client'

import { useEffect, useRef, useState } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import Link from 'next/link'
import {
  ArrowLeft, CheckCircle2, Plus, MapPin, Locate, ImagePlus, LoaderCircle,
  Tag, Sparkles, X, Eye, EyeOff, AlertTriangle,
} from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import { checkRateLimit } from '@/lib/rate-limit'
import VoiceInputButton from '@/components/shared/VoiceInputButton'
import IntentSuggestionBanner from '@/components/shared/IntentSuggestionBanner'
import type { IntentType } from '@/lib/intent-classifier'

/** Type-Option für die Auswahl-Buttons im Create-Form */
export interface CreateTypeOption {
  value: string
  label: string
  /** Optional: vorgegebene Kategorie, wenn dieser Typ ausgewählt wird */
  cat?: string
  /** Optional: Beschreibung für den Button */
  desc?: string
}

/** Kategorie-Option für das Select */
export interface CreateCategoryOption {
  value: string
  label: string
}

/** Props der wiederverwendbaren Full-Page Create-Komponente */
export interface CreatePostPageProps {
  /** Modul-Schlüssel (z.B. 'animals'), wird mit gespeichert */
  moduleKey: string
  /** Header-Titel der Seite */
  moduleTitle: string
  /** Header-Beschreibung */
  moduleDescription: string
  /** Tailwind from-* Klasse für Gradient-Header */
  gradientFrom: string
  /** Tailwind to-* Klasse für Gradient-Header */
  gradientTo: string
  /** Tailwind ring-* Klasse für Active-Buttons */
  ringColor: string
  /** Header-Icon (Lucide React-Element) */
  iconComponent: React.ReactNode
  /** Auswahl der Beitrags-Typen */
  createTypes: CreateTypeOption[]
  /** Auswahl der Kategorien */
  categories: CreateCategoryOption[]
  /** Pfad zum Modul, wohin nach Erfolg/Abbruch zurückgekehrt wird */
  returnRoute: string
  /** Anonyme Beiträge erlauben (Toggle anzeigen) */
  showAnonymous?: boolean
  /** Hinweis-Banner oben (z.B. für mental-support) */
  topBanner?: React.ReactNode
  /** Modulspezifische Zusatzfelder (z.B. Datum/Zeit für mobility) */
  extraFields?: React.ReactNode
}

const TITLE_SUGGESTIONS: Record<string, string[]> = {
  help_request: ['Brauche Hilfe beim Einkaufen', 'Suche Unterstützung bei …', 'Benötige dringend Hilfe mit …'],
  help_offered: ['Biete Hilfe beim Einkaufen an', 'Kann beim Umzug helfen', 'Bin verfügbar für …'],
  rescue:       ['Rette Lebensmittel – bitte abholen', 'Überschuss kostenlos', 'Reste zu vergeben'],
  animal:       ['Katze entlaufen', 'Biete Tierbetreuung an', 'Suche Pflegestelle'],
  housing:      ['Biete Zimmer an', 'Suche Unterkunft', 'Notunterkunft verfügbar'],
  supply:       ['Gemüse vom Garten', 'Suche regionale Produkte', 'Biete Selbstgeerntetes an'],
  skill:        ['Gebe Unterricht in …', 'Helfe bei Computerproblemen', 'Biete Handwerker-Hilfe an'],
  mobility:     ['Fahre nach … – Mitfahrer willkommen', 'Suche Mitfahrt nach …', 'Biete Fahrten an'],
  sharing:      ['Verleihe Werkzeug', 'Tausche Bücher', 'Gebe Kindersachen weiter'],
  community:    ['Idee für Gemeinschaftsprojekt', 'Abstimmung: …', 'Einladung zum Treffen'],
  crisis:       ['DRINGEND: Sofortige Hilfe gesucht', 'Notfall – bitte melden', 'Medizinische Hilfe benötigt'],
  knowledge:    ['Anleitung: …', 'Tipps für …', 'Guide: …'],
  mental:       ['Suche jemanden zum Reden', 'Biete Begleitung an', 'Möchte Erfahrungen teilen'],
}

/**
 * Wiederverwendbare Full-Page Create-Komponente für alle Module.
 * Visuell orientiert an /dashboard/supply/farm/add (Gradient-Header, weiße Card-Sektionen).
 * Übernimmt die komplette Funktionalität des alten CreatePostModal aus ModulePage.
 */
export default function CreatePostPage({
  moduleKey,
  moduleTitle,
  moduleDescription,
  gradientFrom,
  gradientTo,
  ringColor,
  iconComponent,
  createTypes,
  categories,
  returnRoute,
  showAnonymous = false,
  topBanner,
  extraFields,
}: CreatePostPageProps) {
  const router = useRouter()
  const searchParams = useSearchParams()

  const urlType        = searchParams.get('type')
  const urlCategory    = searchParams.get('category')
  const urlTitle       = searchParams.get('title') ?? ''
  const urlDescription = searchParams.get('description') ?? ''

  const initialType     = urlType && createTypes.some(t => t.value === urlType) ? urlType : (createTypes[0]?.value ?? 'rescue')
  const initialCategory = urlCategory && categories.some(c => c.value === urlCategory)
    ? urlCategory
    : (createTypes.find(t => t.value === initialType)?.cat ?? categories[0]?.value ?? 'general')

  const [currentUserId, setCurrentUserId] = useState<string>()
  const [authChecked, setAuthChecked] = useState(false)

  const [form, setForm] = useState({
    type: initialType,
    category: initialCategory,
    title: urlTitle,
    description: urlDescription,
    location: '',
    contact_phone: '',
    contact_whatsapp: '',
    urgency: 'low',
    is_anonymous: false,
  })

  const [tags, setTags] = useState<string[]>([])
  const [tagInput, setTagInput] = useState('')
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [showSuggestions, setShowSuggestions] = useState(false)
  const [acceptedNoTrade, setAcceptedNoTrade] = useState(false)

  const [userLat, setUserLat] = useState<number | null>(null)
  const [userLng, setUserLng] = useState<number | null>(null)
  const [gettingLocation, setGettingLocation] = useState(false)

  const [imageUrl, setImageUrl] = useState<string | null>(null)
  const [imagePreview, setImagePreview] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)

  const [submitting, setSubmitting] = useState(false)
  const [success, setSuccess] = useState(false)

  // Auth-Check + Profil-Koordinaten als Fallback
  useEffect(() => {
    const supabase = createClient()
    let cancelled = false
    async function init() {
      const { data: { user } } = await supabase.auth.getUser()
      if (cancelled) return
      if (!user) {
        router.push('/auth')
        return
      }
      setCurrentUserId(user.id)
      setAuthChecked(true)
      const { data } = await supabase.from('profiles').select('latitude, longitude').eq('id', user.id).maybeSingle()
      if (cancelled) return
      if (data?.latitude && data?.longitude) {
        setUserLat(data.latitude as number)
        setUserLng(data.longitude as number)
      }
    }
    init()
    return () => { cancelled = true }
  }, [router])

  const set = (k: string, v: string | boolean) => setForm(f => ({ ...f, [k]: v }))

  // Wenn Type wechselt und der Type eine cat hat, Kategorie automatisch setzen
  const handleTypeChange = (newType: string) => {
    const opt = createTypes.find(t => t.value === newType)
    setForm(f => ({
      ...f,
      type: newType,
      category: opt?.cat ?? f.category,
    }))
  }

  const addTag = () => {
    const t = tagInput.trim().toLowerCase()
    if (t && !tags.includes(t) && tags.length < 5) {
      setTags(prev => [...prev, t])
      setTagInput('')
    }
  }

  const handleGetLocation = () => {
    if (!navigator.geolocation) return
    setGettingLocation(true)
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        setUserLat(pos.coords.latitude)
        setUserLng(pos.coords.longitude)
        try {
          const res = await fetch(`https://nominatim.openstreetmap.org/reverse?lat=${pos.coords.latitude}&lon=${pos.coords.longitude}&format=json`)
          const data = await res.json()
          if (data.display_name && !form.location) {
            const parts = (data.display_name as string).split(',')
            set('location', parts.slice(0, 3).join(',').trim())
          }
        } catch { /* Geocoding-Fehler ignorieren */ }
        setGettingLocation(false)
      },
      () => { setGettingLocation(false) },
      { timeout: 10000 },
    )
  }

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file || !currentUserId) return
    if (file.size > 10 * 1024 * 1024) { toast.error('Bild zu groß (max. 10 MB)'); return }
    if (!['image/jpeg', 'image/png', 'image/webp', 'image/gif'].includes(file.type)) {
      toast.error('Nur JPEG, PNG, WebP oder GIF erlaubt')
      return
    }
    const reader = new FileReader()
    reader.onload = () => setImagePreview(reader.result as string)
    reader.readAsDataURL(file)
    setUploading(true)
    try {
      const supabase = createClient()
      const ext = file.name.split('.').pop() ?? 'jpg'
      const path = `${currentUserId}/${Date.now()}_${Math.random().toString(36).slice(2)}.${ext}`
      const { error: upErr } = await supabase.storage.from('post-images').upload(path, file, { upsert: false })
      if (upErr) { toast.error('Upload fehlgeschlagen'); setImagePreview(null); setUploading(false); return }
      const { data: urlData } = supabase.storage.from('post-images').getPublicUrl(path)
      setImageUrl(urlData.publicUrl)
      toast.success('Bild hochgeladen')
    } catch {
      toast.error('Upload fehlgeschlagen')
      setImagePreview(null)
    } finally {
      setUploading(false)
    }
  }

  const validate = () => {
    const e: Record<string, string> = {}
    if (!form.title.trim()) e.title = 'Titel ist Pflichtfeld'
    else if (form.title.trim().length < 5) e.title = 'Mindestens 5 Zeichen'
    if (form.description.length > 2000) e.description = 'Beschreibung darf max. 2000 Zeichen haben'
    setErrors(e)
    return Object.keys(e).length === 0
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!currentUserId) { toast.error('Nicht eingeloggt'); return }
    if (!acceptedNoTrade) { toast.error('Bitte bestätige, dass kein Handel oder Geldgeschäft stattfindet.'); return }
    if (!validate()) return
    setSubmitting(true)

    const allowed = await checkRateLimit(currentUserId, 'create_post', 2, 10)
    if (!allowed) {
      toast.error('Zu viele Beiträge in kurzer Zeit. Bitte warte etwas.')
      setSubmitting(false)
      return
    }

    const supabase = createClient()
    const { error } = await supabase.from('posts').insert({
      user_id: currentUserId,
      type: form.type,
      category: form.category,
      title: form.title.trim(),
      description: form.description.trim() || 'Keine weiteren Details angegeben.',
      location_text: form.location.trim() || null,
      ...(userLat !== null ? { latitude: userLat } : {}),
      ...(userLng !== null ? { longitude: userLng } : {}),
      contact_phone: form.is_anonymous ? null : form.contact_phone.trim() || null,
      contact_whatsapp: form.is_anonymous ? null : form.contact_whatsapp.trim() || null,
      urgency: form.urgency,
      is_anonymous: form.is_anonymous,
      ...(tags.length > 0 ? { tags } : {}),
      ...(imageUrl ? { media_urls: [imageUrl] } : {}),
      status: 'active',
    })

    if (error) {
      toast.error('Fehler: ' + error.message)
      setSubmitting(false)
      return
    }

    toast.success('Beitrag erfolgreich veröffentlicht! 🌿')
    setSuccess(true)
    setTimeout(() => router.push(returnRoute), 2500)
  }

  const suggestions = TITLE_SUGGESTIONS[form.type] ?? []

  if (!authChecked) {
    return (
      <div className="min-h-dvh flex items-center justify-center bg-paper">
        <div className="w-8 h-8 border-4 border-primary-300 border-t-primary-600 rounded-full animate-spin" />
      </div>
    )
  }

  if (success) {
    return (
      <div className="min-h-dvh flex items-center justify-center bg-primary-50">
        <div className="text-center p-8">
          <div className="w-16 h-16 bg-primary-100 border border-primary-200 rounded-2xl flex items-center justify-center mx-auto mb-4">
            <CheckCircle2 className="w-8 h-8 text-primary-600" aria-hidden="true" />
          </div>
          <h2 className="font-display text-2xl font-medium text-ink-800 mb-2">Beitrag veröffentlicht!</h2>
          <p className="text-ink-600 mb-1">Dein Beitrag ist jetzt für die Community sichtbar.</p>
          <p className="text-sm text-ink-400">Du wirst weitergeleitet…</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-dvh bg-paper">
      {/* Gradient-Header */}
      <div className={cn('bg-gradient-to-r text-white px-4 sm:px-6 py-6', gradientFrom, gradientTo)}>
        <div className="max-w-2xl mx-auto">
          <Link href={returnRoute} className="flex items-center gap-2 text-white/85 hover:text-white text-sm mb-4">
            <ArrowLeft className="w-4 h-4" /> Zurück zum Modul
          </Link>
          <h1 className="text-2xl font-bold flex items-center gap-3">
            <span className="flex items-center justify-center w-8 h-8" aria-hidden="true">{iconComponent}</span>
            {moduleTitle}
          </h1>
          <p className="text-white/85 text-sm mt-1">{moduleDescription}</p>
        </div>
      </div>

      <div className="max-w-2xl mx-auto px-4 sm:px-6 py-8">
        {topBanner}

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Intent-Vorschlag (zeigt sich, wenn Inhalt nicht zum gewählten Typ passt) */}
          <IntentSuggestionBanner
            title={form.title}
            description={form.description}
            currentType={form.type}
            navigateOnAccept
            onAccept={(intent: IntentType) => {
              const supported = createTypes.find(t => t.value === intent)
              if (supported) handleTypeChange(supported.value)
            }}
          />

          {/* Sektion 1: Typ & Kategorie */}
          <div className="bg-white rounded-2xl border border-stone-100 shadow-md p-6 space-y-4">
            <h2 className="font-bold text-ink-900 text-lg">Art & Kategorie</h2>

            <div>
              <label className="text-sm font-medium text-ink-700 mb-1.5 block">Art des Beitrags *</label>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {createTypes.map(t => (
                  <button
                    key={t.value}
                    type="button"
                    onClick={() => handleTypeChange(t.value)}
                    className={cn(
                      'min-h-[44px] px-3 py-2.5 rounded-xl text-sm font-medium border transition-all text-left',
                      form.type === t.value
                        ? cn('bg-primary-50 border-primary-400 ring-2 text-primary-800', ringColor)
                        : 'bg-white text-ink-700 border-stone-200 hover:border-primary-200',
                    )}
                  >
                    {t.label}
                    {t.desc && <span className="block text-xs text-ink-500 mt-0.5">{t.desc}</span>}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <label htmlFor="post-category" className="text-sm font-medium text-ink-700 mb-1.5 block">Kategorie *</label>
              <select
                id="post-category"
                value={form.category}
                onChange={e => set('category', e.target.value)}
                aria-label="Kategorie"
                className="w-full border border-stone-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
              >
                {categories.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
            </div>
          </div>

          {/* Sektion 2: Dringlichkeit */}
          <div className="bg-white rounded-2xl border border-stone-100 shadow-md p-6">
            <h2 className="font-bold text-ink-900 text-lg mb-4">Dringlichkeit</h2>
            <div className="grid grid-cols-3 gap-2">
              {[
                { v: 'low',    l: '🟦 Normal',   a: 'bg-primary-600 text-white border-primary-600' },
                { v: 'medium', l: '🟧 Mittel',   a: 'bg-orange-500 text-white border-orange-500' },
                { v: 'high',   l: '🔴 Dringend', a: 'bg-red-600 text-white border-red-600' },
              ].map(({ v, l, a }) => (
                <button
                  key={v}
                  type="button"
                  onClick={() => set('urgency', v)}
                  className={cn(
                    'min-h-[44px] py-2.5 rounded-xl text-xs font-semibold border transition-all',
                    form.urgency === v ? a : 'bg-white text-ink-700 border-stone-200 hover:border-primary-200',
                  )}
                >
                  {l}
                </button>
              ))}
            </div>
          </div>

          {/* Sektion 3: Titel */}
          <div className="bg-white rounded-2xl border border-stone-100 shadow-md p-6 space-y-4">
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label htmlFor="post-title" className="text-sm font-medium text-ink-700 flex items-center gap-2">
                  Titel *
                  <VoiceInputButton
                    label="Titel"
                    onResult={t => set('title', form.title ? `${form.title} ${t}` : t)}
                  />
                </label>
                {suggestions.length > 0 && (
                  <button
                    type="button"
                    onClick={() => setShowSuggestions(s => !s)}
                    className="flex items-center gap-1 text-xs text-violet-600 hover:text-violet-700 font-medium"
                  >
                    <Sparkles className="w-3 h-3" /> Vorschläge
                  </button>
                )}
              </div>
              {showSuggestions && (
                <div className="mb-2 p-2 bg-violet-50 border border-violet-200 rounded-xl space-y-1">
                  {suggestions.map(s => (
                    <button
                      key={s}
                      type="button"
                      onClick={() => { set('title', s); setShowSuggestions(false) }}
                      className="block w-full text-left text-xs text-violet-800 hover:bg-violet-100 px-2 py-1 rounded-lg transition-colors"
                    >
                      {s}
                    </button>
                  ))}
                </div>
              )}
              <input
                id="post-title"
                value={form.title}
                onChange={e => { set('title', e.target.value); setErrors(er => ({ ...er, title: '' })) }}
                placeholder="Kurze, klare Beschreibung"
                maxLength={80}
                className={cn(
                  'w-full border rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary-300',
                  errors.title ? 'border-red-400' : 'border-stone-200',
                )}
              />
              <div className="flex justify-between mt-1">
                {errors.title ? <p className="text-xs text-red-500">{errors.title}</p> : <span />}
                <p className="text-xs text-ink-400">{form.title.length}/80</p>
              </div>
            </div>

            <div>
              <label htmlFor="post-description" className="text-sm font-medium text-ink-700 mb-1.5 flex items-center gap-2">
                Beschreibung
                <VoiceInputButton
                  label="Beschreibung"
                  onResult={t => set('description', form.description ? `${form.description} ${t}` : t)}
                />
                <span className="font-normal text-ink-400 text-xs">optional</span>
              </label>
              <textarea
                id="post-description"
                value={form.description}
                onChange={e => set('description', e.target.value)}
                placeholder="Was genau benötigst du / bietest du an?"
                rows={4}
                maxLength={2000}
                className={cn(
                  'w-full border rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary-300 resize-none',
                  errors.description ? 'border-red-400' : 'border-stone-200',
                )}
              />
              <div className="flex justify-between mt-1">
                {errors.description ? <p className="text-xs text-red-500">{errors.description}</p> : <span />}
                <p className="text-xs text-ink-400">{form.description.length}/2000</p>
              </div>
            </div>
          </div>

          {/* Modulspezifische Zusatzfelder */}
          {extraFields}

          {/* Sektion 5: Standort */}
          <div className="bg-white rounded-2xl border border-stone-100 shadow-md p-6 space-y-3">
            <h2 className="font-bold text-ink-900 text-lg flex items-center gap-2">
              <MapPin className="w-5 h-5 text-primary-500" /> Standort
            </h2>
            <div>
              <label htmlFor="post-location" className="text-sm font-medium text-ink-700 mb-1.5 block">
                Adresse <span className="font-normal text-ink-400 text-xs">optional</span>
              </label>
              <input
                id="post-location"
                value={form.location}
                onChange={e => set('location', e.target.value)}
                placeholder="z.B. Wien, 1010 oder Graz-Mitte"
                className="w-full border border-stone-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
              />
              <div className="flex items-center gap-2 mt-2">
                <button
                  type="button"
                  onClick={handleGetLocation}
                  disabled={gettingLocation}
                  className="min-h-[44px] flex items-center gap-1.5 px-3 py-2 text-xs font-medium border border-primary-300 bg-primary-50 text-primary-700 rounded-xl hover:bg-primary-100 transition-all disabled:opacity-60"
                >
                  {gettingLocation
                    ? <span className="w-3.5 h-3.5 border-2 border-primary-300 border-t-primary-600 rounded-full animate-spin" />
                    : <Locate className="w-3.5 h-3.5" />}
                  Meinen Standort verwenden
                </button>
                {userLat !== null && (
                  <span className="text-xs text-green-600 flex items-center gap-1">
                    <MapPin className="w-3 h-3" /> Koordinaten gesetzt
                  </span>
                )}
              </div>
            </div>
          </div>

          {/* Sektion 6: Bild */}
          <div className="bg-white rounded-2xl border border-stone-100 shadow-md p-6">
            <h2 className="font-bold text-ink-900 text-lg mb-4 flex items-center gap-2">
              <ImagePlus className="w-5 h-5 text-amber-500" /> Bild
              <span className="font-normal text-ink-400 text-xs ml-1">optional · max. 10 MB</span>
            </h2>
            <input
              ref={fileRef}
              type="file"
              accept="image/jpeg,image/png,image/webp,image/gif"
              onChange={handleImageUpload}
              className="hidden"
              aria-label="Bild auswählen"
            />
            {imagePreview ? (
              <div className="relative inline-block">
                <img src={imagePreview} alt="Vorschau" className="h-24 w-24 object-cover rounded-xl border border-stone-200" />
                {uploading && (
                  <div className="absolute inset-0 flex items-center justify-center bg-black/40 rounded-xl">
                    <LoaderCircle className="w-5 h-5 text-white animate-spin" />
                  </div>
                )}
                <button
                  type="button"
                  onClick={() => { setImageUrl(null); setImagePreview(null); if (fileRef.current) fileRef.current.value = '' }}
                  aria-label="Bild entfernen"
                  className="absolute -top-1.5 -right-1.5 bg-white rounded-full p-1 shadow border border-stone-200"
                >
                  <X className="w-3 h-3 text-ink-500" />
                </button>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => fileRef.current?.click()}
                className="min-h-[44px] flex items-center gap-2 px-4 py-2.5 text-sm text-ink-600 border border-dashed border-stone-300 rounded-xl hover:bg-stone-50 transition"
              >
                <ImagePlus className="w-4 h-4" /> Bild hinzufügen
              </button>
            )}
          </div>

          {/* Sektion 7: Tags */}
          <div className="bg-white rounded-2xl border border-stone-100 shadow-md p-6">
            <h2 className="font-bold text-ink-900 text-lg mb-3 flex items-center gap-2">
              <Tag className="w-4 h-4 text-violet-500" /> Tags
              <span className="font-normal text-ink-400 text-xs ml-1">max. 5</span>
            </h2>
            <div className="flex gap-2">
              <input
                value={tagInput}
                onChange={e => setTagInput(e.target.value.replace(/[^a-zA-ZäöüÄÖÜß0-9-]/g, ''))}
                onKeyDown={e => { if ((e.key === 'Enter' || e.key === ',') && tagInput.trim()) { e.preventDefault(); addTag() } }}
                placeholder="Tag + Enter"
                className="flex-1 border border-stone-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
                maxLength={20}
                disabled={tags.length >= 5}
                aria-label="Tag hinzufügen"
              />
              <button
                type="button"
                onClick={addTag}
                disabled={!tagInput.trim() || tags.length >= 5}
                aria-label="Tag hinzufügen"
                className="min-h-[44px] px-4 py-2 bg-violet-600 text-white text-sm font-bold rounded-xl hover:bg-violet-700 disabled:opacity-40 transition-all"
              >
                +
              </button>
            </div>
            {tags.length > 0 && (
              <div className="flex flex-wrap gap-1.5 mt-3">
                {tags.map(tag => (
                  <span key={tag} className="flex items-center gap-1 bg-violet-100 text-violet-700 px-2.5 py-1 rounded-full text-xs font-medium">
                    #{tag}
                    <button
                      type="button"
                      onClick={() => setTags(t => t.filter(x => x !== tag))}
                      aria-label={`Tag ${tag} entfernen`}
                    >
                      <X className="w-3 h-3" />
                    </button>
                  </span>
                ))}
              </div>
            )}
          </div>

          {/* Sektion 8: Kontakt */}
          {!form.is_anonymous && (
            <div className="bg-white rounded-2xl border border-stone-100 shadow-md p-6 space-y-4">
              <h2 className="font-bold text-ink-900 text-lg">Kontakt</h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label htmlFor="post-phone" className="text-sm font-medium text-ink-700 mb-1.5 block">Telefon</label>
                  <input
                    id="post-phone"
                    type="tel"
                    value={form.contact_phone}
                    onChange={e => set('contact_phone', e.target.value)}
                    placeholder="+43 xxx xxx"
                    className="w-full border border-stone-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
                  />
                </div>
                <div>
                  <label htmlFor="post-whatsapp" className="text-sm font-medium text-ink-700 mb-1.5 block">WhatsApp</label>
                  <input
                    id="post-whatsapp"
                    type="tel"
                    value={form.contact_whatsapp}
                    onChange={e => set('contact_whatsapp', e.target.value)}
                    placeholder="+43 xxx xxx"
                    className="w-full border border-stone-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
                  />
                </div>
              </div>
              {errors.contact && (
                <p className="text-xs text-red-500 flex items-center gap-1">
                  <AlertTriangle className="w-3.5 h-3.5" /> {errors.contact}
                </p>
              )}
            </div>
          )}

          {/* Sektion 9: Optionen */}
          {showAnonymous && (
            <div className="bg-white rounded-2xl border border-stone-100 shadow-md p-6">
              <h2 className="font-bold text-ink-900 text-lg mb-3">Optionen</h2>
              <button
                type="button"
                onClick={() => set('is_anonymous', !form.is_anonymous)}
                className={cn(
                  'w-full flex items-start gap-3 p-3 rounded-xl border transition-all text-left',
                  form.is_anonymous ? 'bg-cyan-50 border-cyan-300' : 'bg-white border-stone-200 hover:border-cyan-200',
                )}
              >
                {form.is_anonymous
                  ? <EyeOff className="w-5 h-5 text-cyan-600 flex-shrink-0 mt-0.5" />
                  : <Eye className="w-5 h-5 text-ink-400 flex-shrink-0 mt-0.5" />}
                <div className="flex-1">
                  <p className="text-sm font-semibold text-ink-900">Anonym posten</p>
                  <p className="text-xs text-ink-500 mt-0.5">
                    {form.is_anonymous ? 'Anonym aktiv – kein Kontakt nötig' : 'Name & Kontakt werden angezeigt'}
                  </p>
                </div>
                <div className={cn(
                  'w-5 h-5 rounded border flex items-center justify-center flex-shrink-0',
                  form.is_anonymous ? 'bg-cyan-500 border-cyan-500' : 'border-stone-300',
                )}>
                  {form.is_anonymous && <span className="text-white text-xs font-bold">✓</span>}
                </div>
              </button>
            </div>
          )}

          {/* Kein-Handel-Bestätigung */}
          <div className="bg-white rounded-2xl border border-stone-100 shadow-md p-6">
            <button
              type="button"
              onClick={() => setAcceptedNoTrade(v => !v)}
              className="flex items-start gap-3 w-full text-left"
            >
              <div className={cn(
                'w-5 h-5 rounded border-2 flex items-center justify-center flex-shrink-0 mt-0.5 transition-all',
                acceptedNoTrade ? 'bg-primary-500 border-primary-500' : 'border-amber-400 bg-white',
              )}>
                {acceptedNoTrade && <span className="text-white text-xs font-bold">✓</span>}
              </div>
              <div>
                <p className="text-sm font-semibold text-ink-900">Kein Handel / kein Geldgeschäft *</p>
                <p className="text-xs text-ink-500 mt-0.5">
                  Ich bestätige, dass dieser Beitrag <strong>keinen kommerziellen Handel, Verkauf oder Geldgeschäfte</strong> beinhaltet.
                  <Link href="/nutzungsbedingungen" target="_blank" rel="noopener noreferrer" className="text-primary-600 hover:underline ml-1">Siehe AGB §4</Link>
                </p>
              </div>
            </button>
          </div>

          {/* Footer mit Abbrechen + Veröffentlichen */}
          <div className="flex gap-4">
            <Link
              href={returnRoute}
              className="flex-1 min-h-[44px] py-3 border border-stone-200 rounded-xl text-sm font-semibold text-ink-700 hover:bg-stone-50 transition-colors text-center flex items-center justify-center"
            >
              Abbrechen
            </Link>
            <button
              type="submit"
              disabled={submitting || uploading || !acceptedNoTrade}
              className="flex-1 min-h-[44px] py-3 bg-primary-600 text-white rounded-xl text-sm font-semibold hover:bg-primary-700 disabled:opacity-60 transition-colors flex items-center justify-center gap-2"
            >
              {submitting
                ? <><div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" /> Wird gespeichert…</>
                : <><Plus className="w-4 h-4" /> Veröffentlichen</>}
            </button>
          </div>

          {/* moduleKey nicht direkt im Insert (DB hat die Spalte nicht), aber für künftige Verwendung exposed */}
          <input type="hidden" name="moduleKey" value={moduleKey} />
        </form>
      </div>
    </div>
  )
}
