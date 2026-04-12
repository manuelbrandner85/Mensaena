'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  ShoppingBag, Plus, Search, X, Tag, MapPin, Euro, Package,
  ChevronRight, Heart, Loader2, Filter, Grid3X3, List,
  Clock, User, Star,
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
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto p-6" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-bold text-gray-900">Neue Anzeige</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded-lg"><X className="w-5 h-5" /></button>
        </div>

        <div className="space-y-4">
          <div>
            <label className="text-sm font-medium text-gray-700">Titel *</label>
            <input value={title} onChange={e => setTitle(e.target.value)} maxLength={80}
              className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-orange-500" placeholder="Was bietest du an?" />
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Beschreibung</label>
            <textarea value={description} onChange={e => setDescription(e.target.value)} rows={3} maxLength={1000}
              className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-orange-500" placeholder="Details zum Artikel..." />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-sm font-medium text-gray-700">Kategorie</label>
              <select value={category} onChange={e => setCategory(e.target.value)}
                className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-orange-500">
                {CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
            </div>
            <div>
              <label className="text-sm font-medium text-gray-700">Zustand</label>
              <select value={condition} onChange={e => setCondition(e.target.value)}
                className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-orange-500">
                {CONDITIONS.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-sm font-medium text-gray-700">Preisart</label>
              <select value={priceType} onChange={e => setPriceType(e.target.value)}
                className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-orange-500">
                {PRICE_TYPES.map(p => <option key={p.value} value={p.value}>{p.label}</option>)}
              </select>
            </div>
            {priceType !== 'free' && priceType !== 'swap' && (
              <div>
                <label className="text-sm font-medium text-gray-700">Preis (€)</label>
                <input type="number" value={price} onChange={e => setPrice(e.target.value)} min="0" step="0.5"
                  className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-orange-500" placeholder="0.00" />
              </div>
            )}
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Standort</label>
            <input value={location} onChange={e => setLocation(e.target.value)}
              className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-orange-500" placeholder="z.B. Berlin-Mitte" />
          </div>

          <button onClick={handleCreate} disabled={saving || title.trim().length < 3}
            className="w-full py-2.5 bg-orange-500 text-white rounded-xl font-medium hover:bg-orange-600 disabled:opacity-50 flex items-center justify-center gap-2">
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Plus className="w-4 h-4" />}
            Anzeige erstellen
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Listing Card ────────────────────────────────────────────────
function ListingCard({ listing }: { listing: Listing }) {
  const pt = listing.price_type || listing.listing_type || 'negotiable'
  const cond = listing.condition_state || listing.condition || null
  const priceLabel = pt === 'free' ? '🎁 Gratis'
    : pt === 'swap' ? '🔄 Tausch'
    : listing.price != null ? `${listing.price.toFixed(0)} €` : 'VB'

  return (
    <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden hover:shadow-md transition-all group">
      {/* Image or Placeholder */}
      <div className="h-36 bg-gradient-to-br from-orange-50 to-amber-50 flex items-center justify-center relative">
        <span className="text-4xl">{catEmoji[listing.category] || '📦'}</span>
        <div className="absolute top-2 right-2 bg-white/90 backdrop-blur-sm rounded-full px-2 py-0.5 text-xs font-bold text-orange-600">
          {priceLabel}
        </div>
      </div>

      <div className="p-3">
        <h3 className="font-bold text-gray-900 text-sm truncate">{listing.title}</h3>
        {listing.description && <p className="text-xs text-gray-500 mt-0.5 line-clamp-2">{listing.description}</p>}
        <div className="flex items-center gap-2 mt-2 text-xs text-gray-400">
          {listing.location_text && <span className="flex items-center gap-0.5"><MapPin className="w-3 h-3" /> {listing.location_text}</span>}
          {cond && <span className="bg-gray-50 px-1.5 py-0.5 rounded">{cond}</span>}
        </div>
        <div className="flex items-center gap-1 mt-2 text-xs text-gray-400">
          <Clock className="w-3 h-3" />
          {new Date(listing.created_at).toLocaleDateString('de-DE')}
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

  const loadData = useCallback(async () => {
    const supabase = createClient()
    const { data } = await supabase.from('marketplace_listings').select('*')
      .eq('status', 'active')
      .order('created_at', { ascending: false })
    setListings(data ?? [])
    setLoading(false)
  }, [])

  useEffect(() => { loadData() }, [loadData])

  const filtered = listings.filter(l => {
    if (filterCat !== 'all' && l.category !== filterCat) return false
    const lpt = l.price_type || l.listing_type || 'negotiable'
    if (filterPrice !== 'all' && lpt !== filterPrice) return false
    if (searchTerm && !l.title.toLowerCase().includes(searchTerm.toLowerCase()) &&
        !(l.description ?? '').toLowerCase().includes(searchTerm.toLowerCase())) return false
    return true
  })

  const freeCount = listings.filter(l => (l.price_type || l.listing_type) === 'free').length

  return (
    <div className="min-h-screen bg-gradient-to-b from-orange-50 via-white to-white">
      {/* Header */}
      <div className="bg-gradient-to-r from-orange-500 to-amber-600 text-white px-4 sm:px-6 py-8">
        <div className="max-w-5xl mx-auto">
          <div className="flex items-center gap-3 mb-2">
            <div className="p-2.5 bg-white/20 rounded-xl backdrop-blur-sm"><ShoppingBag className="w-6 h-6" /></div>
            <h1 className="text-2xl font-bold">Marktplatz</h1>
          </div>
          <p className="text-orange-100 text-sm">Kaufen, verkaufen, tauschen und verschenken in deiner Nachbarschaft</p>
          <div className="flex gap-4 mt-4">
            <div className="bg-white/15 backdrop-blur-sm rounded-xl px-3 py-1.5 text-sm">
              📦 {listings.length} Anzeigen
            </div>
            <div className="bg-white/15 backdrop-blur-sm rounded-xl px-3 py-1.5 text-sm">
              🎁 {freeCount} gratis
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-5xl mx-auto px-4 sm:px-6 -mt-4">
        {/* Filter Bar */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4 mb-6">
          <div className="flex flex-col sm:flex-row gap-3">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input value={searchTerm} onChange={e => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border rounded-xl text-sm focus:ring-2 focus:ring-orange-500" placeholder="Suche nach Artikeln..." />
            </div>
            <select value={filterCat} onChange={e => setFilterCat(e.target.value)}
              className="px-3 py-2 border rounded-xl text-sm focus:ring-2 focus:ring-orange-500">
              <option value="all">Alle Kategorien</option>
              {CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
            </select>
            <select value={filterPrice} onChange={e => setFilterPrice(e.target.value)}
              className="px-3 py-2 border rounded-xl text-sm focus:ring-2 focus:ring-orange-500">
              <option value="all">Alle Preise</option>
              {PRICE_TYPES.map(p => <option key={p.value} value={p.value}>{p.label}</option>)}
            </select>
            <button onClick={() => setShowCreate(true)}
              className="flex items-center justify-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-xl text-sm font-medium hover:bg-orange-600 transition-all">
              <Plus className="w-4 h-4" /> Anzeige erstellen
            </button>
          </div>
        </div>

        {/* Grid */}
        {loading ? (
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {[1, 2, 3, 4, 5, 6].map(i => <div key={i} className="h-56 bg-white rounded-2xl animate-pulse border" />)}
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-16">
            <ShoppingBag className="w-12 h-12 text-gray-300 mx-auto mb-3" />
            <p className="text-gray-500 font-medium">Keine Anzeigen gefunden</p>
            <button onClick={() => setShowCreate(true)} className="mt-3 text-sm text-orange-600 hover:text-orange-700 font-medium">
              Erstelle die erste Anzeige →
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 pb-8">
            {filtered.map(l => <ListingCard key={l.id} listing={l} />)}
          </div>
        )}
      </div>

      {showCreate && <CreateListingModal onClose={() => setShowCreate(false)} onCreated={loadData} />}
    </div>
  )
}
