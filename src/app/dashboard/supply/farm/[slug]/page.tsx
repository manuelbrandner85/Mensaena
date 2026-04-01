'use client'


import { useEffect, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import dynamic from 'next/dynamic'
import {
  ArrowLeft, MapPin, Phone, Mail, Globe, Clock, Leaf, CheckCircle2,
  Truck, Scissors, ShoppingBag, Share2, Bookmark, ExternalLink,
  Building2, Star, Package, RefreshCw
} from 'lucide-react'
import type { FarmListing } from '@/types/farm'
import { CATEGORY_ICONS, CATEGORY_COLORS, COUNTRY_LABELS } from '@/types/farm'

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

export default function FarmDetailPage() {
  const { slug } = useParams<{ slug: string }>()
  const router = useRouter()
  const [farm, setFarm] = useState<FarmListing | null>(null)
  const [loading, setLoading] = useState(true)
  const [saved, setSaved] = useState(false)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    if (!slug) return
    fetch(`/api/farms/${slug}`)
      .then((r) => r.json())
      .then((d) => setFarm(d.farm || null))
      .catch(() => setFarm(null))
      .finally(() => setLoading(false))
  }, [slug])

  const handleShare = () => {
    if (navigator.share && farm) {
      navigator.share({ title: farm.name, url: window.location.href }).catch(() => {})
    } else {
      navigator.clipboard.writeText(window.location.href)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    }
  }

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
  const categoryIcon = CATEGORY_ICONS[farm.category] ?? '🏡'
  const hasCoords = farm.latitude && farm.longitude

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
            <button
              onClick={() => setSaved(!saved)}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl border text-sm font-medium transition-all ${
                saved
                  ? 'bg-amber-50 border-amber-300 text-amber-700'
                  : 'border-gray-200 text-gray-600 hover:border-amber-300 hover:text-amber-700'
              }`}
            >
              <Bookmark className={`w-4 h-4 ${saved ? 'fill-amber-500' : ''}`} />
              {saved ? 'Gespeichert' : 'Speichern'}
            </button>
            <button
              onClick={handleShare}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-gray-200 text-sm font-medium text-gray-600 hover:border-green-300 hover:text-green-700 transition-all"
            >
              <Share2 className="w-4 h-4" />
              {copied ? 'Kopiert!' : 'Teilen'}
            </button>
          </div>
        </div>
      </div>

      <div className="max-w-5xl mx-auto px-4 sm:px-6 py-8 space-y-6">
        {/* Hero Card */}
        <div className="bg-white rounded-3xl shadow-sm border border-gray-100 overflow-hidden">
          {/* Color banner */}
          <div className="bg-gradient-to-r from-yellow-400 to-amber-500 h-3" />

          <div className="p-6 md:p-8">
            <div className="flex items-start gap-5">
              {/* Icon */}
              <div className="w-16 h-16 bg-gradient-to-br from-amber-100 to-yellow-100 rounded-2xl flex items-center justify-center text-3xl shrink-0 border border-amber-200">
                {categoryIcon}
              </div>

              <div className="flex-1 min-w-0">
                {/* Badges */}
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
                <p className="flex items-center gap-1.5 text-gray-500 text-sm">
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

            {/* Description */}
            {farm.description && (
              <p className="mt-5 text-gray-700 leading-relaxed text-base">{farm.description}</p>
            )}

            {/* Quick Actions */}
            <div className="flex flex-wrap gap-3 mt-6">
              {farm.phone && (
                <a
                  href={`tel:${farm.phone}`}
                  className="flex items-center gap-2 bg-green-600 text-white px-5 py-2.5 rounded-xl font-semibold text-sm hover:bg-green-700 transition-colors"
                >
                  <Phone className="w-4 h-4" /> Anrufen
                </a>
              )}
              {farm.email && (
                <a
                  href={`mailto:${farm.email}`}
                  className="flex items-center gap-2 bg-blue-600 text-white px-5 py-2.5 rounded-xl font-semibold text-sm hover:bg-blue-700 transition-colors"
                >
                  <Mail className="w-4 h-4" /> E-Mail
                </a>
              )}
              {farm.website && (
                <a
                  href={farm.website}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-2 border border-gray-200 text-gray-700 px-5 py-2.5 rounded-xl font-semibold text-sm hover:border-green-300 hover:text-green-700 transition-all"
                >
                  <Globe className="w-4 h-4" /> Website besuchen <ExternalLink className="w-3.5 h-3.5" />
                </a>
              )}
              {hasCoords && (
                <a
                  href={`https://www.google.com/maps/dir/?api=1&destination=${farm.latitude},${farm.longitude}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-2 border border-gray-200 text-gray-700 px-5 py-2.5 rounded-xl font-semibold text-sm hover:border-blue-300 hover:text-blue-700 transition-all"
                >
                  <MapPin className="w-4 h-4" /> Route planen
                </a>
              )}
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
                    <span key={s} className="bg-blue-50 text-blue-800 border border-blue-100 text-sm px-3 py-1.5 rounded-full font-medium">
                      {s}
                    </span>
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
                    <span key={s} className="bg-gray-100 text-gray-700 text-sm px-3 py-1.5 rounded-full">
                      {s}
                    </span>
                  ))}
                </div>
              </div>
            )}
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
                    <Phone className="w-4 h-4 text-gray-400 shrink-0" />
                    {farm.phone}
                  </a>
                )}
                {farm.email && (
                  <a href={`mailto:${farm.email}`} className="flex items-center gap-2.5 text-gray-600 hover:text-green-700 transition-colors">
                    <Mail className="w-4 h-4 text-gray-400 shrink-0" />
                    <span className="break-all">{farm.email}</span>
                  </a>
                )}
                {farm.website && (
                  <a
                    href={farm.website}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-2.5 text-gray-600 hover:text-green-700 transition-colors"
                  >
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

            {/* Quelle */}
            {farm.source_name && (
              <div className="bg-gray-50 rounded-2xl border border-gray-100 p-4 text-xs text-gray-400">
                <p className="font-medium mb-1">Datenquelle</p>
                <p>{farm.source_name}</p>
                {farm.imported_at && (
                  <p>Importiert: {new Date(farm.imported_at).toLocaleDateString('de-AT')}</p>
                )}
                {farm.last_verified_at && (
                  <p>Zuletzt verifiziert: {new Date(farm.last_verified_at).toLocaleDateString('de-AT')}</p>
                )}
              </div>
            )}
          </div>
        </div>

        {/* Back button */}
        <div className="flex justify-center pt-4">
          <Link
            href="/dashboard/supply"
            className="flex items-center gap-2 text-gray-500 hover:text-green-700 text-sm font-medium transition-colors"
          >
            <ArrowLeft className="w-4 h-4" /> Zurück zur Übersicht
          </Link>
        </div>
      </div>
    </div>
  )
}
