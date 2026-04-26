// OpenFoodFacts API – https://world.openfoodfacts.org
// Open Data, kein API-Key nötig.

export interface FoodProduct {
  barcode: string
  name: string
  brand: string
  imageUrl: string | null
  nutriScore: 'a' | 'b' | 'c' | 'd' | 'e' | null
  ecoScore: 'a' | 'b' | 'c' | 'd' | 'e' | null
  allergens: string[]          // deutsche Labels
  allergenTags: string[]       // raw OFF tags (en:gluten etc.)
  isVegan: boolean
  isVegetarian: boolean
  calories?: number            // kcal per 100g
  fat?: number                 // g per 100g
  sugar?: number               // g per 100g
  salt?: number                // g per 100g
  protein?: number             // g per 100g
  carbs?: number               // g per 100g
}

// ── Nutri/Eco-Score helper ─────────────────────────────────────

export type ScoreGrade = 'a' | 'b' | 'c' | 'd' | 'e'

export const NUTRISCORE_COLOR: Record<ScoreGrade, string> = {
  a: '#038141',  // darkgreen
  b: '#85BB2F',  // green
  c: '#FECB02',  // yellow
  d: '#EE8100',  // orange
  e: '#E63312',  // red
}

export const ECOSCORE_COLOR: Record<ScoreGrade, string> = {
  a: '#1B5E20',
  b: '#558B2F',
  c: '#F9A825',
  d: '#E65100',
  e: '#B71C1C',
}

function parseGrade(raw: unknown): ScoreGrade | null {
  if (typeof raw !== 'string') return null
  const g = raw.toLowerCase().trim()
  if (g === 'a' || g === 'b' || g === 'c' || g === 'd' || g === 'e') return g
  return null
}

// ── Allergen-Übersetzung ───────────────────────────────────────

const ALLERGEN_MAP: Record<string, string> = {
  gluten:           'Gluten',
  wheat:            'Weizen',
  rye:              'Roggen',
  barley:           'Gerste',
  oats:             'Hafer',
  spelt:            'Dinkel',
  kamut:            'Kamut',
  crustaceans:      'Krebstiere',
  eggs:             'Eier',
  fish:             'Fisch',
  peanuts:          'Erdnüsse',
  soybeans:         'Soja',
  soya:             'Soja',
  milk:             'Milch',
  lactose:          'Laktose',
  nuts:             'Nüsse',
  almonds:          'Mandeln',
  hazelnuts:        'Haselnüsse',
  walnuts:          'Walnüsse',
  cashews:          'Cashews',
  pecans:           'Pekannüsse',
  pistachios:       'Pistazien',
  macadamia:        'Macadamianüsse',
  celery:           'Sellerie',
  mustard:          'Senf',
  sesame:           'Sesam',
  sulphites:        'Sulfite',
  'sulphur-dioxide':'Schwefeldioxid',
  lupin:            'Lupinen',
  molluscs:         'Weichtiere',
}

function translateAllergen(tag: string): string {
  // Tag format: "en:gluten" or "en:milk" or just "milk"
  const key = tag.replace(/^[a-z]{2}:/, '').toLowerCase().replace(/-/g, '')
  // Try exact match first
  for (const [k, v] of Object.entries(ALLERGEN_MAP)) {
    if (k.replace(/-/g, '') === key) return v
  }
  // Substring match
  for (const [k, v] of Object.entries(ALLERGEN_MAP)) {
    if (key.includes(k.replace(/-/g, '')) || k.replace(/-/g, '').includes(key)) return v
  }
  // Fallback: capitalize the raw value
  return tag.replace(/^[a-z]{2}:/, '').replace(/-/g, ' ')
    .replace(/\b\w/g, c => c.toUpperCase())
}

// ── OFF response mapper ────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapProduct(raw: any, barcode: string): FoodProduct {
  const p = raw ?? {}
  const nutriments = p.nutriments ?? {}

  // Allergens
  const rawTags: string[] = Array.isArray(p.allergens_tags) ? p.allergens_tags : []
  const allergenTags = rawTags.filter(Boolean)
  const allergens = [...new Set(allergenTags.map(translateAllergen))]

  // Vegan / Vegetarian (OFF ingredients_analysis_tags)
  const analysisTags: string[] = Array.isArray(p.ingredients_analysis_tags)
    ? p.ingredients_analysis_tags
    : []
  const isVegan      = analysisTags.some(t => t.includes('vegan') && !t.includes('non'))
  const isVegetarian = analysisTags.some(t => t.includes('vegetarian') && !t.includes('non')) || isVegan

  const num = (field: string): number | undefined => {
    const v = nutriments[field]
    return typeof v === 'number' ? Math.round(v * 10) / 10 : undefined
  }

  return {
    barcode,
    name:         (p.product_name || p.product_name_de || p.product_name_en || '').trim() || 'Unbekanntes Produkt',
    brand:        (p.brands || '').split(',')[0].trim() || '',
    imageUrl:     p.image_front_url || p.image_url || null,
    nutriScore:   parseGrade(p.nutriscore_grade),
    ecoScore:     parseGrade(p.ecoscore_grade),
    allergens,
    allergenTags,
    isVegan,
    isVegetarian,
    calories: num('energy-kcal_100g') ?? num('energy-kcal'),
    fat:      num('fat_100g')         ?? num('fat'),
    sugar:    num('sugars_100g')      ?? num('sugars'),
    salt:     num('salt_100g')        ?? num('salt'),
    protein:  num('proteins_100g')    ?? num('proteins'),
    carbs:    num('carbohydrates_100g') ?? num('carbohydrates'),
  }
}

// ── Public API ────────────────────────────────────────────────

const BASE = 'https://world.openfoodfacts.org'
const HEADERS = {
  'User-Agent': 'MensaEna/1.0 (+https://www.mensaena.de)',
  'Accept': 'application/json',
}

/**
 * Produkt per EAN/UPC-Barcode laden.
 * Gibt `null` zurück wenn nicht gefunden oder Fehler.
 */
export async function getProductByBarcode(barcode: string): Promise<FoodProduct | null> {
  try {
    const res = await fetch(`${BASE}/api/v2/product/${encodeURIComponent(barcode)}.json`, {
      headers: HEADERS,
      signal: AbortSignal.timeout(8000),
    })
    if (!res.ok) return null
    const data = await res.json()
    if (data.status !== 1 || !data.product) return null
    return mapProduct(data.product, barcode)
  } catch {
    return null
  }
}

/**
 * Produkte per Suchbegriff suchen (max 5 Treffer).
 */
export async function searchProducts(query: string): Promise<FoodProduct[]> {
  if (!query.trim()) return []
  try {
    const params = new URLSearchParams({
      search_terms: query.trim(),
      search_simple: '1',
      action: 'process',
      json: '1',
      page_size: '5',
      fields: [
        'code', 'product_name', 'product_name_de', 'product_name_en',
        'brands', 'nutriscore_grade', 'ecoscore_grade',
        'allergens_tags', 'ingredients_analysis_tags',
        'image_front_url', 'image_url',
        'nutriments',
      ].join(','),
    })
    const res = await fetch(`${BASE}/cgi/search.pl?${params}`, {
      headers: HEADERS,
      signal: AbortSignal.timeout(8000),
    })
    if (!res.ok) return []
    const data = await res.json()
    const products: FoodProduct[] = []
    for (const p of (data.products ?? [])) {
      const barcode = String(p.code ?? p._id ?? '')
      if (barcode) products.push(mapProduct(p, barcode))
    }
    return products
  } catch {
    return []
  }
}
