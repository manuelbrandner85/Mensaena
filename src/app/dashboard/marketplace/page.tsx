'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import {
  ShoppingBag, Plus, Search, X, MapPin, Loader2,
  Clock, CheckCircle2, ImagePlus, ChevronLeft, ChevronRight,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import toast from 'react-hot-toast'
import { checkRateLimit } from '@/lib/rate-limit'
import MarketplaceReservation from '@/components/features/MarketplaceReservation'

// ── Types ──────────────────────────────────────────────────────
interface Listing {
  id: string
  title: string
  description: string | null
  price: number | null
  price_type?: string
  listing_type?: string
  category: string
  condition?: string | null
  condition_state?: string | null
  image_urls?: string[]
  images?: string[]
  location_text: string | null
  status: string
  created_at: string
  seller_id?: string
  user_id?: string
  seller_name?: string
  reserved_for?: string | null
}

// ── Config ─────────────────────────────────────────────────────
const CATEGORIES = [
  { value: 'moebel', label: '🛋️ Möbel' },
  { value: 'elektronik', label: '📱 Elektronik' },
  { value: 'kleidung', label: '👗 Kleidung' },
  { value: 'sport', label: '⚽ Sport & Freizeit' },
  { value: 'garten', label: '🌱 Garten' },
  { value: 'kinder', label: '🧸 Kinder' },
  { value: 'haushalt', label: '🏠 Haushalt' },
  { value: 'buecher', label: '📚 Bücher & Medien' },
  { value: 'handwerk', label: '🔧 Werkzeug' },
  { value: 'sonstiges', label: '📦 Sonstiges' },
]

const CONDITIONS = [
  { value: 'neu', label: 'Neu' },
  { value: 'wie_neu', label: 'Wie neu' },
  { value: 'gut', label: 'Gut' },
  { value: 'akzeptabel', label: 'Akzeptabel' },
]

const PRICE_TYPES = [
  { value: 'fixed', label: '💶 Festpreis' },
  { value: 'negotiable', label: '🤝 Verhandlungsbasis' },
  { value: 'free', label: '🎁 Zu verschenken' },
  { value: 'swap', label: '🔄 Tausch' },
]

const catEmoji: Record<string, string> = {
  moebel: '🛋️', elektronik: '📱', kleidung: '👗', sport: '⚽',
  garten: '🌱', kinder: '🧸', haushalt: '🏠', buecher: '📚',
  handwerk: '🔧', sonstiges: '📦',
}

// Category → gradient background for image placeholder
const catGradient: Record<string, string> = {
  moebel:     'from-amber-50 via-orange-50 to-rose-50',
  elektronik: 'from-sky-50 via-blue-50 to-indigo-50',
  kleidung:   'from-pink-50 via-rose-50 to-fuchsia-50',
  sport:      'from-lime-50 via-emerald-50 to-teal-50',
  garten:     'from-green-50 via-emerald-50 to-teal-50',
  kinder:     'from-yellow-50 via-amber-50 to-orange-50',
  haushalt:   'from-stone-50 via-warm-50 to-amber-50',
  buecher:    'from-violet-50 via-purple-50 to-indigo-50',
  handwerk:   'from-slate-50 via-gray-50 to-stone-50',
  sonstiges:  'from-orange-50 via-amber-50 to-yellow-50',
}

// ── Create Listing Modal ────────────────────────────────────────
const MAX_LISTING_IMAGES = 5

