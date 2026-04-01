// src/types/farm.ts
export interface FarmListing {
  id: string
  name: string
  slug: string
  category:
    | 'Bauernhof'
    | 'Hofladen'
    | 'Direktvermarktung'
    | 'Wochenmarkt'
    | 'Solidarische Landwirtschaft'
    | 'Biohof'
    | 'Selbsternte'
    | 'Lieferdienst'
  subcategories: string[]
  description: string | null
  address: string | null
  postal_code: string | null
  city: string
  region: string | null
  state: string | null
  country: string
  latitude: number | null
  longitude: number | null
  phone: string | null
  email: string | null
  website: string | null
  opening_hours: Record<string, string> | null
  products: string[]
  services: string[]
  delivery_options: string[]
  image_url: string | null
  source_url: string | null
  source_name: string | null
  is_bio: boolean
  is_seasonal: boolean
  is_verified: boolean
  is_public: boolean
  imported_at: string
  last_verified_at: string | null
  created_at: string
  updated_at: string
}

export type FarmCategory = FarmListing['category']

export const FARM_CATEGORIES: FarmCategory[] = [
  'Bauernhof',
  'Hofladen',
  'Direktvermarktung',
  'Wochenmarkt',
  'Solidarische Landwirtschaft',
  'Biohof',
  'Selbsternte',
  'Lieferdienst',
]

export const FARM_PRODUCTS = [
  'Gemüse', 'Obst', 'Fleisch', 'Wurst', 'Käse', 'Milch',
  'Eier', 'Brot', 'Getreide', 'Wein', 'Most', 'Saft',
  'Honig', 'Kräuter', 'Fisch', 'Geflügel', 'Öl', 'Spargel',
  'Erdbeeren', 'Kürbis', 'Kartoffeln',
]

export const COUNTRY_LABELS: Record<string, string> = {
  AT: '🇦🇹 Österreich',
  DE: '🇩🇪 Deutschland',
  CH: '🇨🇭 Schweiz',
}

export const CATEGORY_ICONS: Record<FarmCategory, string> = {
  'Bauernhof': '🏡',
  'Hofladen': '🛍️',
  'Direktvermarktung': '🤝',
  'Wochenmarkt': '🛒',
  'Solidarische Landwirtschaft': '🌱',
  'Biohof': '🌿',
  'Selbsternte': '✂️',
  'Lieferdienst': '🚚',
}

export const CATEGORY_COLORS: Record<FarmCategory, string> = {
  'Bauernhof': 'bg-amber-100 text-amber-800',
  'Hofladen': 'bg-orange-100 text-orange-800',
  'Direktvermarktung': 'bg-green-100 text-green-800',
  'Wochenmarkt': 'bg-blue-100 text-blue-800',
  'Solidarische Landwirtschaft': 'bg-emerald-100 text-emerald-800',
  'Biohof': 'bg-lime-100 text-lime-800',
  'Selbsternte': 'bg-yellow-100 text-yellow-800',
  'Lieferdienst': 'bg-purple-100 text-purple-800',
}
