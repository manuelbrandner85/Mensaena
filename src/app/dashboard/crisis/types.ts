// ============================================================================
// CRISIS SYSTEM – Types & Config
// ============================================================================

import {
  Siren, Flame, Droplets, CloudLightning, Car, ShieldAlert,
  Search, Wrench, Package, ArrowRightFromLine,
  CircleHelp, AlertTriangle, AlertCircle, Info, CheckCircle2,
  XCircle, Ban, Clock, type LucideIcon,
} from 'lucide-react'

// ── DB Row Types ──────────────────────────────────────────────────────────

export interface Crisis {
  id: string
  creator_id: string
  title: string
  description: string
  category: CrisisCategory
  urgency: CrisisUrgency
  status: CrisisStatus
  location_text: string | null
  latitude: number | null
  longitude: number | null
  radius_km: number
  affected_count: number
  image_urls: string[]
  contact_phone: string | null
  contact_name: string | null
  is_anonymous: boolean
  is_verified: boolean
  verified_by: string | null
  verified_at: string | null
  resolved_at: string | null
  resolved_by: string | null
  resolved_image_url: string | null
  false_alarm_by: string | null
  helper_count: number
  needed_helpers: number
  needed_skills: string[]
  needed_resources: string[]
  created_at: string
  updated_at: string
  // Joined fields
  profiles?: {
    name: string | null
    display_name?: string | null
    avatar_url: string | null
    trust_score?: number
    is_crisis_volunteer?: boolean
  }
  distance_km?: number
}

export interface CrisisHelper {
  id: string
  crisis_id: string
  user_id: string
  status: HelperStatus
  message: string | null
  skills: string[]
  eta_minutes: number | null
  latitude: number | null
  longitude: number | null
  created_at: string
  updated_at: string
  profiles?: {
    name: string | null
    display_name?: string | null
    avatar_url: string | null
    trust_score?: number
    is_crisis_volunteer?: boolean
    crisis_skills?: string[]
  }
}

export interface CrisisUpdate {
  id: string
  crisis_id: string
  author_id: string
  content: string
  update_type: UpdateType
  image_url: string | null
  is_pinned: boolean
  created_at: string
  profiles?: {
    name: string | null
    avatar_url: string | null
  }
}

export interface EmergencyNumber {
  id: string
  country: 'DE' | 'AT' | 'CH'
  category: string
  label: string
  number: string
  description: string | null
  is_24h: boolean
  is_free: boolean
  sort_order: number
}

export interface CrisisStats {
  active_count: number
  total_active_helpers: number
  resolved_last_30_days: number
  avg_resolution_hours: number
}

// ── Enums ─────────────────────────────────────────────────────────────────

export type CrisisCategory =
  | 'medical' | 'fire' | 'flood' | 'storm' | 'accident' | 'violence'
  | 'missing_person' | 'infrastructure' | 'supply' | 'evacuation' | 'other'

export type CrisisUrgency = 'critical' | 'high' | 'medium' | 'low'

export type CrisisStatus = 'active' | 'in_progress' | 'resolved' | 'false_alarm' | 'cancelled'

export type HelperStatus = 'offered' | 'accepted' | 'on_way' | 'arrived' | 'completed' | 'withdrawn'

export type UpdateType = 'info' | 'status_change' | 'resource_update' | 'helper_update' | 'resolution' | 'warning' | 'official'

// ── Input Types ───────────────────────────────────────────────────────────

export interface CreateCrisisInput {
  title: string
  description: string
  category: CrisisCategory
  urgency: CrisisUrgency
  location_text?: string
  latitude?: number
  longitude?: number
  radius_km?: number
  affected_count?: number
  image_urls?: string[]
  contact_phone?: string
  contact_name?: string
  is_anonymous?: boolean
  needed_helpers?: number
  needed_skills?: string[]
  needed_resources?: string[]
}

export interface CrisisFilters {
  status: CrisisStatus | 'all'
  category: CrisisCategory | 'all'
  urgency: CrisisUrgency | 'all'
  search: string
}

// ── Config Objects ────────────────────────────────────────────────────────

export interface CategoryConfig {
  label: string
  icon: LucideIcon
  color: string       // Tailwind text color
  bgColor: string     // Tailwind bg color
  borderColor: string // Tailwind border color
  emoji: string
}

export const CRISIS_CATEGORY_CONFIG: Record<CrisisCategory, CategoryConfig> = {
  medical:         { label: 'Medizinisch',     icon: Siren,               color: 'text-red-700',     bgColor: 'bg-red-50',     borderColor: 'border-red-200',     emoji: '🏥' },
  fire:            { label: 'Brand',           icon: Flame,               color: 'text-orange-700',  bgColor: 'bg-orange-50',  borderColor: 'border-orange-200',  emoji: '🔥' },
  flood:           { label: 'Hochwasser',      icon: Droplets,            color: 'text-blue-700',    bgColor: 'bg-blue-50',    borderColor: 'border-blue-200',    emoji: '🌊' },
  storm:           { label: 'Unwetter',        icon: CloudLightning,      color: 'text-purple-700',  bgColor: 'bg-purple-50',  borderColor: 'border-purple-200',  emoji: '⛈️' },
  accident:        { label: 'Unfall',          icon: Car,                 color: 'text-yellow-700',  bgColor: 'bg-yellow-50',  borderColor: 'border-yellow-200',  emoji: '🚗' },
  violence:        { label: 'Gewalt',          icon: ShieldAlert,         color: 'text-rose-700',    bgColor: 'bg-rose-50',    borderColor: 'border-rose-200',    emoji: '🛡️' },
  missing_person:  { label: 'Vermisst',        icon: Search,              color: 'text-indigo-700',  bgColor: 'bg-indigo-50',  borderColor: 'border-indigo-200',  emoji: '🔍' },
  infrastructure:  { label: 'Infrastruktur',   icon: Wrench,              color: 'text-gray-700',    bgColor: 'bg-gray-50',    borderColor: 'border-gray-200',    emoji: '🏗️' },
  supply:          { label: 'Versorgung',      icon: Package,             color: 'text-primary-700', bgColor: 'bg-primary-50', borderColor: 'border-primary-200', emoji: '📦' },
  evacuation:      { label: 'Evakuierung',     icon: ArrowRightFromLine,  color: 'text-amber-700',   bgColor: 'bg-amber-50',   borderColor: 'border-amber-200',   emoji: '🚨' },
  other:           { label: 'Sonstiges',       icon: CircleHelp,          color: 'text-slate-700',   bgColor: 'bg-slate-50',   borderColor: 'border-slate-200',   emoji: '❓' },
}

