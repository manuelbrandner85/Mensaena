// ============================================================================
// HILFSORGANISATIONEN – Types & Config
// ============================================================================

import {
  Building2, Heart, Cat, Soup, Home, ShoppingBag, Shirt,
  Store, PhoneCall, Moon, Users, Accessibility,
  ShieldCheck, BookOpen, Stethoscope, HandHeart,
  type LucideIcon,
} from 'lucide-react'

// ── Enums / Literals ──────────────────────────────────────────────────────

export type OrganizationCategory =
  | 'tierheim' | 'tierschutz' | 'suppenkueche' | 'obdachlosenhilfe'
  | 'tafel' | 'kleiderkammer' | 'sozialkaufhaus' | 'krisentelefon'
  | 'notschlafstelle' | 'jugend' | 'senioren' | 'behinderung'
  | 'sucht' | 'fluechtlingshilfe' | 'allgemein'

export type OrganizationStatus = 'active' | 'inactive' | 'pending'

export type SuggestionStatus = 'pending' | 'approved' | 'rejected'

export type ReviewSortOption = 'newest' | 'oldest' | 'highest' | 'lowest'

// ── OpeningHours JSONB ───────────────────────────────────────────────────

export interface DayHours {
  open: string // e.g. "08:00"
  close: string // e.g. "17:00"
  closed?: boolean
}

export interface OpeningHours {
  monday?: DayHours
  tuesday?: DayHours
  wednesday?: DayHours
  thursday?: DayHours
  friday?: DayHours
  saturday?: DayHours
  sunday?: DayHours
  holidays?: DayHours
  notes?: string
}

// ── AccessibilityInfo JSONB ──────────────────────────────────────────────

export interface AccessibilityInfo {
  wheelchair?: boolean
  elevator?: boolean
  blind_friendly?: boolean
  deaf_friendly?: boolean
  parking?: boolean
  public_transport?: boolean
  barrier_free_entrance?: boolean
  accessible_toilet?: boolean
  notes?: string
}

// ── DB Row Types ─────────────────────────────────────────────────────────

export interface Organization {
  id: string
  slug: string
  name: string
  short_description: string | null
  description: string | null
  category: OrganizationCategory
  logo_url: string | null
  cover_image_url: string | null
  address: string | null
  zip_code: string | null
  city: string
  state: string | null
  country: string
  latitude: number | null
  longitude: number | null
  phone: string | null
  fax: string | null
  email: string | null
  website: string | null
  opening_hours_text: string | null
  opening_hours: OpeningHours | null
  accessibility: AccessibilityInfo | null
  services: string[]
  target_groups: string[]
  languages: string[]
  tags: string[]
  is_verified: boolean
  is_active: boolean
  is_emergency: boolean
  rating_avg: number
  rating_count: number
  source_url: string | null
  created_by: string | null
  created_at: string
  updated_at: string
  // computed / joined
  distance_km?: number
}

export interface OrganizationReview {
  id: string
  organization_id: string
  user_id: string
  rating: number
  title: string | null
  content: string
  is_reported: boolean
  report_reason: string | null
  admin_response: string | null
  admin_response_at: string | null
  helpful_count: number
  created_at: string
  updated_at: string
  // joined
  profiles?: {
    name: string | null
    display_name?: string | null
    avatar_url: string | null
  }
  // client-side
  user_found_helpful?: boolean
}

export interface OrganizationSuggestion {
  id: string
  user_id: string
  name: string
  description: string | null
  category: OrganizationCategory
  address: string | null
  city: string | null
  country: string
  phone: string | null
  email: string | null
  website: string | null
  status: SuggestionStatus
  admin_notes: string | null
  created_at: string
  // joined
  profiles?: {
    name: string | null
    avatar_url: string | null
  }
}

export interface OrganizationStats {
  total_organizations: number
  verified_count: number
  total_reviews: number
  avg_rating: number
  categories: { category: string; count: number }[]
}

// ── Input Types ──────────────────────────────────────────────────────────

export interface CreateReviewInput {
  organization_id: string
  rating: number
  title?: string
  content: string
}

export interface UpdateReviewInput {
  rating?: number
  title?: string
  content?: string
}

export interface CreateSuggestionInput {
  name: string
  description?: string
  category: OrganizationCategory
  address?: string
  city?: string
  country: string
  phone?: string
  email?: string
  website?: string
}

// ── Filters ──────────────────────────────────────────────────────────────

