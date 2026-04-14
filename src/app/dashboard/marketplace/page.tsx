'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  ShoppingBag, Plus, Search, X, Tag, MapPin, Euro, Package,
  ChevronRight, Heart, Loader2, Filter, Grid3X3, List,
  Clock, User, Star, CheckCircle2,
} from 'lucide-react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import toast from 'react-hot-toast'
import { checkRateLimit } from '@/lib/rate-limit'

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

// ── Create Listing Modal ────────────────────────────────────────
function CreateListingModal({ onClose, onCreated }: { onClose: () => void; onCreated: () => void }) {
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [category, setCategory] = useState('sonstiges')
  const [condition, setCondition] = useState('gut')
  const [priceType, setPriceType] = useState('negotiable')
  const [price, setPrice] = useState('')
  const [location, setLocation] = useState('')
  const [saving, setSaving] = useState(false)

  // Close on Escape
  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [onClose])

  const handleCreate = async () => {
    if (title.trim().length < 3) { toast.error('Titel mindestens 3 Zeichen'); return }
    if (description.trim().length > 1000) { toast.error('Beschreibung max. 1000 Zeichen'); return }
    setSaving(true)
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { toast.error('Bitte einloggen'); setSaving(false); return }

      // Rate-Limiting
      const allowed = await checkRateLimit(user.id, 'create_listing', 3, 60)
      if (!allowed) { toast.error('Zu viele Anzeigen in kurzer Zeit. Bitte warte etwas.'); setSaving(false); return }

      const priceVal = priceType === 'free' ? 0 : (parseFloat(price) || null)

      // Insert with both old and new column names for compatibility
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
        images: [],
        image_urls: [],
        status: 'active',
      }

      let result = await supabase.from('marketplace_listings').insert(insertData)

      // If column errors, strip unknown columns and retry
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
    } catch (err: any) {
      console.error('Marketplace create error:', err)
      toast.error('Fehler beim Erstellen: ' + (err?.message ?? ''))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-fade-in" onClick={onClose}>
      <div className="bg-white rounded-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto p-6 shadow-2xl animate-scale-in" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-5">
          <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
            <ShoppingBag className="w-5 h-5 text-orange-500" /> Neue Anzeige
          </h2>
          <button onClick={onClose} className="p-1.5 hover:bg-gray-100 rounded-xl transition-colors"><X className="w-5 h-5 text-gray-400" /></button>
        </div>

        <div className="space-y-4">
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

          <button onClick={handleCreate} disabled={saving || title.trim().length < 3}
            className="w-full py-3 bg-gradient-to-r from-orange-500 to-amber-600 text-white rounded-xl font-semibold hover:shadow-lg disabled:opacity-50 flex items-center justify-center gap-2 transition-all active:scale-95">
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
  listing, currentUserId, onMarkClaimed,
}: {
  listing: Listing
  currentUserId?: string
  onMarkClaimed: (id: string) => void
}) {
  const pt = listing.price_type || listing.listing_type || 'negotiable'
  const cond = listing.condition_state || listing.condition || null
  const priceLabel = pt === 'free' ? '🎁 Gratis'
    : pt === 'swap' ? '🔄 Tausch'
    : listing.price != null ? `${listing.price.toFixed(0)} €` : 'VB'
  const isClaimed = listing.status === 'claimed'
  const isOwner = currentUserId && (listing.seller_id === currentUserId || listing.user_id === currentUserId)

  return (
    <div className={cn(
      'bg-white rounded-2xl border overflow-hidden transition-all group',
      isClaimed ? 'border-stone-200 opacity-60' : 'border-warm-200 hover:shadow-md hover:-translate-y-[2px]',
    )}>
      {/* Image or Placeholder */}
      <div className="h-36 bg-gradient-to-br from-orange-50 to-amber-50 flex items-center justify-center relative">
        <span className={cn('text-4xl opacity-80 transition-transform', !isClaimed && 'group-hover:scale-110')}>
          {catEmoji[listing.category] || '📦'}
        </span>
        <div className="absolute top-2.5 right-2.5 bg-white/90 backdrop-blur-sm rounded-full px-2.5 py-1 text-xs font-bold text-orange-600 shadow-sm">
          {priceLabel}
        </div>
        {/* Vergeben overlay */}
        {isClaimed && (
          <div className="absolute inset-0 bg-stone-900/40 flex items-center justify-center rounded-t-2xl">
            <span className="bg-white text-stone-800 text-xs font-bold px-3 py-1.5 rounded-full flex items-center gap-1.5 shadow-md">
              <CheckCircle2 className="w-3.5 h-3.5 text-green-600" /> Vergeben
            </span>
          </div>
        )}
      </div>

      <div className="p-3.5">
        <h3 className="font-bold text-gray-900 text-sm truncate">{listing.title}</h3>
        {listing.description && <p className="text-xs text-gray-500 mt-1 line-clamp-2">{listing.description}</p>}
        <div className="flex items-center gap-2 mt-2.5 text-xs text-gray-400">
          {listing.location_text && <span className="flex items-center gap-1"><MapPin className="w-3 h-3" /> {listing.location_text}</span>}
          {cond && <span className="bg-gray-50 px-2 py-0.5 rounded-lg text-gray-500 font-medium">{cond}</span>}
        </div>
        <div className="flex items-center justify-between mt-2">
          <span className="flex items-center gap-1.5 text-xs text-gray-400">
            <Clock className="w-3 h-3" />
            {new Date(listing.created_at).toLocaleDateString('de-DE')}
          </span>
          {isOwner && !isClaimed && (
            <button
              onClick={() => onMarkClaimed(listing.id)}
              className="text-xs text-ink-500 hover:text-green-700 hover:bg-green-50 px-2 py-1 rounded-lg transition-colors flex items-center gap-1"
            >
              <CheckCircle2 className="w-3 h-3" /> Vergeben
            </button>
          )}
        </div>
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

  const handleMarkClaimed = useCallback(async (id: string) => {
    const supabase = createClient()
    // Optimistic update
    setListings(prev => prev.map(l => l.id === id ? { ...l, status: 'claimed' } : l))
    const { error } = await supabase.from('marketplace_listings').update({ status: 'claimed' }).eq('id', id)
    if (error) {
      // Rollback
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

  const freeCount = listings.filter(l => (l.price_type || l.listing_type) === 'free').length

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 py-6">
      {/* Editorial header */}
      <header className="mb-8">
        <div className="meta-label meta-label--subtle mb-4">§ 27 / Marktplatz</div>
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 rounded-2xl bg-orange-50 border border-orange-100 flex items-center justify-center flex-shrink-0 float-idle">
              <ShoppingBag className="w-6 h-6 text-orange-600" />
            </div>
            <div>
              <h1 className="page-title">Marktplatz</h1>
              <p className="page-subtitle mt-2">Kaufen, verkaufen, tauschen und <span className="text-accent">verschenken</span>.</p>
            </div>
          </div>
          <div className="flex items-center gap-2 flex-shrink-0 text-xs tracking-wide text-ink-500">
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-stone-100 border border-stone-200">
              <span className="font-serif italic text-ink-800 tabular-nums">{listings.filter(l => l.status === 'active').length}</span> Anzeigen
            </span>
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-stone-100 border border-stone-200">
              <span className="font-serif italic text-ink-800 tabular-nums">{freeCount}</span> gratis
            </span>
            {claimedCount > 0 && (
              <button
                onClick={() => setShowClaimed(v => !v)}
                className={cn(
                  'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border transition-colors',
                  showClaimed
                    ? 'bg-green-50 border-green-200 text-green-700'
                    : 'bg-stone-100 border-stone-200 text-ink-500 hover:bg-stone-50',
                )}
              >
                <CheckCircle2 className="w-3 h-3" />
                <span className="tabular-nums">{claimedCount}</span> vergeben
              </button>
            )}
          </div>
        </div>
        <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
      </header>

      <div>
        {/* Filter Bar */}
        <div className="bg-white rounded-2xl border border-warm-200 shadow-sm p-4 mb-6">
          <div className="flex flex-col sm:flex-row gap-3">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input value={searchTerm} onChange={e => setSearchTerm(e.target.value)}
                className="input pl-10 py-2.5" placeholder="Suche nach Artikeln..." />
            </div>
            <select value={filterCat} onChange={e => setFilterCat(e.target.value)} className="input w-auto min-w-[160px]">
              <option value="all">Alle Kategorien</option>
              {CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
            </select>
            <select value={filterPrice} onChange={e => setFilterPrice(e.target.value)} className="input w-auto min-w-[140px]">
              <option value="all">Alle Preise</option>
              {PRICE_TYPES.map(p => <option key={p.value} value={p.value}>{p.label}</option>)}
            </select>
            <button onClick={() => setShowCreate(true)}
              className="flex items-center justify-center gap-2 px-5 py-2.5 bg-gradient-to-r from-orange-500 to-amber-600 text-white rounded-xl text-sm font-semibold hover:shadow-lg transition-all active:scale-95 flex-shrink-0">
              <Plus className="w-4 h-4" /> Anzeige erstellen
            </button>
          </div>
        </div>

        {/* Grid */}
        {loading ? (
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {[1, 2, 3, 4, 5, 6].map(i => <div key={i} className="h-56 bg-white rounded-2xl animate-pulse border border-warm-200" />)}
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-16 bg-white rounded-2xl border border-warm-200 shadow-sm">
            <ShoppingBag className="w-12 h-12 text-gray-300 mx-auto mb-3" />
            <p className="text-gray-700 font-bold text-lg">Keine Anzeigen gefunden</p>
            <p className="text-sm text-gray-500 mt-1 mb-4">Starte den Marktplatz mit deiner ersten Anzeige</p>
            <button onClick={() => setShowCreate(true)} className="inline-flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-orange-500 to-amber-600 text-white rounded-xl text-sm font-semibold hover:shadow-lg transition-all active:scale-95">
              <Plus className="w-4 h-4" /> Erste Anzeige erstellen
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 pb-8">
            {filtered.map(l => (
              <ListingCard
                key={l.id}
                listing={l}
                currentUserId={currentUserId}
                onMarkClaimed={handleMarkClaimed}
              />
            ))}
          </div>
        )}
      </div>

      {showCreate && <CreateListingModal onClose={() => setShowCreate(false)} onCreated={loadData} />}
    </div>
  )
}
