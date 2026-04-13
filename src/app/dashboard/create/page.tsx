'use client'

import { useState, useEffect, useRef, Suspense } from 'react'
import { useSearchParams, useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import {
  FilePlus, MapPin, Phone, MessageCircle, X, Tag,
  Eye, EyeOff, CheckCircle2, ChevronRight, Sparkles, Clock,
  Calendar, AlertTriangle, ImagePlus, Link2, Locate, LoaderCircle,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { checkRateLimit } from '@/lib/rate-limit'

// Valid DB types: rescue, animal, housing, supply, mobility, sharing, community, crisis
const TYPES = [
  { value: 'rescue',    label: '🔴 Hilfe suchen/anbieten', desc: 'Hilfe-Anfragen & Angebote', cat: 'everyday' },
  { value: 'help_offered', label: '🧡 Retter-Angebot',      desc: 'Ressourcen retten',           cat: 'food'     },
  { value: 'animal',   label: '🐾 Tierhilfe',               desc: 'Tier sucht / bietet Hilfe',  cat: 'animals'  },
  { value: 'housing',  label: '🏡 Wohnangebot',             desc: 'Wohnung oder Notunterkunft', cat: 'housing'  },
  { value: 'supply',   label: '🌾 Versorgung',              desc: 'Produkt anbieten / suchen',  cat: 'food'     },
  { value: 'sharing',  label: '🔄 Teilen / Skill-Angebot', desc: 'Teilen, Tauschen, Skill',    cat: 'sharing'  },
  { value: 'mobility', label: '🚗 Mobilität',               desc: 'Fahrt anbieten / suchen',    cat: 'mobility' },
  { value: 'community',label: '🗳️ Community / Wissen',    desc: 'Idee, Abstimmung, Guide',    cat: 'general'  },
  { value: 'crisis',   label: '🚨 Notfall / Mentales',     desc: 'Notfall oder Gespräch suchen',cat: 'emergency'},
]

// Valid DB categories: food, everyday, moving, animals, housing, skills, knowledge, mental, mobility, sharing, emergency, general
const CATEGORIES = [
  { value: 'food',      label: '🍎 Essen & Versorgung' },
  { value: 'everyday',  label: '🏠 Alltag & Hilfe'     },
  { value: 'moving',    label: '📦 Umzug'               },
  { value: 'animals',   label: '🐾 Tiere'               },
  { value: 'housing',   label: '🏡 Wohnen'              },
  { value: 'skills',    label: '🛠️ Fähigkeiten'        },
  { value: 'knowledge', label: '📚 Bildung & Wissen'    },
  { value: 'mental',    label: '💙 Mentales'             },
  { value: 'mobility',  label: '🚗 Mobilität'           },
  { value: 'sharing',   label: '🔄 Teilen/Tauschen'     },
  { value: 'emergency', label: '🚨 Notfall'              },
  { value: 'general',   label: '🌿 Sonstiges'           },
]

// Title suggestions per type
const TITLE_SUGGESTIONS: Record<string, string[]> = {
  help_request:  ['Brauche Hilfe beim Einkaufen', 'Suche jemanden der mir hilft', 'Brauche dringend Unterstützung'],
  help_offered:  ['Biete Hilfe beim Einkaufen an', 'Kann beim Umzug helfen', 'Stehe als Ansprechperson zur Verfügung'],
  rescue:        ['Rette Lebensmittel – bitte abholen', 'Überschuss vom Garten kostenlos', 'Reste aus Catering zu vergeben'],
  animal:        ['Katze entlaufen – bitte melden', 'Biete Tierbetreuung an', 'Suche Pflegestelle für Hund'],
  housing:       ['Biete Zimmer für 1 Person', 'Suche kurzfristig Unterkunft', 'Notunterkunft für Familie verfügbar'],
  supply:        ['Gemüse vom Garten zu verschenken', 'Suche regional erzeugte Produkte', 'Biete Holz aus eigenem Wald'],
  skill:         ['Gebe Deutschunterricht', 'Helfe bei Computerproblemen', 'Biete Handwerker-Hilfe an'],
  mobility:      ['Fahre nach Wien – Mitfahrer willkommen', 'Suche Mitfahrt nach Salzburg', 'Biete wöchentliche Fahrt an'],
  sharing:       ['Verleihe Werkzeug kostenlos', 'Tausche Bücher gegen Lebensmittel', 'Gebe Kindersachen weiter'],
  community:     ['Idee für Gemeinschaftsgarten', 'Abstimmung: Neues Community-Projekt', 'Vorschlag für Treffen'],
  crisis:        ['DRINGEND: Brauche sofortige Hilfe', 'Notfall – bitte melden', 'Medizinische Versorgung gesucht'],
  knowledge:     ['Anleitung: Gemüse einkochen', 'Tipps für nachhaltigen Alltag', 'Guide: Erste Hilfe Grundlagen'],
  mental:        ['Suche jemanden zum Reden', 'Biete Begleitung bei schwierigen Zeiten', 'Möchte Erfahrungen teilen'],
}

function CreatePostForm() {
  const searchParams = useSearchParams()
  const router = useRouter()
  const initialType = searchParams.get('type') ?? 'rescue'

  const [step, setStep] = useState(1)
  const [userId, setUserId] = useState<string>()
  const [loading, setLoading] = useState(false)
  const [tagInput, setTagInput] = useState('')
  const [tags, setTags] = useState<string[]>([])
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [showSuggestions, setShowSuggestions] = useState(false)

  const [imageUrl, setImageUrl] = useState<string | null>(null)
  const [imagePreview, setImagePreview] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)
  const [mediaUrlInput, setMediaUrlInput] = useState('')
  const [mediaUrls, setMediaUrls] = useState<string[]>([])
  const [userLat, setUserLat] = useState<number | null>(null)
  const [userLng, setUserLng] = useState<number | null>(null)
  const [gettingLocation, setGettingLocation] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)

  const [acceptedNoTrade, setAcceptedNoTrade] = useState(false)

  const [form, setForm] = useState({
    type: initialType,
    category: TYPES.find(t => t.value === initialType)?.cat ?? 'general',
    title: '',
    description: '',
    location: '',
    contact_phone: '',
    contact_whatsapp: '',
    urgency: initialType === 'crisis' ? 'high' : 'low',
    event_date: '',
    event_time: '',
    duration_hours: '',
    is_anonymous: false,
    availability_start: '',
    availability_end: '',
  })

  useEffect(() => {
    createClient().auth.getUser().then(({ data: { user } }) => {
      if (user) setUserId(user.id)
    })
  }, [])

  const set = (k: string, v: string | boolean) => setForm(f => ({ ...f, [k]: v }))

  // Auto-set category & urgency when type changes
  const handleTypeChange = (typeValue: string) => {
    const t = TYPES.find(x => x.value === typeValue)
    setForm(f => ({
      ...f,
      type: typeValue,
      category: t?.cat ?? f.category,
      urgency: typeValue === 'crisis' ? 'high' : f.urgency,
    }))
    setErrors({})
  }

  const validateStep1 = () => {
    const e: Record<string, string> = {}
    if (!form.type) e.type = 'Bitte Art auswählen'
    setErrors(e)
    return Object.keys(e).length === 0
  }

  const validateStep2 = () => {
    const e: Record<string, string> = {}
    if (!form.title.trim()) e.title = 'Titel ist Pflichtfeld'
    else if (form.title.trim().length < 5) e.title = 'Titel muss mindestens 5 Zeichen haben'
    setErrors(e)
    return Object.keys(e).length === 0
  }

  const validateStep3 = () => {
    const e: Record<string, string> = {}
    if (!form.is_anonymous && !form.contact_phone && !form.contact_whatsapp) {
      e.contact = 'Mindestens Telefon oder WhatsApp ist Pflicht (oder wähle "Anonym posten")'
    }
    setErrors(e)
    return Object.keys(e).length === 0
  }

  const handleSubmit = async () => {
    if (!userId) { toast.error('Nicht eingeloggt'); return }
    if (!acceptedNoTrade) { toast.error('Bitte bestätige, dass kein Handel oder Geldgeschäft stattfindet.'); return }
    if (!validateStep3()) return
    setLoading(true)
    const allowed = await checkRateLimit(userId, 'create_post', 2, 10)
    if (!allowed) { toast.error('Zu viele Beiträge in kurzer Zeit. Bitte warte etwas.'); setLoading(false); return }
    const supabase = createClient()
    const allMediaUrls = [
      ...(imageUrl ? [imageUrl] : []),
      ...mediaUrls,
    ]
    const { error } = await supabase.from('posts').insert({
      user_id: userId,
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
      ...(allMediaUrls.length > 0 ? { media_urls: allMediaUrls } : {}),
      ...(form.event_date ? { event_date: form.event_date } : {}),
      ...(form.event_time ? { event_time: form.event_time } : {}),
      ...(form.duration_hours ? { duration_hours: parseFloat(form.duration_hours) } : {}),
      ...(form.availability_start ? { availability_start: form.availability_start } : {}),
      ...(form.availability_end ? { availability_end: form.availability_end } : {}),
      status: 'active',
    })
    setLoading(false)
    if (error) { toast.error('Fehler: ' + error.message); return }
    toast.success('Beitrag erfolgreich veröffentlicht! 🌿')
    router.push('/dashboard/posts')
  }

  const selectedType = TYPES.find(t => t.value === form.type)
  const suggestions = TITLE_SUGGESTIONS[form.type] ?? []

  const addTag = () => {
    const t = tagInput.trim().toLowerCase()
    if (t && !tags.includes(t) && tags.length < 5) { setTags(prev => [...prev, t]); setTagInput('') }
  }

  // Image upload handler
  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file || !userId) return
    if (file.size > 10 * 1024 * 1024) { toast.error('Bild zu groß (max. 10 MB)'); return }
    if (!['image/jpeg', 'image/png', 'image/webp', 'image/gif'].includes(file.type)) {
      toast.error('Nur JPEG, PNG, WebP oder GIF erlaubt'); return
    }
    const reader = new FileReader()
    reader.onload = () => setImagePreview(reader.result as string)
    reader.readAsDataURL(file)
    setUploading(true)
    try {
      const supabase = createClient()
      const ext = file.name.split('.').pop() ?? 'jpg'
      const path = `${userId}/${Date.now()}_${Math.random().toString(36).slice(2)}.${ext}`
      const { error: upErr } = await supabase.storage.from('post-images').upload(path, file, { upsert: false })
      if (upErr) { toast.error('Upload fehlgeschlagen: ' + upErr.message); setImagePreview(null); setUploading(false); return }
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

  const addMediaUrl = () => {
    const url = mediaUrlInput.trim()
    if (!url) return
    try { new URL(url) } catch { toast.error('Ungültige URL'); return }
    if (mediaUrls.length >= 5) { toast.error('Maximal 5 Medien-URLs'); return }
    if (!mediaUrls.includes(url)) setMediaUrls(prev => [...prev, url])
    setMediaUrlInput('')
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
            const parts = data.display_name.split(',')
            set('location', parts.slice(0, 3).join(',').trim())
          }
        } catch {}
        setGettingLocation(false)
      },
      () => setGettingLocation(false),
      { timeout: 10000 },
    )
  }

  return (
    <div className="max-w-2xl mx-auto">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <FilePlus className="w-6 h-6 text-primary-600" />
          Neuen Beitrag erstellen
        </h1>
        <p className="text-gray-500 text-sm mt-1">Dein Beitrag wird sofort in Feed, Karte und passenden Modulen sichtbar</p>
      </div>

      {/* Progress steps */}
      <div className="flex items-center mb-8">
        {[
          { n: 1, label: 'Art & Kategorie' },
          { n: 2, label: 'Inhalt' },
          { n: 3, label: 'Kontakt' },
        ].map(({ n, label }, i) => (
          <div key={n} className="flex items-center flex-1">
            <div className="flex items-center gap-2">
              <div className={cn(
                'w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold transition-all',
                step > n ? 'bg-primary-600 text-white' :
                step === n ? 'bg-primary-600 text-white ring-4 ring-primary-100' :
                'bg-warm-100 text-gray-400'
              )}>
                {step > n ? <CheckCircle2 className="w-4 h-4" /> : n}
              </div>
              <span className={cn('text-xs font-medium hidden sm:block', step >= n ? 'text-primary-700' : 'text-gray-400')}>
                {label}
              </span>
            </div>
            {i < 2 && <div className={cn('flex-1 h-0.5 mx-2 transition-all', step > n ? 'bg-primary-400' : 'bg-warm-200')} />}
          </div>
        ))}
      </div>

      <div className="bg-white rounded-2xl border border-warm-200 p-6 shadow-sm">

        {/* ── Schritt 1: Art & Kategorie ── */}
        {step === 1 && (
          <div className="space-y-5">
            <div>
              <label className="label text-base font-semibold">Welche Art von Beitrag? *</label>
              {/* Horizontal scroll chips on mobile, grid on desktop */}
              <div className="flex gap-2 mt-2 overflow-x-auto snap-x snap-mandatory pb-2 no-scrollbar md:grid md:grid-cols-3 md:overflow-visible md:snap-none md:pb-0">
                {TYPES.map(t => (
                  <button key={t.value} type="button" onClick={() => handleTypeChange(t.value)}
                    className={cn(
                      'p-3 rounded-xl border text-left transition-all hover:shadow-sm snap-start shrink-0 w-48 md:w-auto touch-target',
                      form.type === t.value
                        ? 'bg-primary-50 border-primary-400 ring-1 ring-primary-300 shadow-sm'
                        : 'bg-white border-warm-200 hover:border-primary-200'
                    )}>
                    <div className="text-sm font-semibold text-gray-800">{t.label}</div>
                    <div className="text-xs text-gray-500 mt-0.5">{t.desc}</div>
                  </button>
                ))}
              </div>
            </div>

            <div>
              <label className="label text-base font-semibold">Kategorie *
                <span className="text-xs font-normal text-primary-600 ml-2">→ automatisch gewählt</span>
              </label>
              <div className="flex gap-2 mt-2 overflow-x-auto snap-x pb-2 no-scrollbar md:grid md:grid-cols-4 md:overflow-visible md:snap-none md:pb-0">
                {CATEGORIES.map(c => (
                  <button key={c.value} type="button" onClick={() => set('category', c.value)}
                    className={cn(
                      'px-3 py-2.5 rounded-xl border text-xs font-medium text-center transition-all whitespace-nowrap shrink-0 snap-start touch-target md:whitespace-normal md:shrink',
                      form.category === c.value
                        ? 'bg-primary-600 text-white border-primary-600'
                        : 'bg-white text-gray-700 border-warm-200 hover:border-primary-200'
                    )}>
                    {c.label}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <label className="label text-base font-semibold">Dringlichkeit</label>
              <div className="flex gap-2 mt-2">
                {[
                  { v: 'low', l: '🟦 Normal', active: 'bg-primary-600 text-white border-primary-600' },
                  { v: 'medium', l: '🟧 Mittel', active: 'bg-orange-500 text-white border-orange-500' },
                  { v: 'high',   l: '🔴 Dringend', active: 'bg-red-600 text-white border-red-600' },
                ].map(({ v, l, active }) => (
                  <button key={v} type="button" onClick={() => set('urgency', v)}
                    className={cn('flex-1 py-2.5 rounded-xl text-sm font-semibold border transition-all',
                      form.urgency === v ? active : 'bg-white text-gray-600 border-warm-200 hover:border-primary-200')}>
                    {l}
                  </button>
                ))}
              </div>
            </div>

            <button onClick={() => { if (validateStep1()) setStep(2) }}
              className="btn-primary w-full py-3 flex items-center justify-center gap-2">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        )}

        {/* ── Schritt 2: Inhalt ── */}
        {step === 2 && (
          <div className="space-y-5">
            {/* Type badge */}
            <div className="flex items-center gap-2 p-3 bg-primary-50 rounded-xl border border-primary-200">
              <span className="text-sm font-semibold text-primary-700">{selectedType?.label}</span>
              <button onClick={() => setStep(1)} className="ml-auto text-xs text-primary-500 hover:underline">Ändern</button>
            </div>

            {/* Titel mit Vorschlägen */}
            <div>
              <div className="flex items-center justify-between mb-1">
                <label className="label">Titel *</label>
                <button type="button" onClick={() => setShowSuggestions(s => !s)}
                  className="flex items-center gap-1 text-xs text-violet-600 hover:text-violet-700 font-medium">
                  <Sparkles className="w-3.5 h-3.5" /> Vorschläge
                </button>
              </div>
              {showSuggestions && suggestions.length > 0 && (
                <div className="mb-2 p-3 bg-violet-50 border border-violet-200 rounded-xl space-y-1.5">
                  <p className="text-xs text-violet-600 font-semibold mb-2">Tipp: Klicke auf einen Vorschlag</p>
                  {suggestions.map(s => (
                    <button key={s} type="button"
                      onClick={() => { set('title', s); setShowSuggestions(false) }}
                      className="block w-full text-left text-xs text-violet-800 hover:bg-violet-100 px-2 py-1.5 rounded-lg transition-colors">
                      {s}
                    </button>
                  ))}
                </div>
              )}
              <input value={form.title} onChange={e => { set('title', e.target.value); setErrors(er => ({ ...er, title: '' })) }}
                placeholder="Kurze, klare Beschreibung deines Beitrags"
                maxLength={80} className={cn('input', errors.title && 'border-red-400 focus:ring-red-300')} />
              <div className="flex justify-between mt-1">
                {errors.title
                  ? <p className="text-xs text-red-500">{errors.title}</p>
                  : <span />}
                <p className="text-xs text-gray-400">{form.title.length}/80</p>
              </div>
            </div>

            {/* Beschreibung */}
            <div>
              <label className="label">Beschreibung
                <span className="text-xs font-normal text-gray-400 ml-2">optional, aber empfohlen</span>
              </label>
              <textarea value={form.description} onChange={e => set('description', e.target.value)}
                placeholder="Was genau benötigst du oder was bietest du an? Je mehr Details, desto besser."
                rows={4} className="input resize-none" />
              <p className="text-xs text-gray-400 mt-1">{form.description.length} Zeichen</p>
            </div>

            {/* Standort */}
            <div>
              <label className="label flex items-center gap-1.5">
                <MapPin className="w-4 h-4 text-gray-400" /> Standort / Ort
                <span className="text-xs font-normal text-gray-400 ml-1">optional</span>
              </label>
              <input value={form.location} onChange={e => set('location', e.target.value)}
                placeholder="z.B. Wien 1070, Graz-Mitte, München Schwabing" className="input" />
              <div className="flex items-center gap-2 mt-2">
                <button type="button" onClick={handleGetLocation} disabled={gettingLocation}
                  className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium border border-primary-300 bg-primary-50 text-primary-700 rounded-xl hover:bg-primary-100 transition-all">
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

            {/* Bild-Upload */}
            <div>
              <label className="label flex items-center gap-1.5">
                <ImagePlus className="w-4 h-4 text-gray-400" /> Bild
                <span className="text-xs font-normal text-gray-400 ml-1">optional – max. 10 MB</span>
              </label>
              <input ref={fileRef} type="file" accept="image/jpeg,image/png,image/webp,image/gif" onChange={handleImageUpload} className="hidden" />
              {imagePreview ? (
                <div className="relative inline-block mt-2">
                  <img src={imagePreview} alt="Vorschau" className="h-24 w-24 object-cover rounded-xl border border-warm-200" />
                  {uploading && (
                    <div className="absolute inset-0 flex items-center justify-center bg-black/40 rounded-xl">
                      <LoaderCircle className="w-5 h-5 text-white animate-spin" />
                    </div>
                  )}
                  <button type="button" onClick={() => { setImageUrl(null); setImagePreview(null); if (fileRef.current) fileRef.current.value = '' }}
                    className="absolute -top-2 -right-2 bg-white rounded-full p-0.5 shadow border border-warm-200">
                    <X className="w-3.5 h-3.5 text-gray-500" />
                  </button>
                </div>
              ) : (
                <button type="button" onClick={() => fileRef.current?.click()}
                  className="flex items-center gap-2 px-3 py-2 text-sm text-gray-600 border border-dashed border-warm-300 rounded-xl hover:bg-warm-50 transition mt-2">
                  <ImagePlus className="w-4 h-4" /> Bild hinzufügen
                </button>
              )}
            </div>

            {/* Medien-URLs */}
            <div>
              <label className="label flex items-center gap-1.5">
                <Link2 className="w-4 h-4 text-gray-400" /> Medien-Links
                <span className="text-xs font-normal text-gray-400 ml-1">optional – max. 5</span>
              </label>
              <div className="flex gap-2">
                <input value={mediaUrlInput} onChange={e => setMediaUrlInput(e.target.value)}
                  onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); addMediaUrl() } }}
                  placeholder="https://... (Video, Bild, etc.)" className="input flex-1 text-sm" disabled={mediaUrls.length >= 5} />
                <button type="button" onClick={addMediaUrl} disabled={!mediaUrlInput.trim() || mediaUrls.length >= 5}
                  className="px-3 py-2 bg-primary-600 text-white text-sm rounded-xl hover:bg-primary-700 disabled:opacity-40 transition-all">+</button>
              </div>
              {mediaUrls.length > 0 && (
                <div className="flex flex-wrap gap-2 mt-2">
                  {mediaUrls.map((url, i) => (
                    <span key={i} className="flex items-center gap-1 bg-blue-100 text-blue-700 px-2.5 py-1 rounded-full text-xs font-medium max-w-[200px]">
                      <span className="truncate">{new URL(url).hostname}</span>
                      <button type="button" onClick={() => setMediaUrls(m => m.filter((_, j) => j !== i))} className="hover:text-red-500"><X className="w-3 h-3" /></button>
                    </span>
                  ))}
                </div>
              )}
            </div>

            {/* Tags */}
            <div>
              <label className="label flex items-center gap-1.5">
                <Tag className="w-4 h-4 text-gray-400" /> Tags
                <span className="text-xs font-normal text-gray-400 ml-1">optional – max. 5</span>
              </label>
              <div className="flex gap-2">
                <input
                  value={tagInput}
                  onChange={e => setTagInput(e.target.value.replace(/[^a-zA-ZäöüÄÖÜß0-9-]/g, ''))}
                  onKeyDown={e => {
                    if ((e.key === 'Enter' || e.key === ',') && tagInput.trim()) {
                      e.preventDefault(); addTag()
                    }
                  }}
                  placeholder="Tag eingeben + Enter"
                  className="input flex-1 text-sm"
                  maxLength={20}
                  disabled={tags.length >= 5}
                />
                <button type="button" onClick={addTag} disabled={!tagInput.trim() || tags.length >= 5}
                  className="px-3 py-2 bg-violet-600 text-white text-sm rounded-xl hover:bg-violet-700 disabled:opacity-40 transition-all">
                  +
                </button>
              </div>
              {tags.length > 0 && (
                <div className="flex flex-wrap gap-2 mt-2">
                  {tags.map(tag => (
                    <span key={tag} className="flex items-center gap-1 bg-violet-100 text-violet-700 px-2.5 py-1 rounded-full text-xs font-medium">
                      #{tag}
                      <button type="button" onClick={() => setTags(t => t.filter(x => x !== tag))}
                        className="hover:text-red-500 transition-colors">
                        <X className="w-3 h-3" />
                      </button>
                    </span>
                  ))}
                </div>
              )}
            </div>

            {/* Verfügbarkeit */}
            <div className="bg-primary-50 p-4 rounded-xl border border-primary-200">
              <label className="label text-xs text-primary-700 flex items-center gap-1 mb-2">
                <Calendar className="w-3.5 h-3.5" /> Verfügbarkeit
                <span className="font-normal ml-1">Uhrzeit von – bis (optional)</span>
              </label>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-[10px] text-primary-600 mb-0.5 block">Verfügbar ab</label>
                  <input type="time" value={form.availability_start} onChange={e => set('availability_start', e.target.value)} className="input text-sm" />
                </div>
                <div>
                  <label className="text-[10px] text-primary-600 mb-0.5 block">Verfügbar bis</label>
                  <input type="time" value={form.availability_end} onChange={e => set('availability_end', e.target.value)}
                    className="input text-sm" />
                </div>
              </div>
            </div>

            {/* Datum + Zeit für Mobilität */}
            {form.type === 'mobility' && (
              <div className="grid grid-cols-2 gap-3 bg-indigo-50 p-4 rounded-xl border border-indigo-200">
                <p className="col-span-2 text-xs font-semibold text-indigo-700 flex items-center gap-1">
                  <Calendar className="w-3.5 h-3.5" /> Fahrplan-Details
                </p>
                <div>
                  <label className="label text-xs text-indigo-700">Fahrt-Datum</label>
                  <input type="date" value={form.event_date} onChange={e => set('event_date', e.target.value)}
                    className="input text-sm" />
                </div>
                <div>
                  <label className="label text-xs text-indigo-700">Abfahrtszeit</label>
                  <input type="time" value={form.event_time} onChange={e => set('event_time', e.target.value)}
                    className="input text-sm" />
                </div>
              </div>
            )}

            {/* Stunden für Zeitbank / skill / help_offer */}
            {(form.type === 'sharing' || form.type === 'rescue') && (
              <div className="bg-amber-50 p-4 rounded-xl border border-amber-200">
                <label className="label text-xs text-amber-700 flex items-center gap-1">
                  <Clock className="w-3.5 h-3.5" /> Zeitaufwand (Stunden)
                  <span className="font-normal ml-1">– für Zeitbank</span>
                </label>
                <input type="number" min="0.5" max="100" step="0.5"
                  value={form.duration_hours} onChange={e => set('duration_hours', e.target.value)}
                  placeholder="z.B. 2 oder 0.5" className="input text-sm mt-1" />
              </div>
            )}

            {/* Anonym-Toggle (immer sichtbar in Schritt 2) */}
            <div onClick={() => set('is_anonymous', !form.is_anonymous)}
              className={cn('flex items-start gap-3 p-3 rounded-xl border cursor-pointer transition-all select-none',
                form.is_anonymous ? 'bg-cyan-50 border-cyan-300' : 'bg-white border-warm-200 hover:border-cyan-200')}>
              {form.is_anonymous
                ? <EyeOff className="w-5 h-5 text-cyan-600 flex-shrink-0 mt-0.5" />
                : <Eye className="w-5 h-5 text-gray-400 flex-shrink-0 mt-0.5" />}
              <div className="flex-1">
                <p className="text-sm font-semibold text-gray-900">Anonym posten</p>
                <p className="text-xs text-gray-500 mt-0.5">
                  {form.is_anonymous
                    ? 'Du wirst als "Anonym" angezeigt – kein Kontakt erforderlich'
                    : 'Dein Name und Kontaktdaten werden sichtbar sein'}
                </p>
              </div>
              <div className={cn('w-5 h-5 rounded border flex items-center justify-center flex-shrink-0 mt-0.5',
                form.is_anonymous ? 'bg-cyan-500 border-cyan-500' : 'border-gray-300')}>
                {form.is_anonymous && <span className="text-white text-xs font-bold">✓</span>}
              </div>
            </div>

            <div className="flex gap-3">
              <button onClick={() => setStep(1)} className="btn-secondary flex-1">← Zurück</button>
              <button onClick={() => { if (validateStep2()) setStep(3) }}
                disabled={!form.title.trim()}
                className="btn-primary flex-1 flex items-center justify-center gap-2">
                Weiter <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}

        {/* ── Schritt 3: Kontakt & Veröffentlichen ── */}
        {step === 3 && (
          <div className="space-y-5">
            {form.is_anonymous ? (
              <div className="flex items-start gap-3 p-4 bg-cyan-50 border border-cyan-300 rounded-xl">
                <EyeOff className="w-5 h-5 text-cyan-600 flex-shrink-0 mt-0.5" />
                <div>
                  <p className="text-sm font-bold text-cyan-800">Anonym-Modus aktiv</p>
                  <p className="text-xs text-cyan-700 mt-0.5">
                    Dein Name und deine Kontaktdaten sind nicht sichtbar. Andere Nutzer können dir trotzdem über das Plattform-Nachrichtensystem schreiben.
                  </p>
                </div>
              </div>
            ) : (
              <>
                <div className="flex items-start gap-3 p-4 bg-amber-50 border border-amber-200 rounded-xl">
                  <AlertTriangle className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
                  <p className="text-sm text-amber-700">
                    Ohne Kontaktmöglichkeit kann niemand auf deinen Beitrag reagieren.
                    Mindestens <strong>Telefon oder WhatsApp</strong> ist erforderlich.
                  </p>
                </div>

                <div>
                  <label className="label flex items-center gap-1.5">
                    <Phone className="w-4 h-4 text-gray-400" /> Telefonnummer
                  </label>
                  <input value={form.contact_phone} onChange={e => { set('contact_phone', e.target.value); setErrors(er => ({ ...er, contact: '' })) }}
                    placeholder="+43 660 123 4567" className={cn('input', errors.contact && 'border-red-400')} />
                </div>

                <div>
                  <label className="label flex items-center gap-1.5">
                    <MessageCircle className="w-4 h-4 text-green-600" /> WhatsApp-Nummer
                  </label>
                  <input value={form.contact_whatsapp} onChange={e => { set('contact_whatsapp', e.target.value); setErrors(er => ({ ...er, contact: '' })) }}
                    placeholder="+43 660 123 4567" className={cn('input', errors.contact && 'border-red-400')} />
                </div>

                {errors.contact && (
                  <p className="text-xs text-red-500 flex items-center gap-1">
                    <AlertTriangle className="w-3.5 h-3.5" /> {errors.contact}
                  </p>
                )}

                {/* Anonym nachträglich */}
                <div onClick={() => set('is_anonymous', !form.is_anonymous)}
                  className="flex items-center gap-3 p-3 rounded-xl border border-warm-200 cursor-pointer hover:border-cyan-200 transition-all select-none">
                  <Eye className="w-4 h-4 text-gray-400" />
                  <p className="text-sm text-gray-600 flex-1">Doch lieber anonym posten? <span className="text-cyan-600 font-medium">Aktivieren</span></p>
                </div>
              </>
            )}

            {/* ── Kein-Handel-Bestätigung ── */}
            <div
              onClick={() => setAcceptedNoTrade(v => !v)}
              className={cn(
                'flex items-start gap-3 p-4 rounded-xl border cursor-pointer transition-all select-none',
                acceptedNoTrade
                  ? 'bg-primary-50 border-primary-300'
                  : 'bg-amber-50 border-amber-300'
              )}
            >
              <div className={cn(
                'w-5 h-5 rounded border-2 flex items-center justify-center flex-shrink-0 mt-0.5 transition-colors',
                acceptedNoTrade ? 'bg-primary-500 border-primary-500' : 'border-amber-400 bg-white'
              )}>
                {acceptedNoTrade && <span className="text-white text-xs font-bold">✓</span>}
              </div>
              <div className="flex-1">
                <p className="text-sm font-semibold text-gray-900">Kein Handel / kein Geldgeschäft *</p>
                <p className="text-xs text-gray-600 mt-0.5 leading-relaxed">
                  Ich bestätige, dass dieser Beitrag <strong>keinen kommerziellen Handel, Verkauf oder Geldgeschäfte</strong> beinhaltet.
                  Mensaena ist eine gemeinnützige Plattform für kostenlose Nachbarschaftshilfe.
                  Kommerzielle Angebote sind laut <a href="/nutzungsbedingungen" target="_blank" className="text-primary-600 underline">AGB §4</a> nicht erlaubt.
                </p>
              </div>
            </div>

            {/* Zusammenfassung */}
            <div className="p-4 bg-gray-50 rounded-xl border border-warm-200 space-y-2">
              <p className="text-sm font-semibold text-gray-700 flex items-center gap-1.5">
                <CheckCircle2 className="w-4 h-4 text-primary-600" /> Zusammenfassung
              </p>
              <div className="text-xs text-gray-600 space-y-1.5">
                <div className="flex gap-2"><span className="font-medium w-20 flex-shrink-0">Art:</span><span>{selectedType?.label}</span></div>
                <div className="flex gap-2"><span className="font-medium w-20 flex-shrink-0">Titel:</span><span className="line-clamp-2">{form.title}</span></div>
                {form.location && <div className="flex gap-2"><span className="font-medium w-20 flex-shrink-0">Ort:</span><span>{form.location}</span></div>}
                {imageUrl && <div className="flex gap-2"><span className="font-medium w-20 flex-shrink-0">Bild:</span><span className="text-green-600">Hochgeladen</span></div>}
                {mediaUrls.length > 0 && <div className="flex gap-2"><span className="font-medium w-20 flex-shrink-0">Medien:</span><span>{mediaUrls.length} Link(s)</span></div>}
                {(form.availability_start || form.availability_end) && (
                  <div className="flex gap-2"><span className="font-medium w-20 flex-shrink-0">Zeitraum:</span><span>{form.availability_start || '–'} bis {form.availability_end || '–'}</span></div>
                )}
                <div className="flex gap-2">
                  <span className="font-medium w-20 flex-shrink-0">Dringlichkeit:</span>
                  <span className={cn('px-2 py-0.5 rounded-full text-xs font-semibold',
                    form.urgency === 'high' ? 'bg-red-100 text-red-700' :
                    form.urgency === 'medium' ? 'bg-orange-100 text-orange-700' :
                    'bg-primary-100 text-primary-700')}>
                    {form.urgency === 'high' ? '🔴 Dringend' : form.urgency === 'medium' ? '🟧 Mittel' : '🟦 Normal'}
                  </span>
                </div>
                {tags.length > 0 && (
                  <div className="flex gap-2">
                    <span className="font-medium w-20 flex-shrink-0">Tags:</span>
                    <span>{tags.map(t => `#${t}`).join(', ')}</span>
                  </div>
                )}
                <div className="flex gap-2"><span className="font-medium w-20 flex-shrink-0">Sichtbarkeit:</span>
                  <span className={form.is_anonymous ? 'text-cyan-700 font-medium' : 'text-gray-600'}>
                    {form.is_anonymous ? '🔒 Anonym' : '👤 Öffentlich (mit Name)'}
                  </span>
                </div>
              </div>
            </div>

            <div className="flex gap-3">
              <button onClick={() => setStep(2)} className="btn-secondary flex-1">← Zurück</button>
              <button
                onClick={handleSubmit}
                disabled={loading || !acceptedNoTrade || (!form.is_anonymous && !form.contact_phone && !form.contact_whatsapp)}
                className="btn-primary flex-1 py-3 flex items-center justify-center gap-2">
                {loading
                  ? <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  : <><CheckCircle2 className="w-4 h-4" /> Jetzt veröffentlichen</>
                }
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

export default function CreatePage() {
  return (
    <Suspense fallback={
      <div className="flex justify-center py-16">
        <div className="w-8 h-8 border-4 border-primary-300 border-t-primary-600 rounded-full animate-spin" />
      </div>
    }>
      <CreatePostForm />
    </Suspense>
  )
}