export interface OrganizationFilter {
  search: string
  category: OrganizationCategory | 'all'
  country: 'all' | 'DE' | 'AT' | 'CH'
  verified_only: boolean
  is_emergency: boolean
  has_reviews: boolean
  min_rating: number
  sort_by: 'name' | 'rating' | 'distance' | 'newest'
  latitude?: number
  longitude?: number
  radius_km: number
}

// ── Constants ────────────────────────────────────────────────────────────

export const PAGE_SIZE = 200
export const REVIEW_PAGE_SIZE = 10

// ── Category Config ──────────────────────────────────────────────────────

export interface CategoryConfig {
  value: OrganizationCategory
  label: string
  icon: LucideIcon
  color: string
  bg: string
  markerColor: string
}

export const ORGANIZATION_CATEGORY_CONFIG: CategoryConfig[] = [
  { value: 'tierheim',         label: 'Tierheime',           icon: Cat,           color: 'text-orange-600', bg: 'bg-orange-100', markerColor: '#EA580C' },
  { value: 'tierschutz',      label: 'Tierschutz',          icon: Heart,         color: 'text-red-500',    bg: 'bg-red-100',    markerColor: '#EF4444' },
  { value: 'suppenkueche',    label: 'Suppenkuechen',       icon: Soup,          color: 'text-yellow-600', bg: 'bg-yellow-100', markerColor: '#CA8A04' },
  { value: 'obdachlosenhilfe',label: 'Obdachlosenhilfe',    icon: Home,          color: 'text-blue-600',   bg: 'bg-blue-100',   markerColor: '#2563EB' },
  { value: 'tafel',           label: 'Tafeln',              icon: ShoppingBag,   color: 'text-green-600',  bg: 'bg-green-100',  markerColor: '#16A34A' },
  { value: 'kleiderkammer',   label: 'Kleiderkammern',      icon: Shirt,         color: 'text-purple-600', bg: 'bg-purple-100', markerColor: '#9333EA' },
  { value: 'sozialkaufhaus',  label: 'Sozialkaufhaeuser',   icon: Store,         color: 'text-indigo-600', bg: 'bg-indigo-100', markerColor: '#4F46E5' },
  { value: 'krisentelefon',   label: 'Krisentelefone',      icon: PhoneCall,     color: 'text-rose-600',   bg: 'bg-rose-100',   markerColor: '#E11D48' },
  { value: 'notschlafstelle', label: 'Notschlafstellen',    icon: Moon,          color: 'text-slate-600',  bg: 'bg-slate-100',  markerColor: '#475569' },
  { value: 'jugend',          label: 'Jugendhilfe',         icon: Users,         color: 'text-sky-600',    bg: 'bg-sky-100',    markerColor: '#0284C7' },
  { value: 'senioren',        label: 'Seniorenhilfe',       icon: HandHeart,     color: 'text-pink-500',   bg: 'bg-pink-100',   markerColor: '#EC4899' },
  { value: 'behinderung',     label: 'Behindertenhilfe',    icon: Accessibility, color: 'text-cyan-600',   bg: 'bg-cyan-100',   markerColor: '#0891B2' },
  { value: 'sucht',           label: 'Suchthilfe',          icon: Stethoscope,   color: 'text-amber-600',  bg: 'bg-amber-100',  markerColor: '#D97706' },
  { value: 'fluechtlingshilfe',label: 'Fluechtlingshilfe',  icon: ShieldCheck,   color: 'text-teal-600',   bg: 'bg-teal-100',   markerColor: '#0D9488' },
  { value: 'allgemein',       label: 'Allgemeine Hilfe',    icon: BookOpen,      color: 'text-ink-600',   bg: 'bg-stone-100',   markerColor: '#4B5563' },
]

export function getCategoryConfig(cat: string): CategoryConfig {
  return ORGANIZATION_CATEGORY_CONFIG.find(c => c.value === cat) ?? ORGANIZATION_CATEGORY_CONFIG[ORGANIZATION_CATEGORY_CONFIG.length - 1]
}

// ── Target Groups Options ────────────────────────────────────────────────

