'use client'

import { useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { MapPin, ImagePlus, ChevronDown, AlertCircle, X, Upload } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'

const postTypes = [
  { value: 'help_needed', label: '🆘 Hilfe suchen', desc: 'Ich brauche Unterstützung' },
  { value: 'help_offered', label: '🤝 Hilfe anbieten', desc: 'Ich kann helfen' },
  { value: 'rescue', label: '📦 Retter-Angebot', desc: 'Lebensmittel / Ressourcen retten' },
  { value: 'animal', label: '🐾 Tierhilfe', desc: 'Tier sucht Hilfe oder ein Zuhause' },
  { value: 'housing', label: '🏡 Wohnangebot', desc: 'Wohnung / Unterkunft anbieten' },
  { value: 'supply', label: '🌾 Versorgung', desc: 'Regionale Produkte oder Ernte' },
  { value: 'mobility', label: '🚗 Mobilität', desc: 'Mitfahrgelegenheit / Transport' },
  { value: 'sharing', label: '🔄 Teilen & Tauschen', desc: 'Tauschen oder verschenken' },
  { value: 'community', label: '📢 Community', desc: 'Ankündigung oder Abstimmung' },
  { value: 'crisis', label: '🚨 Notfall', desc: 'Dringende Hilfe benötigt' },
]

const categories = [
  'Essen', 'Alltag', 'Umzug', 'Tiere', 'Wohnen',
  'Bildung', 'Gesundheit', 'Mobilität', 'Kleidung', 'Sonstiges',
]

const urgencyOptions = [
  { value: 'low', label: '🟢 Niedrig', desc: 'Kein Zeitdruck' },
  { value: 'medium', label: '🟡 Mittel', desc: 'Bald' },
  { value: 'high', label: '🟠 Hoch', desc: 'Bitte bald melden' },
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

  // Bild-Upload State
  const [imageFiles, setImageFiles] = useState<File[]>([])
  const [imagePreviews, setImagePreviews] = useState<string[]>([])
  const [uploadingImages, setUploadingImages] = useState(false)

  const handleGetLocation = () => {
    if (!navigator.geolocation) return
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setCoords({ lat: pos.coords.latitude, lng: pos.coords.longitude })
        setUseLocation(true)
        toast.success('Standort ermittelt')
      },
      () => toast.error('Standort konnte nicht ermittelt werden')
    )
  }

  const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || [])
    if (files.length + imageFiles.length > 4) {
      toast.error('Maximal 4 Bilder erlaubt')
      return
    }
    const validFiles = files.filter(f => {
      if (f.size > 10 * 1024 * 1024) { toast.error(`${f.name} ist zu groß (max. 10MB)`); return false }
      return true
    })
    setImageFiles(prev => [...prev, ...validFiles])
    validFiles.forEach(file => {
      const reader = new FileReader()
      reader.onloadend = () => setImagePreviews(prev => [...prev, reader.result as string])
      reader.readAsDataURL(file)
    })
  }

  const removeImage = (index: number) => {
    setImageFiles(prev => prev.filter((_, i) => i !== index))
    setImagePreviews(prev => prev.filter((_, i) => i !== index))
  }

  const uploadImages = async (userId: string): Promise<string[]> => {
    if (imageFiles.length === 0) return []
    setUploadingImages(true)
    const supabase = createClient()
    const urls: string[] = []

    for (const file of imageFiles) {
      const ext = file.name.split('.').pop()
      const path = `${userId}/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`
      const { error } = await supabase.storage.from('post-images').upload(path, file)
      if (!error) {
        const { data } = supabase.storage.from('post-images').getPublicUrl(path)
        urls.push(data.publicUrl)
      }
    }
    setUploadingImages(false)
    return urls
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')

    if (!type) { setError('Bitte wähle einen Beitragstyp.'); return }
    if (title.trim().length < 5) { setError('Titel muss mindestens 5 Zeichen haben.'); return }
    if (description.trim().length < 20) { setError('Beschreibung muss mindestens 20 Zeichen haben.'); return }

    setLoading(true)
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()

    if (!user) { setError('Nicht eingeloggt.'); setLoading(false); return }

    // Bilder hochladen
    const imageUrls = await uploadImages(user.id)

    const { error: insertError } = await supabase.from('posts').insert({
      user_id: user.id,
      type,
      category: category.toLowerCase(),
      title: title.trim(),
      description: description.trim(),
      urgency,
      contact_phone: contactPhone || null,
      contact_whatsapp: contactWhatsapp || null,
      contact_email: contactEmail || null,
      latitude: coords?.lat || null,
      longitude: coords?.lng || null,
      image_urls: imageUrls.length > 0 ? imageUrls : null,
      status: 'active',
    })

    if (insertError) {
      setError(insertError.message)
      setLoading(false)
      return
    }

    toast.success('Beitrag erfolgreich erstellt! 🎉')
    router.push('/dashboard')
  }

  return (
    <div className="max-w-2xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Beitrag erstellen</h1>
        <p className="text-sm text-gray-600 mt-1">Erstelle einen neuen Beitrag für die Community</p>
      </div>

      {error && (
        <div className="flex items-start gap-3 p-4 bg-red-50 border border-red-200 rounded-xl mb-6 text-sm text-red-700">
          <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Post Type */}
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

        {/* Content */}
        <div className="card p-5">
          <h2 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
            <span className="w-6 h-6 bg-primary-600 text-white rounded-full text-xs flex items-center justify-center font-bold">2</span>
            Beitrag beschreiben
          </h2>
          <div className="space-y-4">
            <div>
              <label className="label">Titel <span className="text-red-500">*</span></label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Kurzer, prägnanter Titel…"
                maxLength={120}
                required
                className="input"
              />
              <p className="text-xs text-gray-400 mt-1">{title.length}/120 Zeichen</p>
            </div>

            <div>
              <label className="label">Beschreibung <span className="text-red-500">*</span></label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Beschreibe deinen Beitrag ausführlich…"
                rows={5}
                required
                className="input resize-none"
              />
              <p className="text-xs text-gray-400 mt-1">{description.length} Zeichen (min. 20)</p>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="label">Kategorie</label>
                <div className="relative">
                  <select
                    value={category}
                    onChange={(e) => setCategory(e.target.value)}
                    className="input appearance-none pr-8 cursor-pointer"
                  >
                    {categories.map((c) => (
                      <option key={c} value={c}>{c}</option>
                    ))}
                  </select>
                  <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" />
                </div>
              </div>
              <div>
                <label className="label">Dringlichkeit</label>
                <div className="relative">
                  <select
                    value={urgency}
                    onChange={(e) => setUrgency(e.target.value)}
                    className="input appearance-none pr-8 cursor-pointer"
                  >
                    {urgencyOptions.map((u) => (
                      <option key={u.value} value={u.value}>{u.label}</option>
                    ))}
                  </select>
                  <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" />
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Bilder Upload */}
        <div className="card p-5">
          <h2 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
            <span className="w-6 h-6 bg-primary-600 text-white rounded-full text-xs flex items-center justify-center font-bold">3</span>
            Bilder hinzufügen (optional)
          </h2>

          {/* Vorschauen */}
          {imagePreviews.length > 0 && (
            <div className="grid grid-cols-2 gap-3 mb-4">
              {imagePreviews.map((preview, i) => (
                <div key={i} className="relative aspect-video rounded-xl overflow-hidden bg-warm-50 border border-warm-200">
                  <img src={preview} alt={`Vorschau ${i + 1}`} className="w-full h-full object-cover" />
                  <button
                    type="button"
                    onClick={() => removeImage(i)}
                    className="absolute top-2 right-2 w-6 h-6 bg-red-500 text-white rounded-full flex items-center justify-center hover:bg-red-600 transition-colors shadow-md"
                  >
                    <X className="w-3.5 h-3.5" />
                  </button>
                </div>
              ))}
            </div>
          )}

          {imageFiles.length < 4 && (
            <button
              type="button"
              onClick={() => fileInputRef.current?.click()}
              className="w-full border-2 border-dashed border-warm-300 rounded-xl p-6 flex flex-col items-center justify-center gap-2 text-gray-500 hover:border-primary-400 hover:bg-primary-50/50 transition-all"
            >
              <div className="w-10 h-10 bg-warm-100 rounded-full flex items-center justify-center">
                {uploadingImages
                  ? <div className="w-5 h-5 border-2 border-primary-400 border-t-transparent rounded-full animate-spin" />
                  : <ImagePlus className="w-5 h-5 text-gray-500" />
                }
              </div>
              <div className="text-center">
                <p className="text-sm font-medium">Bild hinzufügen</p>
                <p className="text-xs text-gray-400">JPG, PNG, WebP · max. 10 MB · bis zu 4 Bilder</p>
              </div>
              <div className="flex items-center gap-2 text-xs text-primary-600 font-medium">
                <Upload className="w-3.5 h-3.5" />
                Datei auswählen
              </div>
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
          <p className="text-xs text-gray-400 mt-2">
            {imageFiles.length}/4 Bilder ausgewählt
          </p>
        </div>

        {/* Location */}
        <div className="card p-5">
          <h2 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
            <span className="w-6 h-6 bg-primary-600 text-white rounded-full text-xs flex items-center justify-center font-bold">4</span>
            Standort (optional)
          </h2>
          <div className="flex items-center gap-3">
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
              {useLocation ? `📍 ${coords?.lat.toFixed(4)}, ${coords?.lng.toFixed(4)}` : 'Standort automatisch ermitteln'}
            </button>
          </div>
          <p className="text-xs text-gray-500 mt-2">
            Mit Standort erscheint dein Beitrag auf der interaktiven Karte.
          </p>
        </div>

        {/* Contact */}
        <div className="card p-5">
          <h2 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
            <span className="w-6 h-6 bg-primary-600 text-white rounded-full text-xs flex items-center justify-center font-bold">5</span>
            Kontakt (optional)
          </h2>
          <div className="space-y-3">
            <input type="tel" value={contactPhone} onChange={(e) => setContactPhone(e.target.value)}
              placeholder="📞 Telefonnummer" className="input" />
            <input type="tel" value={contactWhatsapp} onChange={(e) => setContactWhatsapp(e.target.value)}
              placeholder="💬 WhatsApp-Nummer" className="input" />
            <input type="email" value={contactEmail} onChange={(e) => setContactEmail(e.target.value)}
              placeholder="✉️ E-Mail-Adresse" className="input" />
          </div>
        </div>

        {/* Submit */}
        <div className="flex items-center gap-3 pt-2">
          <button
            type="submit"
            disabled={loading || uploadingImages}
            className="btn-primary flex-1 justify-center py-4 text-base"
          >
            {loading || uploadingImages ? (
              <>
                <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                {uploadingImages ? 'Bilder werden hochgeladen…' : 'Wird erstellt…'}
              </>
            ) : (
              '✓ Beitrag veröffentlichen'
            )}
          </button>
          <button
            type="button"
            onClick={() => router.back()}
            className="btn-secondary px-6 py-4"
          >
            Abbrechen
          </button>
        </div>
      </form>
    </div>
  )
}
