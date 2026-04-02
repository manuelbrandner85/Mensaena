// Shared types and constants for organizations pages

export type Country = 'all' | 'DE' | 'AT' | 'CH'
export type OrgCategory =
  | 'all' | 'tierheim' | 'tierschutz' | 'suppenkueche' | 'obdachlosenhilfe'
  | 'tafel' | 'kleiderkammer' | 'sozialkaufhaus' | 'krisentelefon'
  | 'notschlafstelle' | 'jugend' | 'senioren' | 'behinderung'
  | 'sucht' | 'fluechtlingshilfe' | 'allgemein'

export interface Organization {
  id: string
  name: string
  category: OrgCategory
  description: string | null
  address: string | null
  zip_code: string | null
  city: string
  state: string | null
  country: string
  latitude: number | null
  longitude: number | null
  phone: string | null
  email: string | null
  website: string | null
  opening_hours: string | null
  services: string[] | null
  tags: string[] | null
  is_verified: boolean
}

export const CATEGORIES: { value: OrgCategory; label: string; color: string; bg: string }[] = [
  { value: 'all',              label: 'Alle',              color: 'text-gray-600',   bg: 'bg-gray-100' },
  { value: 'tierheim',         label: 'Tierheime',         color: 'text-orange-600', bg: 'bg-orange-100' },
  { value: 'tierschutz',       label: 'Tierschutz',        color: 'text-red-500',    bg: 'bg-red-100' },
  { value: 'suppenkueche',     label: 'Suppenküchen',      color: 'text-yellow-600', bg: 'bg-yellow-100' },
  { value: 'obdachlosenhilfe', label: 'Obdachlosenhilfe',  color: 'text-blue-600',   bg: 'bg-blue-100' },
  { value: 'tafel',            label: 'Tafeln',            color: 'text-green-600',  bg: 'bg-green-100' },
  { value: 'kleiderkammer',    label: 'Kleiderkammern',    color: 'text-purple-600', bg: 'bg-purple-100' },
  { value: 'sozialkaufhaus',   label: 'Sozialkaufhäuser',  color: 'text-indigo-600', bg: 'bg-indigo-100' },
  { value: 'krisentelefon',    label: 'Krisentelefone',    color: 'text-rose-600',   bg: 'bg-rose-100' },
  { value: 'notschlafstelle',  label: 'Notschlafstellen',  color: 'text-slate-600',  bg: 'bg-slate-100' },
  { value: 'jugend',           label: 'Jugendhilfe',       color: 'text-sky-600',    bg: 'bg-sky-100' },
  { value: 'senioren',         label: 'Seniorenhilfe',     color: 'text-pink-500',   bg: 'bg-pink-100' },
  { value: 'fluechtlingshilfe',label: 'Flüchtlingshilfe',  color: 'text-teal-600',   bg: 'bg-teal-100' },
  { value: 'allgemein',        label: 'Allgemeine Hilfe',  color: 'text-gray-600',   bg: 'bg-gray-100' },
]

export const COUNTRY_FLAGS: Record<string, string> = { DE: '🇩🇪', AT: '🇦🇹', CH: '🇨🇭' }
export const COUNTRY_LABELS: Record<string, string> = { DE: 'Deutschland', AT: 'Österreich', CH: 'Schweiz' }

export function getCategoryConfig(cat: string) {
  return CATEGORIES.find(c => c.value === cat) ?? CATEGORIES[0]
}