export const TARGET_GROUPS_OPTIONS = [
  { value: 'kinder', label: 'Kinder' },
  { value: 'jugendliche', label: 'Jugendliche' },
  { value: 'erwachsene', label: 'Erwachsene' },
  { value: 'senioren', label: 'Senioren' },
  { value: 'familien', label: 'Familien' },
  { value: 'alleinerziehende', label: 'Alleinerziehende' },
  { value: 'obdachlose', label: 'Obdachlose' },
  { value: 'gefluechtete', label: 'Gefluechtete' },
  { value: 'menschen_mit_behinderung', label: 'Menschen mit Behinderung' },
  { value: 'suchtkranke', label: 'Suchtkranke' },
  { value: 'frauen', label: 'Frauen' },
  { value: 'maenner', label: 'Maenner' },
  { value: 'lgbtq', label: 'LGBTQ+' },
  { value: 'tiere', label: 'Tiere' },
  { value: 'alle', label: 'Alle' },
]

// ── Services Options ─────────────────────────────────────────────────────

export const SERVICES_OPTIONS = [
  { value: 'beratung', label: 'Beratung' },
  { value: 'unterkunft', label: 'Unterkunft' },
  { value: 'essen', label: 'Essen & Getraenke' },
  { value: 'kleidung', label: 'Kleidung' },
  { value: 'medizin', label: 'Medizinische Versorgung' },
  { value: 'psychologisch', label: 'Psychologische Hilfe' },
  { value: 'rechtlich', label: 'Rechtsberatung' },
  { value: 'bildung', label: 'Bildung & Kurse' },
  { value: 'sprache', label: 'Sprachkurse' },
  { value: 'arbeit', label: 'Arbeitsvermittlung' },
  { value: 'finanziell', label: 'Finanzielle Hilfe' },
  { value: 'transport', label: 'Transport' },
  { value: 'kinderbetreuung', label: 'Kinderbetreuung' },
  { value: 'notfallhilfe', label: 'Notfallhilfe' },
  { value: 'seelsorge', label: 'Seelsorge' },
  { value: 'tierrettung', label: 'Tierrettung' },
  { value: 'tiervermittlung', label: 'Tiervermittlung' },
  { value: 'sachspenden', label: 'Sachspenden-Annahme' },
]

// ── Accessibility Options ────────────────────────────────────────────────

export const ACCESSIBILITY_OPTIONS = [
  { key: 'wheelchair' as const, label: 'Rollstuhlgerecht', icon: '♿' },
  { key: 'elevator' as const, label: 'Aufzug vorhanden', icon: '🛗' },
  { key: 'blind_friendly' as const, label: 'Blindenfreundlich', icon: '👁' },
  { key: 'deaf_friendly' as const, label: 'Gehoerlosenfreundlich', icon: '🦻' },
  { key: 'parking' as const, label: 'Behindertenparkplatz', icon: '🅿' },
  { key: 'public_transport' as const, label: 'OEPNV-Anbindung', icon: '🚌' },
  { key: 'barrier_free_entrance' as const, label: 'Barrierefreier Eingang', icon: '🚪' },
  { key: 'accessible_toilet' as const, label: 'Barrierefreie Toilette', icon: '🚻' },
]

// ── Days Map ─────────────────────────────────────────────────────────────

export const DAYS_MAP: Record<string, string> = {
  monday: 'Montag',
  tuesday: 'Dienstag',
  wednesday: 'Mittwoch',
  thursday: 'Donnerstag',
  friday: 'Freitag',
  saturday: 'Samstag',
  sunday: 'Sonntag',
  holidays: 'Feiertage',
}

// ── Helper: isCurrentlyOpen ──────────────────────────────────────────────

export function isCurrentlyOpen(hours: OpeningHours | null): 'open' | 'closed' | 'unknown' {
  if (!hours) return 'unknown'

  const now = new Date()
  const dayIndex = now.getDay() // 0=Sun, 1=Mon, ...
  const dayKeys = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday']
  const todayKey = dayKeys[dayIndex] as keyof OpeningHours

  const todayHours = hours[todayKey] as DayHours | undefined
  if (!todayHours || todayHours.closed) return 'closed'

  const nowMinutes = now.getHours() * 60 + now.getMinutes()
  const [oh, om] = (todayHours.open || '00:00').split(':').map(Number)
  const [ch, cm] = (todayHours.close || '23:59').split(':').map(Number)
  const openMin = oh * 60 + om
  const closeMin = ch * 60 + cm

  if (nowMinutes >= openMin && nowMinutes <= closeMin) return 'open'
  return 'closed'
}

// ── Country helpers ──────────────────────────────────────────────────────

export const COUNTRY_FLAGS: Record<string, string> = { DE: '🇩🇪', AT: '🇦🇹', CH: '🇨🇭' }
export const COUNTRY_LABELS: Record<string, string> = { DE: 'Deutschland', AT: 'Oesterreich', CH: 'Schweiz' }