export interface UrgencyConfig {
  label: string
  icon: LucideIcon
  color: string
  bgColor: string
  borderColor: string
  pulseColor: string
  sortOrder: number
}

export const URGENCY_CONFIG: Record<CrisisUrgency, UrgencyConfig> = {
  critical: { label: 'Kritisch',  icon: AlertTriangle, color: 'text-red-700',    bgColor: 'bg-red-100',    borderColor: 'border-red-300',    pulseColor: 'bg-red-500',    sortOrder: 1 },
  high:     { label: 'Hoch',      icon: AlertCircle,   color: 'text-orange-700',  bgColor: 'bg-orange-100',  borderColor: 'border-orange-300',  pulseColor: 'bg-orange-500',  sortOrder: 2 },
  medium:   { label: 'Mittel',    icon: Info,           color: 'text-yellow-700',  bgColor: 'bg-yellow-100',  borderColor: 'border-yellow-300',  pulseColor: 'bg-yellow-500',  sortOrder: 3 },
  low:      { label: 'Niedrig',   icon: Clock,          color: 'text-blue-700',    bgColor: 'bg-blue-100',    borderColor: 'border-blue-300',    pulseColor: 'bg-blue-500',    sortOrder: 4 },
}

export interface StatusConfig {
  label: string
  icon: LucideIcon
  color: string
  bgColor: string
  borderColor: string
}

export const STATUS_CONFIG: Record<CrisisStatus, StatusConfig> = {
  active:      { label: 'Aktiv',          icon: AlertTriangle, color: 'text-red-700',    bgColor: 'bg-red-100',    borderColor: 'border-red-300' },
  in_progress: { label: 'In Bearbeitung', icon: Clock,         color: 'text-orange-700', bgColor: 'bg-orange-100', borderColor: 'border-orange-300' },
  resolved:    { label: 'Gelöst',         icon: CheckCircle2,  color: 'text-green-700',  bgColor: 'bg-green-100',  borderColor: 'border-green-300' },
  false_alarm: { label: 'Fehlalarm',      icon: XCircle,       color: 'text-gray-700',   bgColor: 'bg-gray-100',   borderColor: 'border-gray-300' },
  cancelled:   { label: 'Abgebrochen',    icon: Ban,           color: 'text-slate-700',  bgColor: 'bg-slate-100',  borderColor: 'border-slate-300' },
}

// ── Helper Status Config ──────────────────────────────────────────────────

export const HELPER_STATUS_CONFIG: Record<HelperStatus, { label: string; color: string; bgColor: string }> = {
  offered:   { label: 'Angeboten',    color: 'text-blue-700',    bgColor: 'bg-blue-100' },
  accepted:  { label: 'Akzeptiert',   color: 'text-primary-700', bgColor: 'bg-primary-100' },
  on_way:    { label: 'Unterwegs',    color: 'text-orange-700',  bgColor: 'bg-orange-100' },
  arrived:   { label: 'Vor Ort',      color: 'text-green-700',   bgColor: 'bg-green-100' },
  completed: { label: 'Abgeschlossen',color: 'text-gray-700',    bgColor: 'bg-gray-100' },
  withdrawn: { label: 'Zurückgezogen',color: 'text-red-700',     bgColor: 'bg-red-100' },
}

// ── Constants ─────────────────────────────────────────────────────────────

export const PAGE_SIZE = 20
export const MAX_CRISES_PER_DAY = 3
export const MIN_TRUST_FOR_CRITICAL = 2.0
export const BOT_USER_ID = '00000000-0000-0000-0000-000000000001'

export const CRISIS_SKILLS = [
  'Erste Hilfe', 'Sanitäter', 'Feuerwehr', 'Rettungsdienst',
  'Psychologische Hilfe', 'Gebärdensprache', 'Dolmetschen',
  'Technik/Handwerk', 'Fahrzeug verfügbar', 'Boot verfügbar',
  'Schwere Ausrüstung', 'Kochen/Verpflegung', 'Kinderbetreuung',
  'Seniorenbetreuung', 'Tierpflege', 'Kommunikation/Funk',
] as const

export const CRISIS_RESOURCES = [
  'Trinkwasser', 'Nahrungsmittel', 'Decken/Schlafsäcke', 'Zelte',
  'Medikamente', 'Verbandsmaterial', 'Taschenlampen', 'Batterien',
  'Powerbank', 'Werkzeug', 'Pumpen', 'Sandsäcke', 'Fahrzeug',
  'Generator', 'Kleidung', 'Hygieneartikel',
] as const
