'use client'

import { useEffect, useState, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  Heart, Phone, Mail, Globe, MapPin, Search, Filter,
  Building2, Cat, Soup, Home, ShoppingBag, Shirt,
  Store, PhoneCall, Moon, Users, ExternalLink, ChevronDown,
  AlertTriangle, BookOpen, ShieldCheck, RefreshCw, Map, List,
  Navigation, X, Info
} from 'lucide-react'
import { cn } from '@/lib/utils'
import dynamic from 'next/dynamic'
import {
  type Organization,
  type Country,
  type OrgCategory,
  CATEGORIES,
  COUNTRY_FLAGS,
  COUNTRY_LABELS,
  getCategoryConfig,
} from './types'

// Leaflet wird nur client-side geladen
const MapView = dynamic(() => import('./MapView'), {
  ssr: false,
  loading: () => (
    <div className="w-full h-full flex items-center justify-center bg-gray-100 rounded-2xl">
      <div className="text-gray-400 text-sm flex items-center gap-2">
        <RefreshCw className="w-4 h-4 animate-spin" />
        Karte wird geladen…
      </div>
    </div>
  )
})

// CATEGORIES mit Icons (Icons können nicht in .ts ohne JSX)
const CATEGORIES_WITH_ICONS = CATEGORIES.map(c => ({
  ...c,
  icon: ({
    all:              Building2,
    tierheim:         Cat,
    tierschutz:       Heart,
    suppenkueche:     Soup,
    obdachlosenhilfe: Home,
    tafel:            ShoppingBag,
    kleiderkammer:    Shirt,
    sozialkaufhaus:   Store,
    krisentelefon:    PhoneCall,
    notschlafstelle:  Moon,
    jugend:           Users,
    senioren:         Heart,
    fluechtlingshilfe:ShieldCheck,
    allgemein:        BookOpen,
  } as Record<string, React.ElementType>)[c.value] ?? Building2
}))

