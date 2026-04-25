'use client'

import { useState, useEffect, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { Plus, X, ImagePlus, ArrowLeft, Loader2, ShoppingBag, BookOpen } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { checkRateLimit } from '@/lib/rate-limit'
import BookLookup from '@/components/books/BookLookup'
import type { BookResult } from '@/lib/api/books'

const CATEGORIES = [
  { value: 'moebel',     label: '🛋️ Möbel' },
  { value: 'elektronik', label: '📱 Elektronik' },
  { value: 'kleidung',   label: '👗 Kleidung' },
  { value: 'sport',      label: '⚽ Sport & Freizeit' },
  { value: 'garten',     label: '🌱 Garten' },
  { value: 'kinder',     label: '🧸 Kinder' },
  { value: 'haushalt',   label: '🏠 Haushalt' },
  { value: 'buecher',    label: '📚 Bücher & Medien' },
  { value: 'handwerk',   label: '🔧 Werkzeug' },
  { value: 'sonstiges',  label: '📦 Sonstiges' },
]

const CONDITIONS = [
  { value: 'neu',        label: 'Neu' },
  { value: 'wie_neu',    label: 'Wie neu' },
  { value: 'gut',        label: 'Gut' },
  { value: 'akzeptabel', label: 'Akzeptabel' },
]

const PRICE_TYPES = [
  { value: 'fixed',      label: '💶 Festpreis' },
  { value: 'negotiable', label: '🤝 Verhandlungsbasis' },
  { value: 'free',       label: '🎁 Zu verschenken' },
  { value: 'swap',       label: '🔄 Tausch' },
]

const MAX_LISTING_IMAGES = 5

export default function CreateListingPage() {
  const router = useRouter()
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [category, setCategory] = useState('sonstiges')
  const [condition, setCondition] = useState('gut')
  const [priceType, setPriceType] = useState('negotiable')
  const [price, setPrice] = useState('')
  const [location, setLocation] = useState('')
  const [saving, setSaving] = useState(false)
  const [images, setImages] = useState<{ file: File; preview: string }[]>([])
  const [bookCoverUrl, setBookCoverUrl] = useState<string | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => () => {
    images.forEach(img => URL.revokeObjectURL(img.preview))
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // ── Book auto-fill ──────────────────────────────────────────────────────────
  const handleBookSelect = (book: BookResult) => {
    setTitle(book.title)

    const parts: string[] = []
    if (book.authors.length > 0) parts.push(`von ${book.authors.join(', ')}`)
    if (book.publishYear)        parts.push(`Erschienen: ${book.publishYear}`)
    if (book.publisher)          parts.push(`Verlag: ${book.publisher}`)
    if (book.pageCount)          parts.push(`${book.pageCount} Seiten`)
    if (book.isbn)               parts.push(`ISBN: ${book.isbn}`)
    setDescription(parts.join('\n'))

    if (book.coverUrl) setBookCoverUrl(book.coverUrl)

    toast.success('Buchinfos übernommen!')
  }

  // ── Image handling ──────────────────────────────────────────────────────────
  const handleFilesSelected = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files ?? [])
    if (!files.length) return
    const remaining = MAX_LISTING_IMAGES - images.length
    if (remaining <= 0) { toast.error(`Max. ${MAX_LISTING_IMAGES} Bilder pro Anzeige`); return }
    const accepted = files.slice(0, remaining).filter(f => {
      if (!f.type.startsWith('image/')) { toast.error(`${f.name}: Kein Bild`); return false }
      if (f.size > 10 * 1024 * 1024) { toast.error(`${f.name}: zu groß (max 10MB)`); return false }
      return true
    })
    if (files.length > remaining) toast.error(`Nur ${remaining} weitere Bilder möglich`)
    setImages(prev => [...prev, ...accepted.map(file => ({ file, preview: URL.createObjectURL(file) }))])
    if (fileInputRef.current) fileInputRef.current.value = ''
  }

  const removeImage = (idx: number) => {
    setImages(prev => {
      const next = [...prev]
      const [removed] = next.splice(idx, 1)
      if (removed) URL.revokeObjectURL(removed.preview)
      return next
    })
  }

  // ── Submit ──────────────────────────────────────────────────────────────────
  const handleCreate = async () => {
    if (title.trim().length < 3) { toast.error('Titel mindestens 3 Zeichen'); return }
    if (description.trim().length > 1000) { toast.error('Beschreibung max. 1000 Zeichen'); return }
    setSaving(true)
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { toast.error('Bitte einloggen'); setSaving(false); return }

      const allowed = await checkRateLimit(user.id, 'create_listing', 3, 60)
      if (!allowed) { toast.error('Zu viele Anzeigen in kurzer Zeit. Bitte warte etwas.'); setSaving(false); return }

      const uploadedUrls: string[] = []

      // Include Open Library cover as first image if available and no photos uploaded
      if (bookCoverUrl && images.length === 0) {
        uploadedUrls.push(bookCoverUrl)
      }

      if (images.length > 0) {
        const buckets = ['chat-images', 'avatars'] as const
        for (const img of images) {
          const ext = (img.file.name.split('.').pop() || 'jpg').toLowerCase()
          const uniqueName = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${ext}`
          const filePath = `marketplace/${user.id}/${uniqueName}`
          let publicUrl: string | null = null
          for (const bucket of buckets) {
            const { error: upErr } = await supabase.storage
              .from(bucket)
              .upload(filePath, img.file, { upsert: false, contentType: img.file.type || 'image/jpeg' })
            if (!upErr) {
              publicUrl = supabase.storage.from(bucket).getPublicUrl(filePath).data.publicUrl
              break
            }
          }
          if (!publicUrl) {
            toast.error(`Bild-Upload fehlgeschlagen: ${img.file.name}`)
            setSaving(false)
            return
          }
          uploadedUrls.push(publicUrl)
        }

        // Prepend book cover to uploaded photos so it's available as fallback
        if (bookCoverUrl) uploadedUrls.unshift(bookCoverUrl)
      }

      const priceVal = priceType === 'free' ? 0 : (parseFloat(price) || null)

      const insertData: Record<string, unknown> = {
        title: title.trim(),
        description: description.trim() || null,
        category,
        condition,
        condition_state: condition,
        listing_type: priceType,
        price_type: priceType,
        price: priceVal,
        location_text: location.trim() || null,
        user_id: user.id,
        seller_id: user.id,
        images: uploadedUrls,
        image_urls: uploadedUrls,
        status: 'active',
      }

      let result = await supabase.from('marketplace_listings').insert(insertData)

      for (let attempt = 0; attempt < 5 && result.error?.message?.includes('column'); attempt++) {
        const colMatch = result.error.message.match(/column\s+["']?(\w+)["']?.*does not exist/i)
          || result.error.message.match(/Could not find.*column\s+["']?(\w+)["']?/i)
        if (!colMatch) break
        delete insertData[colMatch[1]]
        result = await supabase.from('marketplace_listings').insert(insertData)
      }

      if (result.error) throw result.error
      toast.success('Anzeige erstellt!')
      router.push('/dashboard/marketplace')
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : ''
      toast.error('Fehler beim Erstellen: ' + msg)
    } finally {
      setSaving(false)
    }
  }

  const isBookCategory = category === 'buecher'

  return (
    <div className="max-w-lg mx-auto px-4 py-6">
      <button
        onClick={() => router.back()}
        className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-800 transition-colors mb-6"
      >
        <ArrowLeft className="w-4 h-4" />
        Zurück zum Marktplatz
      </button>

      <div className="bg-white rounded-2xl border border-gray-100 shadow-soft overflow-hidden">
        <div className="flex items-center gap-3 px-6 py-5 border-b border-gray-100">
          <div className="w-9 h-9 rounded-xl bg-primary-100 flex items-center justify-center flex-shrink-0">
            <ShoppingBag className="w-5 h-5 text-primary-600" />
          </div>
          <div>
            <h1 className="text-base font-semibold text-gray-900">Neue Anzeige</h1>
            <p className="text-xs text-gray-400 mt-0.5">Kaufen · Verkaufen · Tauschen · Verschenken</p>
          </div>
        </div>

        <div className="p-6 space-y-4">

          {/* Category first so BookLookup appears contextually */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Kategorie</label>
              <select
                value={category}
                onChange={e => { setCategory(e.target.value); setBookCoverUrl(null) }}
                className="input"
              >
                {CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
            </div>
            <div>
              <label className="label">Zustand</label>
              <select value={condition} onChange={e => setCondition(e.target.value)} className="input">
                {CONDITIONS.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
            </div>
          </div>

          {/* BookLookup: only visible for books category */}
          {isBookCategory && (
            <div>
              <label className="label flex items-center gap-1.5">
                <BookOpen className="w-3.5 h-3.5 text-primary-500" />
                Buchinfo laden (optional)
              </label>
              <BookLookup
                onBookSelect={handleBookSelect}
                className="mt-1"
              />
            </div>
          )}

          <div>
            <label className="label">Titel *</label>
            <input
              value={title}
              onChange={e => setTitle(e.target.value)}
              maxLength={80}
              className="input"
              placeholder={isBookCategory ? 'Buchtitel' : 'Was bietest du an?'}
              autoFocus={!isBookCategory}
            />
          </div>

          <div>
            <label className="label">Beschreibung</label>
            <textarea
              value={description}
              onChange={e => setDescription(e.target.value)}
              rows={3}
              maxLength={1000}
              className="input resize-none"
              placeholder={isBookCategory
                ? 'Autor, Zustand, Besonderheiten…'
                : 'Details zum Artikel…'
              }
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Preisart</label>
              <select value={priceType} onChange={e => setPriceType(e.target.value)} className="input">
                {PRICE_TYPES.map(p => <option key={p.value} value={p.value}>{p.label}</option>)}
              </select>
            </div>
            {priceType !== 'free' && priceType !== 'swap' && (
              <div>
                <label className="label">Preis (€)</label>
                <input
                  type="number"
                  value={price}
                  onChange={e => setPrice(e.target.value)}
                  min="0"
                  step="0.5"
                  className="input"
                  placeholder="0.00"
                />
              </div>
            )}
          </div>

          <div>
            <label className="label">Standort</label>
            <input
              value={location}
              onChange={e => setLocation(e.target.value)}
              className="input"
              placeholder="z.B. Berlin-Mitte"
            />
          </div>

          {/* Images */}
          <div>
            <label className="label flex items-center justify-between">
              <span>Bilder ({images.length}/{MAX_LISTING_IMAGES})</span>
              <span className="text-[11px] font-normal text-gray-400">optional · max 10MB/Bild</span>
            </label>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              multiple
              onChange={handleFilesSelected}
              className="hidden"
            />
            <div className="grid grid-cols-5 gap-2">
              {/* Book cover preview from Open Library */}
              {bookCoverUrl && images.length === 0 && (
                <div className="relative aspect-square rounded-xl overflow-hidden border border-primary-200 group">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={bookCoverUrl} alt="Buchcover" className="w-full h-full object-cover" />
                  <button
                    type="button"
                    onClick={() => setBookCoverUrl(null)}
                    className="absolute top-1 right-1 w-5 h-5 rounded-full bg-black/60 text-white flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
                    aria-label="Cover entfernen"
                  >
                    <X className="w-3 h-3" />
                  </button>
                  <span className="absolute bottom-1 left-1 text-[9px] font-bold px-1.5 py-0.5 rounded-full bg-white/90 text-primary-700">
                    Cover
                  </span>
                </div>
              )}

              {images.map((img, idx) => (
                <div key={idx} className="relative aspect-square rounded-xl overflow-hidden border border-stone-200 group">
                  <img src={img.preview} alt="" className="w-full h-full object-cover" />
                  <button
                    type="button"
                    onClick={() => removeImage(idx)}
                    className="absolute top-1 right-1 w-5 h-5 rounded-full bg-black/60 text-white flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
                    aria-label="Bild entfernen"
                  >
                    <X className="w-3 h-3" />
                  </button>
                  {idx === 0 && (
                    <span className="absolute bottom-1 left-1 text-[9px] font-bold px-1.5 py-0.5 rounded-full bg-white/90 text-orange-700">
                      Cover
                    </span>
                  )}
                </div>
              ))}

              {images.length < MAX_LISTING_IMAGES && (
                <button
                  type="button"
                  onClick={() => fileInputRef.current?.click()}
                  className="aspect-square rounded-xl border-2 border-dashed border-stone-300 flex flex-col items-center justify-center gap-1 text-stone-400 hover:text-primary-600 hover:border-primary-400 hover:bg-primary-50/50 transition-all"
                >
                  <ImagePlus className="w-5 h-5" />
                  <span className="text-[10px] font-medium">Bild</span>
                </button>
              )}
            </div>
          </div>

          <button
            onClick={handleCreate}
            disabled={saving || title.trim().length < 3}
            className="btn-primary w-full disabled:opacity-50 disabled:pointer-events-none"
          >
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Plus className="w-4 h-4" />}
            Anzeige erstellen
          </button>
        </div>
      </div>
    </div>
  )
}