function CreateListingModal({ onClose, onCreated }: { onClose: () => void; onCreated: () => void }) {
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [category, setCategory] = useState('sonstiges')
  const [condition, setCondition] = useState('gut')
  const [priceType, setPriceType] = useState('negotiable')
  const [price, setPrice] = useState('')
  const [location, setLocation] = useState('')
  const [saving, setSaving] = useState(false)
  const [images, setImages] = useState<{ file: File; preview: string }[]>([])
  const fileInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [onClose])

  // Revoke object URLs on unmount to avoid leaks
  useEffect(() => () => {
    images.forEach(img => URL.revokeObjectURL(img.preview))
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const handleFilesSelected = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files ?? [])
    if (!files.length) return
    const remaining = MAX_LISTING_IMAGES - images.length
    if (remaining <= 0) {
      toast.error(`Max. ${MAX_LISTING_IMAGES} Bilder pro Anzeige`)
      return
    }
    const accepted = files.slice(0, remaining).filter(f => {
      if (!f.type.startsWith('image/')) { toast.error(`${f.name}: Kein Bild`); return false }
      if (f.size > 10 * 1024 * 1024) { toast.error(`${f.name}: zu groß (max 10MB)`); return false }
      return true
    })
    if (files.length > remaining) {
      toast.error(`Nur ${remaining} weitere Bilder möglich`)
    }
    setImages(prev => [...prev, ...accepted.map(file => ({ file, preview: URL.createObjectURL(file) }))])
    // Reset so the same file can be re-selected if removed
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

      // Upload images (if any) before inserting the row so we can persist
      // the public URLs in `image_urls`. Falls back to `avatars` bucket
      // if `chat-images` rejects for any reason (same strategy as ChatView).
      const uploadedUrls: string[] = []
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
      }

      const priceVal = priceType === 'free' ? 0 : (parseFloat(price) || null)

      const insertData: Record<string, unknown> = {
        title: title.trim(),
        description: description.trim() || null,
        category,
        condition: condition,
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
      onCreated()
      onClose()
    } catch (err: unknown) {
      console.error('Marketplace create error:', err)
      const msg = err instanceof Error ? err.message : ''
      toast.error('Fehler beim Erstellen: ' + msg)
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-md z-50 flex items-center justify-center p-4 animate-fade-in" onClick={onClose}>
      <div
        className="bg-white rounded-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto shadow-card animate-scale-in"
        onClick={e => e.stopPropagation()}
      >
        {/* Gradient header */}
        <div className="relative overflow-hidden px-6 pt-6 pb-5 bg-gradient-to-br from-orange-500 via-amber-500 to-orange-600">
          <div className="bg-noise absolute inset-0 opacity-25 pointer-events-none" />
          <div className="relative flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-white/20 backdrop-blur-sm flex items-center justify-center">
                <ShoppingBag className="w-5 h-5 text-white" />
              </div>
              <div>
                <h2 className="text-lg font-bold text-white">Neue Anzeige</h2>
                <p className="text-xs text-white/80 mt-0.5">Kaufen · Verkaufen · Tauschen · Verschenken</p>
              </div>
            </div>
            <button
              onClick={onClose}
              className="p-2 hover:bg-white/20 rounded-xl transition-colors text-white/90"
              aria-label="Schließen"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        <div className="p-6 space-y-4">
          <div>
            <label className="label">Titel *</label>
            <input value={title} onChange={e => setTitle(e.target.value)} maxLength={80}
              className="input" placeholder="Was bietest du an?" />
          </div>
          <div>
            <label className="label">Beschreibung</label>
            <textarea value={description} onChange={e => setDescription(e.target.value)} rows={3} maxLength={1000}
              className="input resize-none" placeholder="Details zum Artikel..." />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Kategorie</label>
              <select value={category} onChange={e => setCategory(e.target.value)} className="input">
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
                <input type="number" value={price} onChange={e => setPrice(e.target.value)} min="0" step="0.5"
                  className="input" placeholder="0.00" />
              </div>
            )}
          </div>
          <div>
            <label className="label">Standort</label>
            <input value={location} onChange={e => setLocation(e.target.value)}
              className="input" placeholder="z.B. Berlin-Mitte" />
          </div>

          {/* ── Bild-Upload (max. 5) ─────────────────────────── */}
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
                  className="aspect-square rounded-xl border-2 border-dashed border-stone-300 flex flex-col items-center justify-center gap-1 text-stone-400 hover:text-orange-600 hover:border-orange-400 hover:bg-orange-50/50 transition-all"
                >
                  <ImagePlus className="w-5 h-5" />
                  <span className="text-[10px] font-medium">Bild</span>
                </button>
              )}
            </div>
          </div>

          <button onClick={handleCreate} disabled={saving || title.trim().length < 3}
            className="shine w-full py-3 bg-gradient-to-r from-orange-500 to-amber-600 text-white rounded-xl font-semibold hover:shadow-card disabled:opacity-50 flex items-center justify-center gap-2 transition-all active:scale-[0.98]">
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Plus className="w-4 h-4" />}
            Anzeige erstellen
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Listing Card ────────────────────────────────────────────────
function ListingCard({
  listing, currentUserId, onMarkClaimed, onReservationChange,
}: {
  listing: Listing
  currentUserId?: string
  onMarkClaimed: (id: string) => void
  onReservationChange: (id: string, patch: { reserved_for?: string | null; status?: string }) => void
}) {
  const pt = listing.price_type || listing.listing_type || 'negotiable'
  const cond = listing.condition_state || listing.condition || null
  const isFree = pt === 'free'
  const isSwap = pt === 'swap'
  const priceLabel = isFree ? 'Gratis'
    : isSwap ? 'Tausch'
    : listing.price != null ? `${listing.price.toFixed(0)} €` : 'VB'
  const isClaimed = listing.status === 'claimed'
  const ownerId = listing.seller_id || listing.user_id || ''
  const isOwner = currentUserId && (listing.seller_id === currentUserId || listing.user_id === currentUserId)
  const gradient = catGradient[listing.category] || catGradient.sonstiges

  // `image_urls` is the canonical column (text[]), `images` is a legacy fallback.
  const pics = (listing.image_urls?.length ? listing.image_urls : listing.images) ?? []
  const [picIdx, setPicIdx] = useState(0)
  const hasPics = pics.length > 0
  const showPrev = (e: React.MouseEvent) => { e.stopPropagation(); setPicIdx(i => (i - 1 + pics.length) % pics.length) }
  const showNext = (e: React.MouseEvent) => { e.stopPropagation(); setPicIdx(i => (i + 1) % pics.length) }

  return (
    <div className={cn(
      'spotlight bg-white rounded-2xl border overflow-hidden group relative',
      'transition-all duration-300',
      isClaimed
        ? 'border-stone-200 opacity-60'
        : 'border-stone-100 shadow-soft hover:shadow-card hover:-translate-y-1',
    )}>
      {/* Top accent line */}
      {!isClaimed && (
        <div className="absolute top-0 left-0 right-0 h-[3px] bg-gradient-to-r from-orange-400 via-amber-500 to-orange-400 z-10" />
      )}

      {/* Image / Placeholder area */}
      <div className={cn(
        'h-40 relative flex items-center justify-center overflow-hidden bg-gradient-to-br',
        !hasPics && gradient,
        hasPics && 'bg-stone-100',
      )}>
        {hasPics ? (
          <>
            {/* Actual photo — covers the whole area */}
            <img
              src={pics[picIdx]}
              alt={listing.title}
              loading="lazy"
              className="absolute inset-0 w-full h-full object-cover"
              onError={(e) => {
                // Broken URL → hide and let the gradient+emoji show through
                e.currentTarget.style.display = 'none'
              }}
            />
            {/* Category emoji tag (small) */}
            <span className="absolute top-3 left-3 text-lg bg-white/90 backdrop-blur-sm rounded-full w-8 h-8 flex items-center justify-center shadow-soft">
              {catEmoji[listing.category] || '📦'}
            </span>
            {/* Prev/Next + dot indicators (only if >1 image) */}
            {pics.length > 1 && (
              <>
                <button
                  type="button"
                  onClick={showPrev}
                  className="absolute left-1.5 top-1/2 -translate-y-1/2 w-7 h-7 rounded-full bg-black/45 text-white backdrop-blur-sm opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center"
                  aria-label="Vorheriges Bild"
                >
                  <ChevronLeft className="w-4 h-4" />
                </button>
                <button
                  type="button"
                  onClick={showNext}
                  className="absolute right-1.5 top-1/2 -translate-y-1/2 w-7 h-7 rounded-full bg-black/45 text-white backdrop-blur-sm opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center"
                  aria-label="Nächstes Bild"
                >
                  <ChevronRight className="w-4 h-4" />
                </button>
                <div className="absolute bottom-2 left-1/2 -translate-x-1/2 flex gap-1">
                  {pics.map((_, i) => (
                    <span
                      key={i}
                      className={cn(
                        'w-1.5 h-1.5 rounded-full transition-all',
                        i === picIdx ? 'bg-white w-4' : 'bg-white/60',
                      )}
                    />
                  ))}
                </div>
                <span className="absolute top-3 right-14 bg-black/55 backdrop-blur-sm text-white text-[10px] font-bold px-2 py-0.5 rounded-full tabular-nums">
                  {picIdx + 1}/{pics.length}
                </span>
              </>
            )}
          </>
        ) : (
          <>
            {/* Film grain for depth */}
            <div className="bg-noise absolute inset-0 opacity-30 pointer-events-none" />

            {/* Emoji icon — float-idle */}
            <span className={cn(
              'text-5xl relative z-[1] transition-transform duration-500 drop-shadow-sm',
              !isClaimed && 'group-hover:scale-110 group-hover:-rotate-3',
              'float-idle',
            )}>
              {catEmoji[listing.category] || '📦'}
            </span>
          </>
        )}

        {/* Price badge */}
        <div className={cn(
          'absolute top-3 right-3 backdrop-blur-md rounded-full px-3 py-1.5 text-xs font-bold shadow-soft',
          isFree
            ? 'bg-primary-600/95 text-white'
            : isSwap
              ? 'bg-[#4F6D8A]/95 text-white'
              : 'bg-white/95 text-orange-700',
        )}>
          {isFree && '🎁 '}
          {isSwap && '🔄 '}
          {priceLabel}
        </div>

        {/* Claimed overlay */}
        {isClaimed && (
          <div className="absolute inset-0 bg-stone-900/50 backdrop-blur-sm flex items-center justify-center">
            <span className="bg-white text-stone-800 text-xs font-bold px-4 py-2 rounded-full flex items-center gap-1.5 shadow-card">
              <CheckCircle2 className="w-3.5 h-3.5 text-primary-600" /> Vergeben
            </span>
          </div>
        )}
      </div>

      {/* Body */}
      <div className="p-3.5">
        <h3 className="font-bold text-gray-900 text-sm truncate leading-snug">{listing.title}</h3>
        {listing.description && (
          <p className="text-xs text-gray-500 mt-1 line-clamp-2 leading-relaxed">{listing.description}</p>
        )}

        <div className="flex items-center gap-2 mt-2.5 text-xs text-gray-500 flex-wrap">
          {listing.location_text && (
            <span className="inline-flex items-center gap-1">
              <MapPin className="w-3 h-3 text-orange-400" />
              <span className="truncate max-w-[120px]">{listing.location_text}</span>
            </span>
          )}
          {cond && (
            <span className="bg-stone-100 px-2 py-0.5 rounded-full text-stone-600 font-medium text-[10px] uppercase tracking-wide">
              {cond}
            </span>
          )}
        </div>

        <div className="flex items-center justify-between mt-3 pt-2.5 border-t border-stone-100">
          <span className="inline-flex items-center gap-1 text-[11px] text-gray-400">
            <Clock className="w-3 h-3" />
            {new Date(listing.created_at).toLocaleDateString('de-DE')}
          </span>
          {isOwner && !isClaimed && (
            <button
              onClick={() => onMarkClaimed(listing.id)}
              className="text-[11px] font-semibold text-gray-500 hover:text-primary-700 hover:bg-primary-50 px-2 py-1 rounded-full transition-colors flex items-center gap-1"
            >
              <CheckCircle2 className="w-3 h-3" /> Vergeben
            </button>
          )}
        </div>

        {!isClaimed && ownerId && (
          <div className="mt-2 flex justify-end">
            <MarketplaceReservation
              listingId={listing.id}
              ownerId={ownerId}
              currentUserId={currentUserId}
              reservedFor={listing.reserved_for ?? null}
              status={listing.status}
              onChange={(patch) => onReservationChange(listing.id, patch)}
            />
          </div>
        )}
      </div>
    </div>
  )
}