// ── Offizielle Notfallnummern ──────────────────────────────────────────────────
const EMERGENCY_NUMBERS = [
  {
    country: 'DE', flag: '🇩🇪', label: 'Deutschland',
    numbers: [
      { label: 'Notruf / Feuerwehr / Rettung', number: '112',            color: 'bg-red-600',    note: 'EU-weit kostenlos, 24/7' },
      { label: 'Polizei',                       number: '110',            color: 'bg-blue-600',   note: '24/7' },
      { label: 'Ärztlicher Bereitschaftsdienst',number: '116 117',        color: 'bg-green-600',  note: 'Kostenlos, 24/7' },
      { label: 'TelefonSeelsorge (ev.)',         number: '0800 111 0 111', color: 'bg-purple-600', note: 'Kostenlos, 24/7' },
      { label: 'TelefonSeelsorge (kath.)',       number: '0800 111 0 222', color: 'bg-purple-600', note: 'Kostenlos, 24/7' },
      { label: 'TelefonSeelsorge EU',            number: '116 123',        color: 'bg-purple-500', note: 'Kostenlos, 24/7' },
      { label: 'Kinder- & Jugendtelefon',        number: '116 111',        color: 'bg-sky-600',    note: 'Mo–Sa 14–20 Uhr, kostenlos' },
      { label: 'Elterntelefon',                  number: '0800 111 0 550', color: 'bg-sky-500',    note: 'Kostenlos' },
      { label: 'Hilfetelefon Gewalt gg. Frauen', number: '116 016',        color: 'bg-pink-600',   note: 'Kostenlos, 24/7, mehrsprachig' },
      { label: 'Krankentransport',               number: '19 222',         color: 'bg-orange-500', note: 'Regional verschieden' },
    ]
  },
  {
    country: 'AT', flag: '🇦🇹', label: 'Österreich',
    numbers: [
      { label: 'Euro-Notruf',                    number: '112',            color: 'bg-red-600',    note: 'EU-weit, 24/7' },
      { label: 'Feuerwehr',                      number: '122',            color: 'bg-red-500',    note: '24/7' },
      { label: 'Polizei',                        number: '133',            color: 'bg-blue-600',   note: '24/7' },
      { label: 'Rettung / Ambulanz',             number: '144',            color: 'bg-green-600',  note: '24/7' },
      { label: 'Bergrettung',                    number: '140',            color: 'bg-orange-500', note: '24/7' },
      { label: 'Ärztenotdienst',                 number: '141',            color: 'bg-green-500',  note: '24/7' },
      { label: 'Telefonseelsorge',               number: '142',            color: 'bg-purple-600', note: 'Kostenlos, 24/7' },
      { label: 'Rat auf Draht (Kinder/Jugend)',  number: '147',            color: 'bg-sky-600',    note: 'Kostenlos, 24/7' },
      { label: 'Frauenhelpline gegen Gewalt',    number: '0800 222 555',   color: 'bg-pink-600',   note: 'Kostenlos, 24/7' },
      { label: 'Vergiftungsinfo (VIZ)',           number: '01 406 43 43',   color: 'bg-amber-600',  note: '24/7' },
      { label: 'Gasgebrechen',                   number: '128',            color: 'bg-yellow-500', note: '24/7' },
    ]
  },
  {
    country: 'CH', flag: '🇨🇭', label: 'Schweiz',
    numbers: [
      { label: 'Euro-Notruf',                    number: '112',            color: 'bg-red-600',    note: 'EU-weit, 24/7' },
      { label: 'Polizei',                        number: '117',            color: 'bg-blue-600',   note: '24/7' },
      { label: 'Feuerwehr',                      number: '118',            color: 'bg-red-500',    note: '24/7' },
      { label: 'Sanität / Rettungsdienst',       number: '144',            color: 'bg-green-600',  note: '24/7' },
      { label: 'REGA (Rettungshelikopter)',       number: '1414',           color: 'bg-orange-500', note: '24/7' },
      { label: 'Die Dargebotene Hand',            number: '143',            color: 'bg-purple-600', note: 'Kostenlos, 24/7' },
      { label: 'Dargebotene Hand (EN)',           number: '0800 143 000',   color: 'bg-purple-500', note: 'Kostenlos' },
      { label: 'Tox Info Suisse (Vergiftungen)', number: '145',            color: 'bg-amber-600',  note: '24/7, kostenlos' },
      { label: '147.ch (Kinder & Jugend)',        number: '147',            color: 'bg-sky-600',    note: 'Kostenlos, 24/7' },
      { label: 'Pannenhilfe TCS',                number: '0800 140 140',   color: 'bg-yellow-600', note: '24/7' },
    ]
  }
]

// ── Hilfsfunktionen ────────────────────────────────────────────────────────────
function formatPhone(phone: string) {
  return phone.replace(/\s+/g, '\u00a0')
}

function getMapsUrl(org: Organization): string {
  if (org.latitude && org.longitude) {
    return `https://www.google.com/maps?q=${org.latitude},${org.longitude}`
  }
  const addr = [org.address, org.zip_code, org.city, org.country].filter(Boolean).join(' ')
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(addr)}`
}

function getOsmUrl(org: Organization): string {
  if (org.latitude && org.longitude) {
    return `https://www.openstreetmap.org/?mlat=${org.latitude}&mlon=${org.longitude}&zoom=16`
  }
  const addr = [org.address, org.zip_code, org.city].filter(Boolean).join(', ')
  return `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(addr + ', ' + org.country)}&format=html`
}

