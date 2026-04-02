'use client'

import { useEffect, useState, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  Heart, Phone, Mail, Globe, MapPin, Search, Filter,
  Building2, Cat, Soup, Home, ShoppingBag, Shirt,
  Store, PhoneCall, Moon, Users, ExternalLink, ChevronDown,
  AlertTriangle, BookOpen, ShieldCheck, RefreshCw
} from 'lucide-react'
import { cn } from '@/lib/utils'

// ── Typen ──────────────────────────────────────────────────────────────────────
type Country = 'all' | 'DE' | 'AT' | 'CH'
type OrgCategory =
  | 'all' | 'tierheim' | 'tierschutz' | 'suppenkueche' | 'obdachlosenhilfe'
  | 'tafel' | 'kleiderkammer' | 'sozialkaufhaus' | 'krisentelefon'
  | 'notschlafstelle' | 'jugend' | 'senioren' | 'behinderung'
  | 'sucht' | 'fluechtlingshilfe' | 'allgemein'

interface Organization {
  id: string
  name: string
  category: OrgCategory
  description: string | null
  address: string | null
  zip_code: string | null
  city: string
  state: string | null
  country: string
  phone: string | null
  email: string | null
  website: string | null
  opening_hours: string | null
  services: string[] | null
  tags: string[] | null
  is_verified: boolean
}

// ── Kategorie-Konfiguration ────────────────────────────────────────────────────
const CATEGORIES: { value: OrgCategory; label: string; icon: React.ElementType; color: string; bg: string }[] = [
  { value: 'all',              label: 'Alle',              icon: Building2,   color: 'text-gray-600',   bg: 'bg-gray-100' },
  { value: 'tierheim',         label: 'Tierheime',         icon: Cat,         color: 'text-orange-600', bg: 'bg-orange-100' },
  { value: 'tierschutz',       label: 'Tierschutz',        icon: Heart,       color: 'text-red-500',    bg: 'bg-red-100' },
  { value: 'suppenkueche',     label: 'Suppenküchen',      icon: Soup,        color: 'text-yellow-600', bg: 'bg-yellow-100' },
  { value: 'obdachlosenhilfe', label: 'Obdachlosenhilfe',  icon: Home,        color: 'text-blue-600',   bg: 'bg-blue-100' },
  { value: 'tafel',            label: 'Tafeln',            icon: ShoppingBag, color: 'text-green-600',  bg: 'bg-green-100' },
  { value: 'kleiderkammer',    label: 'Kleiderkammern',    icon: Shirt,       color: 'text-purple-600', bg: 'bg-purple-100' },
  { value: 'sozialkaufhaus',   label: 'Sozialkaufhäuser',  icon: Store,       color: 'text-indigo-600', bg: 'bg-indigo-100' },
  { value: 'krisentelefon',    label: 'Krisentelefone',    icon: PhoneCall,   color: 'text-rose-600',   bg: 'bg-rose-100' },
  { value: 'notschlafstelle',  label: 'Notschlafstellen',  icon: Moon,        color: 'text-slate-600',  bg: 'bg-slate-100' },
  { value: 'jugend',           label: 'Jugendhilfe',       icon: Users,       color: 'text-sky-600',    bg: 'bg-sky-100' },
  { value: 'senioren',         label: 'Seniorenhilfe',     icon: Heart,       color: 'text-pink-500',   bg: 'bg-pink-100' },
  { value: 'fluechtlingshilfe',label: 'Flüchtlingshilfe',  icon: ShieldCheck, color: 'text-teal-600',   bg: 'bg-teal-100' },
  { value: 'allgemein',        label: 'Allgemeine Hilfe',  icon: BookOpen,    color: 'text-gray-600',   bg: 'bg-gray-100' },
]

const COUNTRY_FLAGS: Record<string, string> = { DE: '🇩🇪', AT: '🇦🇹', CH: '🇨🇭' }
const COUNTRY_LABELS: Record<string, string> = { DE: 'Deutschland', AT: 'Österreich', CH: 'Schweiz' }

// ── Hilfsfunktionen ────────────────────────────────────────────────────────────
function getCategoryConfig(cat: string) {
  return CATEGORIES.find(c => c.value === cat) ?? CATEGORIES[0]
}

function formatPhone(phone: string) {
  return phone.replace(/\s+/g, '\u00a0')
}

