'use client'

import { useEffect, useState, useCallback } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import dynamic from 'next/dynamic'
import {
  ArrowLeft, MapPin, Phone, Mail, Globe, Clock, Leaf, CheckCircle2,
  Truck, Scissors, ShoppingBag, Share2, Heart, ExternalLink,
  Building2, Star, Package, RefreshCw, Copy, MessageCircle
} from 'lucide-react'
import type { FarmListing } from '@/types/farm'
import { CATEGORY_ICONS, CATEGORY_COLORS, COUNTRY_LABELS } from '@/types/farm'
import { createClient } from '@/lib/supabase/client'

// Supabase client via singleton

// Mini-Map lazy
const FarmDetailMap = dynamic(() => import('@/components/supply/FarmDetailMap'), {
  ssr: false,
  loading: () => (
    <div className="h-64 bg-green-50 rounded-2xl flex items-center justify-center">
      <div className="w-8 h-8 border-4 border-green-400 border-t-transparent rounded-full animate-spin" />
    </div>
  ),
})

const WEEKDAYS_DE: Record<string, string> = {
  monday: 'Montag', tuesday: 'Dienstag', wednesday: 'Mittwoch',
  thursday: 'Donnerstag', friday: 'Freitag', saturday: 'Samstag', sunday: 'Sonntag',
}