// ── Main Marketplace Page ───────────────────────────────────────
export default function MarketplacePage() {
  const [listings, setListings] = useState<Listing[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [filterCat, setFilterCat] = useState('all')
  const [filterPrice, setFilterPrice] = useState('all')
  const [showCreate, setShowCreate] = useState(false)
  const [currentUserId, setCurrentUserId] = useState<string | undefined>()
  const [showClaimed, setShowClaimed] = useState(false)

  const loadData = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (user) setCurrentUserId(user.id)
    const { data, error } = await supabase.from('marketplace_listings').select('*')
      .in('status', ['active', 'claimed'])
      .order('created_at', { ascending: false })
    if (error) {
      console.error('marketplace load failed:', error.message)
      toast.error('Inserate konnten nicht geladen werden')
    }
    setListings(data ?? [])
    setLoading(false)
  }, [])

  const handleReservationChange = useCallback((id: string, patch: { reserved_for?: string | null; status?: string }) => {
    setListings(prev => prev.map(l => l.id === id ? { ...l, ...patch } : l))
  }, [])

  const handleMarkClaimed = useCallback(async (id: string) => {
    const supabase = createClient()
    setListings(prev => prev.map(l => l.id === id ? { ...l, status: 'claimed' } : l))
    const { error } = await supabase.from('marketplace_listings').update({ status: 'claimed' }).eq('id', id)
    if (error) {
      setListings(prev => prev.map(l => l.id === id ? { ...l, status: 'active' } : l))
      toast.error('Konnte nicht als vergeben markiert werden')
      return
    }
    toast.success('Als vergeben markiert')
  }, [])

  useEffect(() => { loadData() }, [loadData])

  const filtered = listings.filter(l => {
    if (!showClaimed && l.status === 'claimed') return false
    if (filterCat !== 'all' && l.category !== filterCat) return false
    const lpt = l.price_type || l.listing_type || 'negotiable'
    if (filterPrice !== 'all' && lpt !== filterPrice) return false
    if (searchTerm && !l.title.toLowerCase().includes(searchTerm.toLowerCase()) &&
        !(l.description ?? '').toLowerCase().includes(searchTerm.toLowerCase())) return false
    return true
  })

  const claimedCount = listings.filter(l => l.status === 'claimed').length
  const activeCount = listings.filter(l => l.status === 'active').length
  const freeCount = listings.filter(l => (l.price_type || l.listing_type) === 'free').length

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 py-6">
      {/* Editorial header */}
      <header className="mb-8 relative overflow-hidden">
        <div className="bg-noise absolute inset-0 opacity-20 pointer-events-none" aria-hidden />
        <div
          className="pointer-events-none absolute -top-16 -right-10 w-64 h-64 rounded-full opacity-25"
          style={{ background: 'radial-gradient(circle, rgba(251,146,60,0.35), transparent 70%)' }}
          aria-hidden
        />

        <div className="relative">
          <div className="meta-label meta-label--subtle mb-4">§ 27 / Marktplatz</div>
          <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
            <div className="flex items-start gap-4">
              <div
                className="w-14 h-14 rounded-2xl bg-gradient-to-br from-orange-100 to-amber-50 border border-orange-200/60 flex items-center justify-center flex-shrink-0 float-idle"
                style={{ boxShadow: '0 8px 24px -8px rgba(251,146,60,0.35)' }}
              >
                <ShoppingBag className="w-6 h-6 text-orange-600" />
              </div>
              <div>
                <h1 className="page-title">Marktplatz</h1>
                <p className="page-subtitle mt-2">Kaufen, verkaufen, tauschen und <span className="text-accent">verschenken</span>.</p>
              </div>
            </div>

            {/* Stat pills */}
            <div className="flex items-center gap-2 flex-shrink-0 text-xs tracking-wide text-ink-500 flex-wrap">
              <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-white border border-stone-200 shadow-soft">
                <span className="display-numeral text-ink-900 tabular-nums font-semibold">{activeCount}</span>
                <span className="text-ink-500">Anzeigen</span>
              </span>
              <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-primary-50 border border-primary-200 text-primary-700">
                <span className="display-numeral tabular-nums font-semibold">{freeCount}</span>
                <span>gratis</span>
              </span>
              {claimedCount > 0 && (
                <button
                  onClick={() => setShowClaimed(v => !v)}
                  className={cn(
                    'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border transition-all',
                    showClaimed
                      ? 'bg-primary-50 border-primary-200 text-primary-700 shadow-soft'
                      : 'bg-white border-stone-200 text-ink-500 hover:bg-stone-50',
                  )}
                >
                  <CheckCircle2 className="w-3 h-3" />
                  <span className="tabular-nums font-semibold">{claimedCount}</span> vergeben
                </button>
              )}
            </div>
          </div>
          <div className="mt-6 h-px bg-gradient-to-r from-orange-300/60 via-stone-200 to-transparent" />
        </div>
      </header>

      {/* Filter Bar */}
      <div className="bg-white rounded-2xl border border-stone-100 shadow-soft p-4 mb-6">
        <div className="flex flex-col sm:flex-row gap-3">
          <div className="relative flex-1">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-orange-400" />
            <input
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              className="input pl-10 py-2.5"
              placeholder="Suche nach Artikeln..."
            />
          </div>
          <select value={filterCat} onChange={e => setFilterCat(e.target.value)} className="input w-auto min-w-[160px]">
            <option value="all">Alle Kategorien</option>
            {CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
          </select>
          <select value={filterPrice} onChange={e => setFilterPrice(e.target.value)} className="input w-auto min-w-[140px]">
            <option value="all">Alle Preise</option>
            {PRICE_TYPES.map(p => <option key={p.value} value={p.value}>{p.label}</option>)}
          </select>
          <button
            onClick={() => setShowCreate(true)}
            className="shine flex items-center justify-center gap-2 px-5 py-2.5 bg-gradient-to-r from-orange-500 to-amber-600 text-white rounded-xl text-sm font-semibold shadow-soft hover:shadow-card transition-all active:scale-[0.98] flex-shrink-0"
            style={{ boxShadow: '0 4px 16px -4px rgba(251,146,60,0.45)' }}
          >
            <Plus className="w-4 h-4" /> Anzeige erstellen
          </button>
        </div>
      </div>

      {/* Grid */}
      {loading ? (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {[1, 2, 3, 4, 5, 6, 7, 8].map(i => (
            <div key={i} className="h-56 bg-white rounded-2xl animate-pulse border border-stone-100 shadow-soft" />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-2xl border border-stone-100 shadow-soft relative overflow-hidden">
          <div
            className="pointer-events-none absolute inset-0 opacity-40"
            style={{ background: 'radial-gradient(circle at 50% 0%, rgba(251,146,60,0.10), transparent 60%)' }}
          />
          <div className="relative">
            <div className="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gradient-to-br from-orange-100 to-amber-50 border border-orange-200/60 flex items-center justify-center float-idle">
              <ShoppingBag className="w-7 h-7 text-orange-600" />
            </div>
            <p className="text-gray-900 font-bold text-lg">Keine Anzeigen gefunden</p>
            <p className="text-sm text-gray-500 mt-1 mb-5">Starte den Marktplatz mit deiner ersten Anzeige</p>
            <button
              onClick={() => setShowCreate(true)}
              className="shine inline-flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-orange-500 to-amber-600 text-white rounded-xl text-sm font-semibold shadow-soft hover:shadow-card transition-all active:scale-[0.98]"
              style={{ boxShadow: '0 4px 16px -4px rgba(251,146,60,0.45)' }}
            >
              <Plus className="w-4 h-4" /> Erste Anzeige erstellen
            </button>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 pb-8">
          {filtered.map(l => (
            <ListingCard
              key={l.id}
              listing={l}
              currentUserId={currentUserId}
              onMarkClaimed={handleMarkClaimed}
              onReservationChange={handleReservationChange}
            />
          ))}
        </div>
      )}

      {showCreate && <CreateListingModal onClose={() => setShowCreate(false)} onCreated={loadData} />}
    </div>
  )
}