// ── Organisations-Karte ────────────────────────────────────────────────────────
function OrgCard({ org }: { org: Organization }) {
  const [expanded, setExpanded] = useState(false)
  const cat = getCategoryConfig(org.category)
  const Icon = cat.icon

  return (
    <div className={cn(
      'bg-white rounded-2xl border border-gray-100 shadow-sm hover:shadow-md transition-all duration-200 overflow-hidden',
      expanded && 'shadow-md'
    )}>
      {/* Header */}
      <div className="p-4">
        <div className="flex items-start gap-3">
          {/* Icon */}
          <div className={cn('w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0', cat.bg)}>
            <Icon className={cn('w-5 h-5', cat.color)} />
          </div>

          {/* Titel + Badges */}
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

            {/* Kategorie + Ort */}
            <div className="flex items-center gap-2 mt-1 flex-wrap">
              <span className={cn('text-xs px-2 py-0.5 rounded-full font-medium', cat.bg, cat.color)}>
                {cat.label}
              </span>
              <span className="text-xs text-gray-500 flex items-center gap-0.5">
                <MapPin className="w-3 h-3" />
                {org.city}{org.state ? `, ${org.state}` : ''}
              </span>
            </div>
          </div>
        </div>

        {/* Beschreibung */}
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
          {/* Expand-Toggle */}
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
          {org.address && (
            <div className="flex items-start gap-2 text-xs text-gray-600">
              <MapPin className="w-3.5 h-3.5 mt-0.5 text-gray-400 flex-shrink-0" />
              <span>{org.address}, {org.zip_code} {org.city}</span>
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
  const [orgs, setOrgs]           = useState<Organization[]>([])
  const [loading, setLoading]     = useState(true)
  const [error, setError]         = useState<string | null>(null)
  const [search, setSearch]       = useState('')
  const [category, setCategory]   = useState<OrgCategory>('all')
  const [country, setCountry]     = useState<Country>('all')
  const [showFilters, setShowFilters] = useState(false)

  const supabase = createClient()

  const fetchOrgs = useCallback(async () => {
    setLoading(true)
    setError(null)

    let query = supabase
      .from('organizations')
      .select('*')
      .eq('is_active', true)
      .order('name')

    if (category !== 'all')  query = query.eq('category', category)
    if (country  !== 'all')  query = query.eq('country', country)
    if (search.trim())       query = query.or(
      `name.ilike.%${search}%,city.ilike.%${search}%,description.ilike.%${search}%`
    )

    const { data, error: err } = await query
    if (err) {
      setError('Organisationen konnten nicht geladen werden. Bitte die SQL-Migration im Supabase Dashboard ausführen.')
      setOrgs([])
    } else {
      setOrgs(data ?? [])
    }
    setLoading(false)
  }, [category, country, search])

  useEffect(() => { fetchOrgs() }, [fetchOrgs])

  // Zähler pro Land
  const countDE = orgs.filter(o => o.country === 'DE').length
  const countAT = orgs.filter(o => o.country === 'AT').length
  const countCH = orgs.filter(o => o.country === 'CH').length

  return (
    <div className="min-h-screen bg-gray-50">
      {/* ── Hero-Header ──────────────────────────────────────────── */}
      <div className="bg-gradient-to-br from-teal-600 via-teal-500 to-emerald-500 px-4 pt-6 pb-8">
        <div className="max-w-2xl mx-auto">
          <div className="flex items-center gap-2 mb-1">
            <Building2 className="w-6 h-6 text-white/80" />
            <span className="text-white/80 text-sm font-medium">Hilfsverzeichnis</span>
          </div>
          <h1 className="text-2xl font-bold text-white mb-1">
            Hilfsorganisationen
          </h1>
          <p className="text-teal-100 text-sm">
            Tierheime, Suppenküchen, Obdachlosenhilfe, Tafeln und mehr –
            für Deutschland 🇩🇪, Österreich 🇦🇹 und die Schweiz 🇨🇭
          </p>

          {/* Suchfeld */}
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

        {/* ── Länder-Tabs ───────────────────────────────────────────── */}
        <div className="flex gap-2 mb-4 mt-4 overflow-x-auto pb-1">
          {(['all', 'DE', 'AT', 'CH'] as Country[]).map(c => (
            <button
              key={c}
              onClick={() => setCountry(c)}
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

        {/* ── Kategorien-Filter ────────────────────────────────────────── */}
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
              {CATEGORIES.map(cat => {
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

        {/* ── Ergebnis-Zähler ──────────────────────────────────────────── */}
        {!loading && !error && (
          <div className="flex items-center justify-between mb-3">
            <p className="text-sm text-gray-500">
              {orgs.length === 0
                ? 'Keine Einträge gefunden'
                : `${orgs.length} Organisation${orgs.length !== 1 ? 'en' : ''} gefunden`}
            </p>
            {(category !== 'all' || country !== 'all' || search) && (
              <button
                onClick={() => { setCategory('all'); setCountry('all'); setSearch('') }}
                className="flex items-center gap-1 text-xs text-teal-600 hover:text-teal-800"
              >
                <RefreshCw className="w-3 h-3" />
                Filter zurücksetzen
              </button>
            )}
          </div>
        )}

        {/* ── Fehler: Migration fehlt ───────────────────────────────────── */}
        {error && (
          <div className="bg-amber-50 border border-amber-200 rounded-2xl p-4 mb-4">
            <div className="flex items-start gap-3">
              <AlertTriangle className="w-5 h-5 text-amber-500 flex-shrink-0 mt-0.5" />
              <div>
                <p className="font-medium text-amber-800 text-sm">Datenbank-Migration erforderlich</p>
                <p className="text-amber-700 text-xs mt-1">
                  Die Tabelle <code className="bg-amber-100 px-1 rounded">organizations</code> existiert noch nicht.
                  Bitte die Datei <strong>supabase/migrations/008_missing_tables.sql</strong> im
                  Supabase SQL-Editor ausführen.
                </p>
                <a
                  href="https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1 mt-2 text-xs font-medium text-amber-800 underline"
                >
                  Supabase SQL-Editor öffnen
                  <ExternalLink className="w-3 h-3" />
                </a>
              </div>
            </div>
          </div>
        )}

        {/* ── Lade-Spinner ──────────────────────────────────────────────── */}
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

        {/* ── Organisationsliste ────────────────────────────────────────── */}
        {!loading && !error && orgs.length > 0 && (
          <div className="grid grid-cols-1 gap-3 pb-8">
            {orgs.map(org => <OrgCard key={org.id} org={org} />)}
          </div>
        )}

        {/* ── Leer-Zustand ──────────────────────────────────────────────── */}
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