// ── Notfallnummern Panel ───────────────────────────────────────────────────────
function EmergencyPanel({ countryFilter }: { countryFilter: Country }) {
  const [open, setOpen] = useState(false)
  const filtered = countryFilter === 'all'
    ? EMERGENCY_NUMBERS
    : EMERGENCY_NUMBERS.filter(e => e.country === countryFilter)

  return (
    <div className="mb-4">
      <button
        onClick={() => setOpen(o => !o)}
        className={cn(
          'w-full flex items-center gap-2 text-sm font-medium px-4 py-2.5 rounded-xl border transition-all',
          open
            ? 'bg-red-50 border-red-200 text-red-700'
            : 'bg-white border-gray-200 text-gray-600 hover:bg-red-50 hover:border-red-200 hover:text-red-700'
        )}
      >
        <PhoneCall className="w-4 h-4" />
        <span>Offizielle Notfall- & Krisentelefone</span>
        <span className="ml-auto text-xs bg-red-100 text-red-700 px-1.5 py-0.5 rounded-full font-semibold">Notruf</span>
        <ChevronDown className={cn('w-3.5 h-3.5 transition-transform', open && 'rotate-180')} />
      </button>

      {open && (
        <div className="mt-2 bg-white border border-gray-100 rounded-2xl shadow-sm overflow-hidden">
          <div className="p-3 bg-red-50 border-b border-red-100 flex items-start gap-2">
            <Info className="w-4 h-4 text-red-500 flex-shrink-0 mt-0.5" />
            <p className="text-xs text-red-700">
              Alle Nummern offiziell verifiziert (Quellen: oesterreich.gv.at, polizei.gv.at, ch.ch, BRK, DRK).
              Notrufnummern sind kostenlos und 24/7 erreichbar.
            </p>
          </div>
          <div className="divide-y divide-gray-50">
            {filtered.map(country => (
              <div key={country.country} className="p-3">
                <div className="flex items-center gap-2 mb-2">
                  <span className="text-lg">{country.flag}</span>
                  <span className="font-semibold text-gray-800 text-sm">{country.label}</span>
                </div>
                <div className="grid grid-cols-1 gap-1">
                  {country.numbers.map(n => (
                    <a
                      key={n.number + n.label}
                      href={`tel:${n.number.replace(/\s/g, '')}`}
                      className="flex items-center gap-2.5 p-2 rounded-xl hover:bg-gray-50 transition-colors group"
                    >
                      <span className={cn(
                        'text-white text-xs font-bold px-2 py-1 rounded-lg min-w-[4.5rem] text-center tabular-nums',
                        n.color
                      )}>
                        {n.number}
                      </span>
                      <div className="flex-1 min-w-0">
                        <p className="text-xs font-medium text-gray-800 leading-tight">{n.label}</p>
                        <p className="text-xs text-gray-400">{n.note}</p>
                      </div>
                      <Phone className="w-3.5 h-3.5 text-gray-300 group-hover:text-teal-500 flex-shrink-0 transition-colors" />
                    </a>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

// ── Organisations-Karte ────────────────────────────────────────────────────────
function OrgCard({ org, onShowOnMap }: { org: Organization; onShowOnMap?: (org: Organization) => void }) {
  const [expanded, setExpanded] = useState(false)
  const cat = getCategoryConfig(org.category)
  const catWithIcon = CATEGORIES_WITH_ICONS.find(c => c.value === org.category) ?? CATEGORIES_WITH_ICONS[0]
  const Icon = catWithIcon.icon

  return (
    <div className={cn(
      'bg-white rounded-2xl border border-gray-100 shadow-sm hover:shadow-md transition-all duration-200 overflow-hidden',
      expanded && 'shadow-md'
    )}>
      {/* Header */}
      <div className="p-4">
        <div className="flex items-start gap-3">
          <div className={cn('w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0', cat.bg)}>
            <Icon className={cn('w-5 h-5', cat.color)} />
          </div>

          <div className="flex-1 min-w-0">
            <div className="flex items-start justify-between gap-2">
              <h3 className="font-semibold text-gray-900 text-sm leading-snug line-clamp-2">
                {org.name}
              </h3>
              <div className="flex items-center gap-1 flex-shrink-0">
                {org.is_verified && (
                  <span className="text-xs bg-green-100 text-green-700 px-1.5 py-0.5 rounded-full font-medium">✓</span>
                )}
                <span className="text-lg leading-none">{COUNTRY_FLAGS[org.country]}</span>
              </div>
            </div>

            <div className="flex items-center gap-2 mt-1 flex-wrap">
              <span className={cn('text-xs px-2 py-0.5 rounded-full font-medium', cat.bg, cat.color)}>
                {cat.label}
              </span>
              {/* Standort – anklickbar → Google Maps */}
              <a
                href={getMapsUrl(org)}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs text-gray-500 flex items-center gap-0.5 hover:text-teal-600 hover:underline transition-colors"
                title="In Google Maps öffnen"
              >
                <MapPin className="w-3 h-3" />
                {org.city}{org.state ? `, ${org.state}` : ''}
                <ExternalLink className="w-2.5 h-2.5 opacity-40" />
              </a>
            </div>
          </div>
        </div>

        {org.description && (
          <p className="text-xs text-gray-600 mt-2 leading-relaxed line-clamp-2">
            {org.description}
          </p>
        )}

        {/* Schnell-Kontakt */}
        <div className="flex items-center gap-2 mt-3 flex-wrap">
          {org.phone && (
            <a href={`tel:${org.phone.replace(/\s/g, '')}`}
               className="flex items-center gap-1 text-xs bg-blue-50 text-blue-700 hover:bg-blue-100 px-2.5 py-1 rounded-full transition-colors font-medium">
              <Phone className="w-3 h-3" />
              {formatPhone(org.phone)}
            </a>
          )}
          {org.website && (
            <a href={org.website} target="_blank" rel="noopener noreferrer"
               className="flex items-center gap-1 text-xs bg-gray-50 text-gray-600 hover:bg-gray-100 px-2.5 py-1 rounded-full transition-colors">
              <Globe className="w-3 h-3" />
              Website
              <ExternalLink className="w-2.5 h-2.5" />
            </a>
          )}
          {org.email && (
            <a href={`mailto:${org.email}`}
               className="flex items-center gap-1 text-xs bg-gray-50 text-gray-600 hover:bg-gray-100 px-2.5 py-1 rounded-full transition-colors">
              <Mail className="w-3 h-3" />
              E-Mail
            </a>
          )}
          {onShowOnMap && (
            <button
              onClick={() => onShowOnMap(org)}
              className="flex items-center gap-1 text-xs bg-teal-50 text-teal-700 hover:bg-teal-100 px-2.5 py-1 rounded-full transition-colors"
            >
              <Navigation className="w-3 h-3" />
              Karte
            </button>
          )}
          <button
            onClick={() => setExpanded(e => !e)}
            className="flex items-center gap-1 text-xs text-gray-400 hover:text-gray-600 px-2 py-1 rounded-full ml-auto transition-colors"
          >
            <ChevronDown className={cn('w-3.5 h-3.5 transition-transform', expanded && 'rotate-180')} />
            {expanded ? 'Weniger' : 'Mehr'}
          </button>
        </div>
      </div>

      {/* Expandierter Bereich */}
      {expanded && (
        <div className="border-t border-gray-50 bg-gray-50/50 px-4 py-3 space-y-2">
          {(org.address || org.city) && (
            <div className="flex items-start gap-2 text-xs text-gray-600">
              <MapPin className="w-3.5 h-3.5 mt-0.5 text-gray-400 flex-shrink-0" />
              <div className="flex-1">
                {org.address
                  ? <span>{org.address}, {org.zip_code} {org.city}</span>
                  : <span>{org.city}{org.country ? `, ${org.country}` : ''}</span>
                }
                <div className="flex gap-3 mt-1">
                  <a href={getMapsUrl(org)} target="_blank" rel="noopener noreferrer"
                     className="text-teal-600 hover:underline flex items-center gap-0.5">
                    <Navigation className="w-3 h-3" /> Google Maps
                  </a>
                  <a href={getOsmUrl(org)} target="_blank" rel="noopener noreferrer"
                     className="text-teal-600 hover:underline flex items-center gap-0.5">
                    <Map className="w-3 h-3" /> OpenStreetMap
                  </a>
                </div>
              </div>
            </div>
          )}
          {org.opening_hours && (
            <div className="flex items-start gap-2 text-xs text-gray-600">
              <span className="text-gray-400 flex-shrink-0 mt-0.5">🕒</span>
              <span>{org.opening_hours}</span>
            </div>
          )}
          {org.services && org.services.length > 0 && (
            <div className="flex flex-wrap gap-1 pt-1">
              {org.services.map(s => (
                <span key={s} className="text-xs bg-white border border-gray-200 text-gray-600 px-2 py-0.5 rounded-full">
                  {s}
                </span>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

// ── Hauptkomponente ────────────────────────────────────────────────────────────
export default function OrganizationsPage() {
  const [orgs, setOrgs]               = useState<Organization[]>([])
  const [loading, setLoading]         = useState(true)
  const [error, setError]             = useState<string | null>(null)
  const [search, setSearch]           = useState('')
  const [category, setCategory]       = useState<OrgCategory>('all')
  const [country, setCountry]         = useState<Country>('all')
  const [showFilters, setShowFilters] = useState(false)
  const [viewMode, setViewMode]       = useState<'list' | 'map'>('list')
  const [selectedOrg, setSelectedOrg] = useState<Organization | null>(null)

  const supabase = createClient()

  const fetchOrgs = useCallback(async () => {
    setLoading(true)
    setError(null)

    let query = supabase
      .from('organizations')
      .select('*')
      .eq('is_active', true)
      .order('name')

    if (category !== 'all') query = query.eq('category', category)
    if (country  !== 'all') query = query.eq('country', country)
    if (search.trim())      query = query.or(
      `name.ilike.%${search}%,city.ilike.%${search}%,description.ilike.%${search}%`
    )

    const { data, error: err } = await query
    if (err) {
      setError('Organisationen konnten nicht geladen werden.')
      setOrgs([])
    } else {
      setOrgs(data ?? [])
    }
    setLoading(false)
  }, [category, country, search])

  useEffect(() => { fetchOrgs() }, [fetchOrgs])

  const handleShowOnMap = useCallback((org: Organization) => {
    setSelectedOrg(org)
    setViewMode('map')
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }, [])

  const countDE = orgs.filter(o => o.country === 'DE').length
  const countAT = orgs.filter(o => o.country === 'AT').length
  const countCH = orgs.filter(o => o.country === 'CH').length
  const orgsWithCoords = orgs.filter(o => o.latitude && o.longitude)

  return (
    <div className="min-h-screen bg-gray-50">
      {/* ── Hero-Header ────────────────────────────────── */}
      <div className="bg-gradient-to-br from-teal-600 via-teal-500 to-emerald-500 px-4 pt-6 pb-8">
        <div className="max-w-2xl mx-auto">
          <div className="flex items-center gap-2 mb-1">
            <Building2 className="w-6 h-6 text-white/80" />
            <span className="text-white/80 text-sm font-medium">Hilfsverzeichnis</span>
          </div>
          <h1 className="text-2xl font-bold text-white mb-1">Hilfsorganisationen</h1>
          <p className="text-teal-100 text-sm">
            Tierheime, Suppenküchen, Obdachlosenhilfe, Tafeln und mehr –
            für Deutschland 🇩🇪, Österreich 🇦🇹 und die Schweiz 🇨🇭
          </p>
          <div className="relative mt-4">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              type="text"
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Organisation, Stadt oder Stichwort suchen…"
              className="w-full pl-9 pr-4 py-3 rounded-xl bg-white text-gray-800 placeholder-gray-400 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-teal-300"
            />
          </div>
        </div>
      </div>

      <div className="max-w-2xl mx-auto px-4 -mt-2">
        {/* ── Länder-Tabs ─────────────────────────────── */}
        <div className="flex gap-2 mb-4 mt-4 overflow-x-auto pb-1">
          {(['all', 'DE', 'AT', 'CH'] as Country[]).map(c => (
            <button key={c} onClick={() => setCountry(c)}
              className={cn(
                'flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium whitespace-nowrap transition-all border',
                country === c
                  ? 'bg-teal-600 text-white border-teal-600 shadow-sm'
                  : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'
              )}
            >
              {c === 'all' ? '🌍 Alle Länder' : `${COUNTRY_FLAGS[c]} ${COUNTRY_LABELS[c]}`}
              {c !== 'all' && country === 'all' && (
                <span className="bg-white/30 text-white rounded-full px-1 text-xs">
                  {c === 'DE' ? countDE : c === 'AT' ? countAT : countCH}
                </span>
              )}
            </button>
          ))}
        </div>

        {/* ── Kategorien-Filter ──────────────────────── */}
        <div className="mb-4">
          <button
            onClick={() => setShowFilters(f => !f)}
            className={cn(
              'flex items-center gap-2 text-sm font-medium px-3 py-2 rounded-xl border transition-all',
              showFilters ? 'bg-teal-50 border-teal-200 text-teal-700' : 'bg-white border-gray-200 text-gray-600 hover:bg-gray-50'
            )}
          >
            <Filter className="w-4 h-4" />
            Kategorie filtern
            {category !== 'all' && (
              <span className="bg-teal-600 text-white text-xs px-1.5 py-0.5 rounded-full">
                {getCategoryConfig(category).label}
              </span>
            )}
            <ChevronDown className={cn('w-3.5 h-3.5 ml-auto transition-transform', showFilters && 'rotate-180')} />
          </button>

          {showFilters && (
            <div className="mt-2 p-3 bg-white border border-gray-100 rounded-2xl shadow-sm grid grid-cols-2 gap-1.5">
              {CATEGORIES_WITH_ICONS.map(cat => {
                const CatIcon = cat.icon
                return (
                  <button
                    key={cat.value}
                    onClick={() => { setCategory(cat.value); setShowFilters(false) }}
                    className={cn(
                      'flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-medium transition-all text-left',
                      category === cat.value
                        ? `${cat.bg} ${cat.color} ring-1 ring-current/20`
                        : 'hover:bg-gray-50 text-gray-700'
                    )}
                  >
                    <CatIcon className={cn('w-3.5 h-3.5 flex-shrink-0', category === cat.value ? cat.color : 'text-gray-400')} />
                    {cat.label}
                  </button>
                )
              })}
            </div>
          )}
        </div>

        {/* ── Notfallnummern Panel ─────────────────────── */}
        <EmergencyPanel countryFilter={country} />

        {/* ── View Toggle ─────────────────────────────── */}
        {!error && (
          <div className="flex items-center gap-2 mb-4">
            <div className="flex bg-white border border-gray-200 rounded-xl overflow-hidden">
              <button
                onClick={() => setViewMode('list')}
                className={cn(
                  'flex items-center gap-1.5 px-3 py-2 text-xs font-medium transition-all',
                  viewMode === 'list' ? 'bg-teal-600 text-white' : 'text-gray-600 hover:bg-gray-50'
                )}
              >
                <List className="w-3.5 h-3.5" />
                Liste
              </button>
              <button
                onClick={() => setViewMode('map')}
                className={cn(
                  'flex items-center gap-1.5 px-3 py-2 text-xs font-medium transition-all',
                  viewMode === 'map' ? 'bg-teal-600 text-white' : 'text-gray-600 hover:bg-gray-50'
                )}
              >
                <Map className="w-3.5 h-3.5" />
                Karte
                {orgsWithCoords.length > 0 && (
                  <span className={cn(
                    'text-xs px-1.5 py-0.5 rounded-full font-semibold',
                    viewMode === 'map' ? 'bg-white/20 text-white' : 'bg-teal-100 text-teal-700'
                  )}>
                    {orgsWithCoords.length}
                  </span>
                )}
              </button>
            </div>
            {!loading && (
              <p className="text-sm text-gray-500 flex-1">
                {orgs.length === 0 ? 'Keine Einträge' : `${orgs.length} Organisation${orgs.length !== 1 ? 'en' : ''}`}
              </p>
            )}
            {(category !== 'all' || country !== 'all' || search) && (
              <button
                onClick={() => { setCategory('all'); setCountry('all'); setSearch('') }}
                className="flex items-center gap-1 text-xs text-teal-600 hover:text-teal-800"
              >
                <RefreshCw className="w-3 h-3" />
                Zurücksetzen
              </button>
            )}
          </div>
        )}

        {/* ── Fehler ──────────────────────────────────── */}
        {error && (
          <div className="bg-amber-50 border border-amber-200 rounded-2xl p-4 mb-4">
            <div className="flex items-start gap-3">
              <AlertTriangle className="w-5 h-5 text-amber-500 flex-shrink-0 mt-0.5" />
              <div>
                <p className="font-medium text-amber-800 text-sm">Datenbank-Migration erforderlich</p>
                <p className="text-amber-700 text-xs mt-1">
                  Die Tabelle <code className="bg-amber-100 px-1 rounded">organizations</code> existiert noch nicht.
                  Bitte die SQL-Migration im Supabase SQL-Editor ausführen.
                </p>
                <a href="https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new"
                   target="_blank" rel="noopener noreferrer"
                   className="inline-flex items-center gap-1 mt-2 text-xs font-medium text-amber-800 underline">
                  Supabase SQL-Editor öffnen <ExternalLink className="w-3 h-3" />
                </a>
              </div>
            </div>
          </div>
        )}

        {/* ── Lade-Spinner ─────────────────────────────── */}
        {loading && (
          <div className="grid grid-cols-1 gap-3">
            {[...Array(6)].map((_, i) => (
              <div key={i} className="bg-white rounded-2xl border border-gray-100 p-4 animate-pulse">
                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 bg-gray-100 rounded-xl flex-shrink-0" />
                  <div className="flex-1">
                    <div className="h-4 bg-gray-100 rounded w-3/4 mb-2" />
                    <div className="h-3 bg-gray-50 rounded w-1/2" />
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* ── KARTENANSICHT ───────────────────────────── */}
        {!loading && !error && viewMode === 'map' && (
          <div className="pb-8">
            {selectedOrg && (
              <div className="mb-2 flex items-center gap-2 bg-teal-50 border border-teal-200 rounded-xl px-3 py-2">
                <Navigation className="w-3.5 h-3.5 text-teal-600 flex-shrink-0" />
                <span className="text-xs text-teal-700 font-medium flex-1">Fokus: {selectedOrg.name}</span>
                <button onClick={() => setSelectedOrg(null)} className="text-teal-400 hover:text-teal-700">
                  <X className="w-3.5 h-3.5" />
                </button>
              </div>
            )}
            {orgsWithCoords.length === 0 ? (
              <div className="bg-white rounded-2xl border border-gray-100 p-8 text-center">
                <Map className="w-10 h-10 text-gray-300 mx-auto mb-3" />
                <p className="text-gray-500 font-medium text-sm">Keine Koordinaten verfügbar</p>
                <p className="text-gray-400 text-xs mt-1">
                  Nutze in der Listenansicht den &quot;Karte&quot;-Button oder den Standort-Link.
                </p>
              </div>
            ) : (
              <div className="rounded-2xl overflow-hidden border border-gray-200 shadow-sm" style={{ height: '520px' }}>
                <MapView orgs={orgsWithCoords} selectedOrg={selectedOrg} onOrgSelect={setSelectedOrg} />
              </div>
            )}
            <p className="text-xs text-gray-400 text-center mt-2">
              {orgsWithCoords.length} von {orgs.length} Organisationen mit GPS-Koordinaten
            </p>
          </div>
        )}

        {/* ── LISTENANSICHT ───────────────────────────── */}
        {!loading && !error && viewMode === 'list' && orgs.length > 0 && (
          <div className="grid grid-cols-1 gap-3 pb-8">
            {orgs.map(org => (
              <OrgCard key={org.id} org={org} onShowOnMap={handleShowOnMap} />
            ))}
          </div>
        )}

        {/* ── Leer-Zustand ────────────────────────────── */}
        {!loading && !error && orgs.length === 0 && (
          <div className="text-center py-12">
            <Building2 className="w-10 h-10 text-gray-300 mx-auto mb-3" />
            <p className="text-gray-500 font-medium">Keine Organisationen gefunden</p>
            <p className="text-gray-400 text-sm mt-1">Versuche andere Suchbegriffe oder Filter</p>
          </div>
        )}
      </div>
    </div>
  )
}