// ─── Ähnliche Betriebe ────────────────────────────────────────
function SimilarFarms({ farm }: { farm: FarmListing }) {
  const [similar, setSimilar] = useState<FarmListing[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    // Same category AND same city/state, exclude current
    supabase
      .from('farm_listings')
      .select('id,name,slug,category,city,state,country,postal_code,products,is_bio,is_verified,description')
      .eq('is_public', true)
      .eq('category', farm.category)
      .neq('id', farm.id)
      .or(`city.ilike.%${farm.city}%,state.ilike.%${farm.state || ''}%`)
      .limit(4)
      .then(({ data }) => {
        if (data && data.length > 0) {
          setSimilar(data as FarmListing[])
        } else {
          // Fallback: same category only
          supabase
            .from('farm_listings')
            .select('id,name,slug,category,city,state,country,postal_code,products,is_bio,is_verified,description')
            .eq('is_public', true)
            .eq('category', farm.category)
            .neq('id', farm.id)
            .limit(4)
            .then(({ data: d2 }) => setSimilar((d2 || []) as FarmListing[]))
            .catch(() => {})
        }
      })
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [farm.id, farm.category, farm.city, farm.state])

  if (loading) return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
      <h2 className="font-bold text-gray-900 mb-4">Ähnliche Betriebe</h2>
      <div className="grid grid-cols-2 gap-3">
        {[1,2,3,4].map((i) => <div key={i} className="bg-gray-100 rounded-xl h-24 animate-pulse" />)}
      </div>
    </div>
  )

  if (similar.length === 0) return null

  return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
      <h2 className="flex items-center gap-2 font-bold text-gray-900 mb-4">
        🔍 Ähnliche Betriebe in der Region
      </h2>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        {similar.map((s) => (
          <Link
            key={s.id}
            href={`/dashboard/supply/farm/${s.slug}`}
            className="flex items-start gap-3 p-3 rounded-xl border border-gray-100 hover:border-green-300 hover:bg-green-50/50 transition-all group"
          >
            <span className="text-xl shrink-0">{CATEGORY_ICONS[s.category] || '🏡'}</span>
            <div className="min-w-0 flex-1">
              <p className="font-semibold text-sm text-gray-900 group-hover:text-green-700 transition-colors truncate">{s.name}</p>
              <p className="text-xs text-gray-500 truncate">
                {s.postal_code} {s.city}{s.state ? `, ${s.state}` : ''}
              </p>
              {s.is_bio && <span className="text-xs text-lime-700">🌿 Bio</span>}
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}

// ─── Share Panel ──────────────────────────────────────────────
function SharePanel({ farm }: { farm: FarmListing }) {
  const [open,   setOpen]   = useState(false)
  const [copied, setCopied] = useState(false)

  const url  = typeof window !== 'undefined' ? window.location.href : ''
  const text = `${farm.name} – ${farm.city} | Mensaena`

  const copyLink = useCallback(() => {
    navigator.clipboard.writeText(url).then(() => {
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    })
  }, [url])

  const shareWhatsApp = () =>
    window.open(`https://wa.me/?text=${encodeURIComponent(text + '\n' + url)}`, '_blank')

  const nativeShare = () => {
    if (navigator.share) {
      navigator.share({ title: farm.name, text, url }).catch(() => {})
    } else {
      copyLink()
    }
  }

  return (
    <div className="relative">
      <button
        onClick={() => setOpen(!open)}
        className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-gray-200 text-sm font-medium text-gray-600 hover:border-green-300 hover:text-green-700 transition-all"
      >
        <Share2 className="w-4 h-4" /> Teilen
      </button>
      {open && (
        <div className="absolute right-0 top-full mt-2 z-50 bg-white rounded-2xl shadow-xl border border-gray-100 p-4 w-64">
          <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">Teilen über</p>
          <div className="space-y-2">
            <button
              onClick={copyLink}
              className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-gray-50 text-sm text-gray-700 transition-colors"
            >
              <Copy className="w-4 h-4 text-gray-400" />
              {copied ? '✓ Link kopiert!' : 'Link kopieren'}
            </button>
            <button
              onClick={shareWhatsApp}
              className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-green-50 text-sm text-gray-700 transition-colors"
            >
              <MessageCircle className="w-4 h-4 text-green-500" />
              Via WhatsApp teilen
            </button>
            {typeof navigator !== 'undefined' && navigator.share && (
              <button
                onClick={nativeShare}
                className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-blue-50 text-sm text-gray-700 transition-colors"
              >
                <Share2 className="w-4 h-4 text-blue-500" />
                Über System teilen
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

// ─── Hauptkomponente ──────────────────────────────────────────
export default function FarmDetailPage() {
  const { slug } = useParams<{ slug: string }>()
  const router   = useRouter()
  const [farm,    setFarm]    = useState<FarmListing | null>(null)
  const [loading, setLoading] = useState(true)
  const [isFav,   setIsFav]   = useState(false)

  // Load farm
  useEffect(() => {
    if (!slug) return
    const supabase = createClient()
    supabase
      .from('farm_listings').select('*')
      .eq('slug', slug).eq('is_public', true).single()
      .then(({ data }) => setFarm(data || null))
      .catch(() => setFarm(null))
      .finally(() => setLoading(false))
  }, [slug])

  // Sync favorites from localStorage
  useEffect(() => {
    if (!farm) return
    try {
      const saved = localStorage.getItem('mensaena_favorites')
      if (saved) setIsFav(JSON.parse(saved).includes(farm.id))
    } catch { /* ignore */ }
  }, [farm])

  const toggleFav = useCallback(() => {
    if (!farm) return
    setIsFav((prev) => {
      const next = !prev
      try {
        const saved: string[] = JSON.parse(localStorage.getItem('mensaena_favorites') || '[]')
        const updated = next ? [...saved, farm.id] : saved.filter((x) => x !== farm.id)
        localStorage.setItem('mensaena_favorites', JSON.stringify(updated))
      } catch { /* ignore */ }
      return next
    })
  }, [farm])

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="w-12 h-12 border-4 border-green-400 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
          <p className="text-gray-500">Betrieb wird geladen…</p>
        </div>
      </div>
    )
  }

  if (!farm) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <span className="text-6xl mb-4 block">🌾</span>
          <h2 className="text-2xl font-bold text-gray-800 mb-2">Betrieb nicht gefunden</h2>
          <p className="text-gray-500 mb-6">Dieser Eintrag existiert nicht oder wurde entfernt.</p>
          <Link
            href="/dashboard/supply"
            className="inline-flex items-center gap-2 bg-green-600 text-white px-6 py-3 rounded-xl font-semibold hover:bg-green-700 transition-colors"
          >
            <ArrowLeft className="w-4 h-4" /> Zurück zur Übersicht
          </Link>
        </div>
      </div>
    )
  }

  const categoryColor = CATEGORY_COLORS[farm.category] ?? 'bg-gray-100 text-gray-700'
  const categoryIcon  = CATEGORY_ICONS[farm.category] ?? '🏡'
  const hasCoords     = farm.latitude && farm.longitude

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Back bar */}
      <div className="bg-white border-b border-gray-100 px-4 sm:px-6 py-3">
        <div className="max-w-5xl mx-auto flex items-center justify-between">
          <button
            onClick={() => router.back()}
            className="flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900 font-medium transition-colors"
          >
            <ArrowLeft className="w-4 h-4" /> Zurück
          </button>
          <div className="flex items-center gap-2">
            {/* Favorit */}
            <button
              onClick={toggleFav}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl border text-sm font-medium transition-all ${
                isFav
                  ? 'bg-red-50 border-red-200 text-red-600'
                  : 'border-gray-200 text-gray-600 hover:border-red-200 hover:text-red-500'
              }`}
            >
              <Heart className={`w-4 h-4 ${isFav ? 'fill-red-500' : ''}`} />
              {isFav ? 'Gespeichert' : 'Merken'}
            </button>
            {/* Share Panel */}
            <SharePanel farm={farm} />
          </div>
        </div>
      </div>

      <div className="max-w-5xl mx-auto px-4 sm:px-6 py-8 space-y-6">
        {/* Hero Card */}
        <div className="bg-white rounded-3xl shadow-sm border border-gray-100 overflow-hidden">
          <div className="bg-gradient-to-r from-yellow-400 to-amber-500 h-3" />
          <div className="p-6 md:p-8">
            <div className="flex items-start gap-5">
              <div className="w-16 h-16 bg-gradient-to-br from-amber-100 to-yellow-100 rounded-2xl flex items-center justify-center text-3xl shrink-0 border border-amber-200">
                {categoryIcon}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex flex-wrap items-center gap-2 mb-2">
                  <span className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold ${categoryColor}`}>
                    {categoryIcon} {farm.category}
                  </span>
                  {farm.is_bio && (
                    <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-lime-100 text-lime-800 border border-lime-200">
                      <Leaf className="w-3 h-3" /> Bio-zertifiziert
                    </span>
                  )}
                  {farm.is_verified && (
                    <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-800 border border-blue-200">
                      <CheckCircle2 className="w-3 h-3" /> Verifiziert
                    </span>
                  )}
                  {farm.is_seasonal && (
                    <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-orange-100 text-orange-800">
                      🍂 Saisonal
                    </span>
                  )}
                </div>
                <h1 className="text-2xl md:text-3xl font-bold text-gray-900 mb-1">{farm.name}</h1>
                <p className="flex items-center gap-1.5 text-gray-500 text-sm flex-wrap">
                  <MapPin className="w-4 h-4 shrink-0" />
                  {farm.address && `${farm.address}, `}
                  {farm.postal_code && `${farm.postal_code} `}
                  {farm.city}
                  {farm.state && `, ${farm.state}`}
                  {' · '}
                  {COUNTRY_LABELS[farm.country] ?? farm.country}
                </p>
              </div>
            </div>

            {farm.description && (
              <p className="mt-5 text-gray-700 leading-relaxed text-base">{farm.description}</p>
            )}

            {/* Quick Actions */}
            <div className="flex flex-wrap gap-3 mt-6">
              {farm.phone && (
                <a href={`tel:${farm.phone}`} className="flex items-center gap-2 bg-green-600 text-white px-5 py-2.5 rounded-xl font-semibold text-sm hover:bg-green-700 transition-colors">
                  <Phone className="w-4 h-4" /> Anrufen
                </a>
              )}
              {farm.email && (
                <a href={`mailto:${farm.email}`} className="flex items-center gap-2 bg-blue-600 text-white px-5 py-2.5 rounded-xl font-semibold text-sm hover:bg-blue-700 transition-colors">
                  <Mail className="w-4 h-4" /> E-Mail
                </a>
              )}
              {farm.website && (
                <a href={farm.website} target="_blank" rel="noopener noreferrer"
                  className="flex items-center gap-2 border border-gray-200 text-gray-700 px-5 py-2.5 rounded-xl font-semibold text-sm hover:border-green-300 hover:text-green-700 transition-all">
                  <Globe className="w-4 h-4" /> Website <ExternalLink className="w-3.5 h-3.5" />
                </a>
              )}
              {hasCoords && (
                <a
                  href={`https://www.google.com/maps/dir/?api=1&destination=${farm.latitude},${farm.longitude}`}
                  target="_blank" rel="noopener noreferrer"
                  className="flex items-center gap-2 border border-gray-200 text-gray-700 px-5 py-2.5 rounded-xl font-semibold text-sm hover:border-blue-300 hover:text-blue-700 transition-all"
                >
                  <MapPin className="w-4 h-4" /> Route planen
                </a>
              )}
              {/* WhatsApp direkter Share-Button */}
              <button
                onClick={() => {
                  const url = typeof window !== 'undefined' ? window.location.href : ''
                  window.open(`https://wa.me/?text=${encodeURIComponent(farm.name + ' – ' + url)}`, '_blank')
                }}
                className="flex items-center gap-2 border border-gray-200 text-gray-700 px-5 py-2.5 rounded-xl font-semibold text-sm hover:border-green-300 hover:text-green-700 transition-all"
              >
                <MessageCircle className="w-4 h-4 text-green-500" /> Empfehlen
              </button>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {/* Left: Details */}
          <div className="md:col-span-2 space-y-6">
            {/* Produkte */}
            {farm.products.length > 0 && (
              <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
                <h2 className="flex items-center gap-2 text-lg font-bold text-gray-900 mb-4">
                  <Package className="w-5 h-5 text-amber-500" /> Produkte
                </h2>
                <div className="flex flex-wrap gap-2">
                  {farm.products.map((p) => (
                    <span key={p} className="bg-amber-50 text-amber-800 border border-amber-100 text-sm px-3 py-1.5 rounded-full font-medium">
                      {p}
                    </span>
                  ))}
                </div>
              </div>
            )}

            {/* Services */}
            {farm.services.length > 0 && (
              <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
                <h2 className="flex items-center gap-2 text-lg font-bold text-gray-900 mb-4">
                  <Star className="w-5 h-5 text-blue-500" /> Dienstleistungen & Angebote
                </h2>
                <div className="flex flex-wrap gap-2">
                  {farm.services.map((s) => (
                    <span key={s} className="bg-blue-50 text-blue-800 border border-blue-100 text-sm px-3 py-1.5 rounded-full font-medium">{s}</span>
                  ))}
                </div>
              </div>
            )}

            {/* Lieferung */}
            {farm.delivery_options.length > 0 && (
              <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
                <h2 className="flex items-center gap-2 text-lg font-bold text-gray-900 mb-4">
                  <Truck className="w-5 h-5 text-purple-500" /> Liefer- & Abholoptionen
                </h2>
                <div className="space-y-2">
                  {farm.delivery_options.map((d) => (
                    <div key={d} className="flex items-center gap-3 text-sm text-gray-700">
                      <span className="w-2 h-2 bg-purple-400 rounded-full shrink-0" />
                      {d}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Subcategories */}
            {farm.subcategories.length > 0 && (
              <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
                <h2 className="flex items-center gap-2 text-lg font-bold text-gray-900 mb-4">
                  <Building2 className="w-5 h-5 text-gray-400" /> Kategorien & Schwerpunkte
                </h2>
                <div className="flex flex-wrap gap-2">
                  {farm.subcategories.map((s) => (
                    <span key={s} className="bg-gray-100 text-gray-700 text-sm px-3 py-1.5 rounded-full">{s}</span>
                  ))}
                </div>
              </div>
            )}

            {/* Ähnliche Betriebe */}
            <SimilarFarms farm={farm} />
          </div>

          {/* Right: Contact + Hours + Map */}
          <div className="space-y-6">
            {/* Kontakt */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
              <h2 className="font-bold text-gray-900 mb-4 text-base">Kontakt & Adresse</h2>
              <div className="space-y-3 text-sm">
                {farm.address && (
                  <div className="flex items-start gap-2.5 text-gray-600">
                    <MapPin className="w-4 h-4 mt-0.5 text-gray-400 shrink-0" />
                    <div>
                      <p>{farm.address}</p>
                      <p>{farm.postal_code} {farm.city}</p>
                      <p>{farm.state}{farm.state && farm.country ? ', ' : ''}{COUNTRY_LABELS[farm.country] ?? farm.country}</p>
                    </div>
                  </div>
                )}
                {farm.phone && (
                  <a href={`tel:${farm.phone}`} className="flex items-center gap-2.5 text-gray-600 hover:text-green-700 transition-colors">
                    <Phone className="w-4 h-4 text-gray-400 shrink-0" />{farm.phone}
                  </a>
                )}
                {farm.email && (
                  <a href={`mailto:${farm.email}`} className="flex items-center gap-2.5 text-gray-600 hover:text-green-700 transition-colors">
                    <Mail className="w-4 h-4 text-gray-400 shrink-0" />
                    <span className="break-all">{farm.email}</span>
                  </a>
                )}
                {farm.website && (
                  <a href={farm.website} target="_blank" rel="noopener noreferrer"
                    className="flex items-center gap-2.5 text-gray-600 hover:text-green-700 transition-colors">
                    <Globe className="w-4 h-4 text-gray-400 shrink-0" />
                    <span className="truncate">{farm.website.replace(/^https?:\/\//, '')}</span>
                    <ExternalLink className="w-3 h-3 shrink-0" />
                  </a>
                )}
              </div>
            </div>

            {/* Öffnungszeiten */}
            {farm.opening_hours && Object.keys(farm.opening_hours).length > 0 && (
              <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
                <h2 className="flex items-center gap-2 font-bold text-gray-900 mb-4 text-base">
                  <Clock className="w-4 h-4 text-gray-400" /> Öffnungszeiten
                </h2>
                <div className="space-y-1.5">
                  {Object.entries(farm.opening_hours).map(([day, hours]) => (
                    <div key={day} className="flex items-center justify-between text-sm">
                      <span className="text-gray-500">{WEEKDAYS_DE[day.toLowerCase()] ?? day}</span>
                      <span className="text-gray-900 font-medium">{String(hours)}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Mini Map */}
            {hasCoords && (
              <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
                <FarmDetailMap lat={farm.latitude!} lng={farm.longitude!} name={farm.name} />
              </div>
            )}

            {/* Datenquelle */}
            {farm.source_name && (
              <div className="bg-gray-50 rounded-2xl border border-gray-100 p-4 text-xs text-gray-400">
                <p className="font-medium mb-1">Datenquelle</p>
                <p>{farm.source_name}</p>
                {farm.imported_at && <p>Importiert: {new Date(farm.imported_at).toLocaleDateString('de-AT')}</p>}
                {farm.last_verified_at && <p>Zuletzt verifiziert: {new Date(farm.last_verified_at).toLocaleDateString('de-AT')}</p>}
              </div>
            )}
          </div>
        </div>

        {/* Back */}
        <div className="flex justify-center pt-4">
          <Link href="/dashboard/supply" className="flex items-center gap-2 text-gray-500 hover:text-green-700 text-sm font-medium transition-colors">
            <ArrowLeft className="w-4 h-4" /> Zurück zur Übersicht
          </Link>
        </div>
      </div>
    </div>
  )
}
