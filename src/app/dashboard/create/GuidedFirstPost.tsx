'use client'

import { useState, useRef, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { MapPin, ImagePlus, Loader2, X, CheckCircle2 } from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import { checkRateLimit } from '@/lib/rate-limit'

// ── Types ─────────────────────────────────────────────────────────────────────

interface TypeOption {
  emoji: string
  title: string
  desc: string
  type: string
  category: string
}

const TYPE_OPTIONS: TypeOption[] = [
  { emoji: '🙋', title: 'Ich brauche Hilfe',  desc: 'Jemand soll mir bei etwas helfen',   type: 'rescue',       category: 'general'  },
  { emoji: '🤝', title: 'Ich biete Hilfe an', desc: 'Ich möchte jemandem helfen',           type: 'help_offered', category: 'general'  },
  { emoji: '🎁', title: 'Ich teile etwas',    desc: 'Ich gebe etwas weiter oder tausche',  type: 'sharing',      category: 'everyday' },
  { emoji: '🔍', title: 'Ich suche etwas',    desc: 'Ich bin auf der Suche nach etwas',    type: 'rescue',       category: 'general'  },
]

// ── Progress indicator ────────────────────────────────────────────────────────

function StepIndicator({ step }: { step: number }) {
  return (
    <div className="flex items-center justify-center mb-8">
      {[1, 2, 3].map((n, i) => (
        <div key={n} className="flex items-center">
          <div className={cn(
            'w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold transition-all duration-300',
            step > n  ? 'bg-primary-500 text-white'                           :
            step === n ? 'bg-primary-500 text-white ring-4 ring-primary-100'  :
            'bg-stone-100 text-ink-400'
          )}>
            {step > n ? <CheckCircle2 className="w-4 h-4" /> : n}
          </div>
          {i < 2 && (
            <div className={cn(
              'w-12 h-0.5 mx-1 transition-all duration-300',
              step > n + 1 ? 'bg-primary-400' : step > n ? 'bg-primary-300' : 'bg-stone-200'
            )} />
          )}
        </div>
      ))}
    </div>
  )
}

// ── Animated step wrapper ─────────────────────────────────────────────────────

function StepWrap({ visible, children }: { visible: boolean; children: React.ReactNode }) {
  return (
    <div
      className="transition-all duration-300"
      style={{
        opacity: visible ? 1 : 0,
        transform: visible ? 'translateX(0)' : 'translateX(16px)',
        pointerEvents: visible ? 'auto' : 'none',
        position: visible ? 'static' : 'absolute',
      }}
    >
      {children}
    </div>
  )
}

// ── Main component ─────────────────────────────────────────────────────────────

export default function GuidedFirstPost({ userId }: { userId: string }) {
  const router = useRouter()
  const fileRef = useRef<HTMLInputElement>(null)

  const [step, setStep]                   = useState(1)
  const [selected, setSelected]           = useState<TypeOption | null>(null)
  const [title, setTitle]                 = useState('')
  const [description, setDescription]    = useState('')
  const [location, setLocation]           = useState('')
  const [lat, setLat]                     = useState<number | null>(null)
  const [lng, setLng]                     = useState<number | null>(null)
  const [geoLoading, setGeoLoading]       = useState(false)
  const [imageUrl, setImageUrl]           = useState<string | null>(null)
  const [imagePreview, setImagePreview]   = useState<string | null>(null)
  const [uploading, setUploading]         = useState(false)
  const [submitting, setSubmitting]       = useState(false)
  const [titleError, setTitleError]       = useState('')
  const [acceptedNoTrade, setAcceptedNoTrade] = useState(false)

  // Auto-request geo on step 2
  useEffect(() => {
    if (step !== 2 || lat !== null || typeof navigator === 'undefined') return
    setGeoLoading(true)
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        setLat(pos.coords.latitude)
        setLng(pos.coords.longitude)
        try {
          const res = await fetch(
            `https://nominatim.openstreetmap.org/reverse?lat=${pos.coords.latitude}&lon=${pos.coords.longitude}&format=json`,
            { headers: { 'Accept-Language': 'de' } }
          )
          const data = await res.json()
          const parts = (data.display_name as string ?? '').split(',')
          setLocation(parts.slice(0, 2).join(',').trim())
        } catch { /* no location text */ }
        setGeoLoading(false)
      },
      () => setGeoLoading(false),
      { enableHighAccuracy: false, timeout: 8000 }
    )
  }, [step]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Image upload ──────────────────────────────────────────────────────────
  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
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
      const { error } = await supabase.storage.from('post-images').upload(path, file, { upsert: false })
      if (error) { toast.error('Upload fehlgeschlagen'); setImagePreview(null); setUploading(false); return }
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

  // ── Submit ─────────────────────────────────────────────────────────────────
  const handleSubmit = async () => {
    if (!selected) return
    if (!acceptedNoTrade) {
      toast.error('Bitte bestätige, dass der Beitrag keinen kommerziellen Handel beinhaltet.')
      return
    }
    setSubmitting(true)
    const allowed = await checkRateLimit(userId, 'create_post', 2, 10)
    if (!allowed) { toast.error('Zu viele Beiträge in kurzer Zeit.'); setSubmitting(false); return }
    const supabase = createClient()
    const { error } = await supabase.from('posts').insert({
      user_id:       userId,
      type:          selected.type,
      category:      selected.category,
      title:         title.trim(),
      description:   description.trim() || 'Keine weiteren Details angegeben.',
      location_text: location.trim() || null,
      ...(lat !== null ? { latitude: lat }   : {}),
      ...(lng !== null ? { longitude: lng }  : {}),
      urgency:       'low',
      is_anonymous:  false,
      status:        'active',
      ...(imageUrl ? { media_urls: [imageUrl] } : {}),
    })
    setSubmitting(false)
    if (error) { toast.error('Fehler: ' + error.message); return }
    toast.success('Dein erster Beitrag! 🎉')
    router.push('/dashboard')
  }

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <div className="max-w-lg mx-auto">
      {/* Intro */}
      <div className="text-center mb-6">
        <h1 className="text-2xl font-bold text-ink-900">Dein erster Beitrag</h1>
        <p className="text-ink-500 text-sm mt-1">Nur 3 kurze Schritte – wir führen dich durch.</p>
      </div>

      <StepIndicator step={step} />

      <div className="bg-white rounded-2xl border border-stone-200 shadow-soft p-6 relative overflow-hidden">

        {/* ── Schritt 1: Was möchtest du tun? ── */}
        {step === 1 && (
          <StepWrap visible>
            <h2 className="text-xl font-bold text-ink-900 mb-1">Was möchtest du tun?</h2>
            <p className="text-sm text-ink-500 mb-5">Wähle aus, was am besten passt.</p>
            <div className="grid grid-cols-2 gap-3">
              {TYPE_OPTIONS.map((opt) => (
                <button
                  key={`${opt.type}-${opt.title}`}
                  onClick={() => {
                    setSelected(opt)
                    setStep(2)
                  }}
                  className={cn(
                    'rounded-2xl border p-5 text-left transition-all duration-200',
                    'hover:scale-[1.02] hover:shadow-lg hover:border-primary-300',
                    selected?.title === opt.title
                      ? 'bg-primary-50 border-primary-400 ring-2 ring-primary-200'
                      : 'bg-white border-stone-200'
                  )}
                >
                  <div className="text-3xl mb-2">{opt.emoji}</div>
                  <p className="font-semibold text-sm text-ink-900">{opt.title}</p>
                  <p className="text-xs text-ink-500 mt-1 leading-relaxed">{opt.desc}</p>
                </button>
              ))}
            </div>
          </StepWrap>
        )}

        {/* ── Schritt 2: Beschreibe kurz ── */}
        {step === 2 && (
          <StepWrap visible>
            <h2 className="text-xl font-bold text-ink-900 mb-1">Beschreibe kurz, worum es geht</h2>
            <p className="text-sm text-ink-500 mb-5">
              {selected?.emoji} <span className="font-medium text-ink-700">{selected?.title}</span>
            </p>

            {/* Titel */}
            <div className="space-y-1 mb-4">
              <label className="text-sm font-medium text-ink-700">Titel *</label>
              <input
                value={title}
                onChange={e => { setTitle(e.target.value); if (e.target.value.length >= 5) setTitleError('') }}
                placeholder="Kurze, klare Beschreibung"
                maxLength={80}
                autoFocus
                className={cn('input', titleError && 'border-red-400')}
              />
              <div className="flex justify-between">
                {titleError
                  ? <p className="text-xs text-red-500">{titleError}</p>
                  : <span />
                }
                <p className="text-xs text-ink-400">{title.length}/80</p>
              </div>
            </div>

            {/* Beschreibung */}
            <div className="space-y-1 mb-4">
              <label className="text-sm font-medium text-ink-700">
                Beschreibung <span className="font-normal text-ink-400">optional</span>
              </label>
              <textarea
                value={description}
                onChange={e => setDescription(e.target.value)}
                placeholder="Mehr Details helfen anderen zu verstehen, was du brauchst oder anbietest."
                rows={3}
                maxLength={2000}
                className="input resize-none"
              />
              <p className="text-xs text-ink-400 text-right">{description.length}/2000</p>
            </div>

            {/* Standort */}
            <div className="space-y-1 mb-6">
              <label className="text-sm font-medium text-ink-700 flex items-center gap-1.5">
                <MapPin className="w-3.5 h-3.5 text-ink-400" /> Standort
                <span className="font-normal text-ink-400">optional</span>
                {geoLoading && <Loader2 className="w-3 h-3 animate-spin text-primary-500 ml-1" />}
              </label>
              <input
                value={location}
                onChange={e => setLocation(e.target.value)}
                placeholder="z.B. Berlin Mitte, 55545 Bad Kreuznach"
                className="input"
              />
              {lat !== null && (
                <p className="text-xs text-green-600 flex items-center gap-1">
                  <MapPin className="w-3 h-3" /> GPS-Koordinaten gesetzt
                </p>
              )}
            </div>

            <div className="flex gap-3">
              <button
                onClick={() => setStep(1)}
                className="btn-secondary flex-1"
              >
                ← Zurück
              </button>
              <button
                onClick={() => {
                  if (title.trim().length < 5) { setTitleError('Mindestens 5 Zeichen erforderlich'); return }
                  setStep(3)
                }}
                className="btn-primary flex-1"
              >
                Weiter →
              </button>
            </div>
          </StepWrap>
        )}

        {/* ── Schritt 3: Foto + Veröffentlichen ── */}
        {step === 3 && (
          <StepWrap visible>
            <h2 className="text-xl font-bold text-ink-900 mb-1">Fast fertig! Noch ein Foto?</h2>
            <p className="text-sm text-ink-500 mb-5">Ein Bild sagt mehr als tausend Worte – ist aber optional.</p>

            {/* Bild-Upload */}
            <input ref={fileRef} type="file" accept="image/jpeg,image/png,image/webp,image/gif" onChange={handleImageUpload} className="hidden" />
            <div className="mb-5">
              {imagePreview ? (
                <div className="relative inline-block">
                  <img src={imagePreview} alt="Vorschau" className="h-28 w-28 object-cover rounded-xl border border-stone-200" />
                  {uploading && (
                    <div className="absolute inset-0 flex items-center justify-center bg-black/40 rounded-xl">
                      <Loader2 className="w-5 h-5 text-white animate-spin" />
                    </div>
                  )}
                  <button
                    onClick={() => { setImageUrl(null); setImagePreview(null); if (fileRef.current) fileRef.current.value = '' }}
                    className="absolute -top-2 -right-2 bg-white rounded-full p-0.5 shadow border border-stone-200"
                  >
                    <X className="w-3.5 h-3.5 text-ink-500" />
                  </button>
                </div>
              ) : (
                <button
                  onClick={() => fileRef.current?.click()}
                  className="flex items-center gap-2 px-4 py-3 text-sm text-ink-600 border-2 border-dashed border-stone-300 rounded-xl hover:bg-stone-50 hover:border-primary-300 transition w-full justify-center"
                >
                  <ImagePlus className="w-5 h-5 text-ink-400" />
                  Foto hinzufügen (optional, max. 10 MB)
                </button>
              )}
            </div>

            {/* Vorschau-Karte */}
            <div className="bg-stone-50 rounded-xl border border-stone-200 p-4 mb-5">
              <p className="text-xs font-semibold text-ink-400 uppercase tracking-wider mb-3">Vorschau</p>
              <div className="flex gap-3">
                {imagePreview && (
                  <img src={imagePreview} alt="" className="w-14 h-14 rounded-xl object-cover flex-shrink-0" />
                )}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-1.5 mb-1">
                    <span className="text-base">{selected?.emoji}</span>
                    <span className="text-xs font-medium text-primary-600 bg-primary-50 px-2 py-0.5 rounded-full">
                      {selected?.title}
                    </span>
                  </div>
                  <p className="font-semibold text-sm text-ink-900 truncate">{title}</p>
                  {description && (
                    <p className="text-xs text-ink-500 mt-0.5 line-clamp-2">{description}</p>
                  )}
                  {location && (
                    <p className="text-xs text-ink-400 mt-1 flex items-center gap-1">
                      <MapPin className="w-3 h-3" /> {location}
                    </p>
                  )}
                </div>
              </div>
            </div>

            {/* ── Kein-Handel-Bestätigung ── */}
            <div
              onClick={() => setAcceptedNoTrade(v => !v)}
              className={cn(
                'flex items-start gap-3 p-4 rounded-xl border cursor-pointer transition-all select-none mb-5',
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
                <p className="text-sm font-semibold text-ink-900">Kein Handel / kein Geldgeschäft *</p>
                <p className="text-xs text-ink-600 mt-0.5 leading-relaxed">
                  Ich bestätige, dass dieser Beitrag <strong>keinen kommerziellen Handel, Verkauf oder Geldgeschäfte</strong> beinhaltet.
                  Mensaena ist eine gemeinnützige Plattform für kostenlose Nachbarschaftshilfe.
                  Kommerzielle Angebote sind laut <a href="/nutzungsbedingungen" target="_blank" className="text-primary-600 underline">AGB §4</a> nicht erlaubt.
                </p>
              </div>
            </div>

            <div className="flex gap-3">
              <button onClick={() => setStep(2)} className="btn-secondary flex-1">← Zurück</button>
              <button
                onClick={handleSubmit}
                disabled={submitting || uploading || !acceptedNoTrade}
                className={cn(
                  'btn-primary flex-1 flex items-center justify-center gap-2',
                  (submitting || uploading || !acceptedNoTrade) && 'opacity-60 cursor-not-allowed'
                )}
              >
                {submitting
                  ? <><Loader2 className="w-4 h-4 animate-spin" /> Wird veröffentlicht…</>
                  : <><CheckCircle2 className="w-4 h-4" /> Veröffentlichen</>
                }
              </button>
            </div>
          </StepWrap>
        )}
      </div>
    </div>
  )
}
