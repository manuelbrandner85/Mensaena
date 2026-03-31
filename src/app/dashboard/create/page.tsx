'use client'

import { useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { MapPin, ImagePlus, ChevronDown, AlertCircle, X } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'

const postTypes = [
  { value: 'help_needed',  label: '🆘 Hilfe suchen',       desc: 'Ich brauche Unterstützung' },
  { value: 'help_offered', label: '🤝 Hilfe anbieten',      desc: 'Ich kann helfen' },
  { value: 'rescue',       label: '📦 Retter-Angebot',      desc: 'Lebensmittel / Ressourcen retten' },
  { value: 'animal',       label: '🐾 Tierhilfe',           desc: 'Tier sucht Hilfe oder ein Zuhause' },
  { value: 'housing',      label: '🏡 Wohnangebot',         desc: 'Wohnung / Unterkunft anbieten' },
  { value: 'supply',       label: '🌾 Versorgung',          desc: 'Regionale Produkte oder Ernte' },
  { value: 'mobility',     label: '🚗 Mobilität',           desc: 'Mitfahrgelegenheit / Transport' },
  { value: 'sharing',      label: '🔄 Teilen & Tauschen',   desc: 'Tauschen oder verschenken' },
  { value: 'community',    label: '📢 Community',           desc: 'Ankündigung oder Abstimmung' },
  { value: 'crisis',       label: '🚨 Notfall',             desc: 'Dringende Hilfe benötigt' },
]

const categories = [
  'Essen', 'Alltag', 'Umzug', 'Tiere', 'Wohnen',
  'Bildung', 'Gesundheit', 'Mobilität', 'Kleidung', 'Sonstiges',
]

const urgencyOptions = [
  { value: 'low',      label: '🟢 Niedrig',  desc: 'Kein Zeitdruck' },
  { value: 'medium',   label: '🟡 Mittel',   desc: 'Bald' },
  { value: 'high',     label: '🟠 Hoch',     desc: 'Bitte bald melden' },
  { value: 'critical', label: '🔴 Kritisch', desc: 'Sofort benötigt' },
]

export default function CreatePostPage() {
  const router = useRouter()
  const fileInputRef = useRef<HTMLInputElement>(null)

  const [type, setType] = useState('')
  const [category, setCategory] = useState('Sonstiges')
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [urgency, setUrgency] = useState('medium')
  const [contactPhone, setContactPhone] = useState('')
  const [contactWhatsapp, setContactWhatsapp] = useState('')
  const [contactEmail, setContactEmail] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [useLocation, setUseLocation] = useState(false)
  const [coords, setCoords] = useState<{ lat: number; lng: number } | null>(null)

  // Bilder-Upload State
  const [images, setImages] = useState<{ file: File; preview: string }[]>([])
  const [uploadingImages, setUploadingImages] = useState(false)

  const handleGetLocation = () => {
    if (!navigator.geolocation) return
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setCoords({ lat: pos.coords.latitude, lng: pos.coords.longitude })
        setUseLocation(true)
        toast.success('Standort ermittelt 📍')
      },
      () => toast.error('Standort konnte nicht ermittelt werden')
    )
  }

  const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || [])
    if (images.length + files.length > 4) {
      toast.error('Maximal 4 Bilder erlaubt')
      return
    }
    const newImages = files
      .filter(f => f.size <= 10 * 1024 * 1024)
      .map(file => ({ file, preview: URL.createObjectURL(file) }))

    if (newImages.length < files.length) {
      toast.error('Einige Bilder überschreiten 10 MB und wurden übersprungen')
    }
    setImages(prev => [...prev, ...newImages])
    // Input zurücksetzen für erneute Auswahl
    if (fileInputRef.current) fileInputRef.current.value = ''
  }

  const removeImage = (idx: number) => {
    setImages(prev => {
      URL.revokeObjectURL(prev[idx].preview)
      return prev.filter((_, i) => i !== idx)
    })
  }

  const uploadImages = async (userId: string): Promise<string[]> => {
    if (images.length === 0) return []
    const supabase = createClient()
    const urls: string[] = []

    for (const img of images) {
      const ext = img.file.name.split('.').pop()
      const path = `${userId}/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`
      const { error } = await supabase.storage
        .from('post-images')
        .upload(path, img.file, { upsert: false })

      if (!error) {
        const { data } = supabase.storage.from('post-images').getPublicUrl(path)
        urls.push(data.publicUrl)
      }
    }
    return urls
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')

    if (!type)                          { setError('Bitte wähle einen Beitragstyp.');              return }
    if (title.trim().length < 5)        { setError('Titel muss mindestens 5 Zeichen haben.');      return }
    if (description.trim().length < 20) { setError('Beschreibung muss mindestens 20 Zeichen.');    return }

    setLoading(true)
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { router.replace('/login'); setLoading(false); return }

    // Bilder hochladen
    setUploadingImages(true)
    const imageUrls = await uploadImages(user.id)
    setUploadingImages(false)

    const { error: insertError } = await supabase.from('posts').insert({
      user_id:           user.id,
      type,
      category:          category.toLowerCase(),
      title:             title.trim(),
      description:       description.trim(),
      urgency,
      image_urls:        imageUrls.length > 0 ? imageUrls : null,
      contact_phone:     contactPhone    || null,
      contact_whatsapp:  contactWhatsapp || null,
      contact_email:     contactEmail    || null,
      latitude:          coords?.lat     || null,
      longitude:         coords?.lng     || null,
      status:            'active',
    })

    if (insertError) {
      setError(insertError.message)
      setLoading(false)
      return
    }

    toast.success('Beitrag erfolgreich veröffentlicht! 🎉')
    router.push('/dashboard/posts')
  }

  return (
    <div className="max-w-2xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Beitrag erstellen</h1>
        <p className="text-sm text-gray-600 mt-1">Teile dein Anliegen mit der Community</p>
      </div>

      {error && (
        <div className="flex items-start gap-3 p-4 bg-red-50 border border-red-200 rounded-xl mb-6 text-sm text-red-700">
          <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-6">

        {/* ── 1. Beitragstyp ── */}
        <div className="card p-5">
          <h2 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
            <span className="w-6 h-6 bg-primary-600 text-white rounded-full text-xs flex items-center justify-center font-bold">1</span>
            Beitragstyp wählen
          </h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
            {postTypes.map((pt) => (
              <button
                key={pt.value}
                type="button"
                onClick={() => setType(pt.value)}
                className={`p-3 rounded-xl border text-left transition-all duration-150 hover:-translate-y-0.5
                  ${type === pt.value
                    ? 'bg-primary-50 border-primary-400 ring-2 ring-primary-300'
                    : 'bg-white border-warm-200 hover:border-primary-300 hover:bg-primary-50/50'
                  }`}
              >
                <div className="text-sm font-medium text-gray-900">{pt.label}</div>
                <div className="text-xs text-gray-500 mt-0.5">{pt.desc}</div>
              </button>
            ))}
          </div>
        </div>

        {/* ── 2. Inhalt ── */}
        <div className="card p-5">
          <h2 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
            <span className="w-6 h-6 bg-primary-600 text-white rounded-full text-xs flex items-center justify-center font-bold">2</span>
            Beitrag beschreiben
          </h2>
          <div className="space-y-4">
            <div>
              <label className="label">Titel <span className="text-red-500">*</span></label>
              <input
                type="text" value={title} onChange={(e) => setTitle(e.target.value)}
                placeholder="Kurzer, prägnanter Titel…" maxLength={120} required className="input"
              />
              <p className="text-xs text-gray-400 mt-1">{title.length}/120 Zeichen</p>
            </div>
            <div>
              <label className="label">Beschreibung <span className="text-red-500">*</span></label>
              <textarea
                value={description} onChange={(e) => setDescription(e.target.value)}
                placeholder="Beschreibe deinen Beitrag ausführlich…"
                rows={5} required className="input resize-none"
              />
              <p className="text-xs text-gray-400 mt-1">{description.length} Zeichen (min. 20)</p>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="label">Kategorie</label>
                <div className="relative">
                  <select value={category} onChange={(e) => setCategory(e.target.value)} className="input appearance-none pr-8 cursor-pointer">
                    {categories.map((c) => <option key={c} value={c}>{c}</option>)}
                  </select>
                  <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" />
                </div>
              </div>
              <div>
                <label className="label">Dringlichkeit</label>
                <div className="relative">
                  <select value={urgency} onChange={(e) => setUrgency(e.target.value)} className="input appearance-none pr-8 cursor-pointer">
                    {urgencyOptions.map((u) => <option key={u.value} value={u.value}>{u.label}</option>)}
                  </select>
                  <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" />
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* ── 3. Bilder ── */}
        <div className="card p-5">
          <h2 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
            <span className="w-6 h-6 bg-primary-600 text-white rounded-full text-xs flex items-center justify-center font-bold">3</span>
            Bilder hinzufügen
            <span className="ml-auto text-xs text-gray-400 font-normal">{images.length}/4</span>
          </h2>

          {/* Vorschau-Grid */}
          {images.length > 0 && (
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-4">
              {images.map((img, idx) => (
                <div key={idx} className="relative group aspect-square rounded-xl overflow-hidden border-2 border-warm-200">
                  <img src={img.preview} alt="" className="w-full h-full object-cover" />
                  <button
                    type="button"
                    onClick={() => removeImage(idx)}
                    className="absolute top-1 right-1 w-6 h-6 bg-red-500 text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity shadow-md"
                  >
                    <X className="w-3.5 h-3.5" />
                  </button>
                  {idx === 0 && (
                    <div className="absolute bottom-0 left-0 right-0 bg-primary-600/80 text-white text-[10px] text-center py-0.5 font-medium">
                      Titelbild
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}

          {/* Upload-Button */}
          {images.length < 4 && (
            <button
              type="button"
              onClick={() => fileInputRef.current?.click()}
              className="w-full flex flex-col items-center justify-center gap-2 py-8 border-2 border-dashed border-warm-300 rounded-xl text-gray-500 hover:border-primary-400 hover:bg-primary-50/30 transition-all"
            >
              <ImagePlus className="w-7 h-7 text-gray-400" />
              <span className="text-sm font-medium">Bilder auswählen</span>
              <span className="text-xs text-gray-400">JPG, PNG, WebP – max. 10 MB pro Bild</span>
            </button>
          )}
          <input
            ref={fileInputRef}
            type="file"
            accept="image/jpeg,image/png,image/webp"
            multiple
            className="hidden"
            onChange={handleImageSelect}
          />
        </div>

        {/* ── 4. Standort ── */}
        <div className="card p-5">
          <h2 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
            <span className="w-6 h-6 bg-primary-600 text-white rounded-full text-xs flex items-center justify-center font-bold">4</span>
            Standort <span className="text-xs text-gray-400 font-normal ml-1">(optional)</span>
          </h2>
          <button
            type="button"
            onClick={handleGetLocation}
            className={`flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium border transition-all
              ${useLocation
                ? 'bg-primary-100 text-primary-700 border-primary-300'
                : 'bg-white text-gray-600 border-warm-200 hover:bg-warm-50'
              }`}
          >
            <MapPin className="w-4 h-4" />
            {useLocation ? `📍 ${coords?.lat.toFixed(4)}, ${coords?.lng.toFixed(4)}` : 'Standort ermitteln'}
          </button>
          <p className="text-xs text-gray-500 mt-2">Mit Standort erscheint dein Beitrag auf der Karte.</p>
        </div>

        {/* ── 5. Kontakt ── */}
        <div className="card p-5">
          <h2 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
            <span className="w-6 h-6 bg-primary-600 text-white rounded-full text-xs flex items-center justify-center font-bold">5</span>
            Kontakt <span className="text-xs text-gray-400 font-normal ml-1">(optional)</span>
          </h2>
          <div className="space-y-3">
            <input type="tel"   value={contactPhone}     onChange={(e) => setContactPhone(e.target.value)}     placeholder="📞 Telefonnummer"  className="input" />
            <input type="tel"   value={contactWhatsapp}  onChange={(e) => setContactWhatsapp(e.target.value)}  placeholder="💬 WhatsApp-Nummer" className="input" />
            <input type="email" value={contactEmail}     onChange={(e) => setContactEmail(e.target.value)}     placeholder="✉️ E-Mail-Adresse" className="input" />
          </div>
        </div>

        {/* ── Submit ── */}
        <div className="flex items-center gap-3 pt-2">
          <button
            type="submit"
            disabled={loading}
            className="btn-primary flex-1 justify-center py-4 text-base"
          >
            {loading ? (
              <>
                <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                {uploadingImages ? 'Bilder werden hochgeladen…' : 'Wird erstellt…'}
              </>
            ) : (
              '✓ Beitrag veröffentlichen'
            )}
          </button>
          <button type="button" onClick={() => router.back()} className="btn-secondary px-6 py-4">
            Abbrechen
          </button>
        </div>
      </form>
    </div>
  )
}
