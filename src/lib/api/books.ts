/**
 * Open Library API client for book lookups in the marketplace.
 * Docs: https://openlibrary.org/dev/docs/api
 * No API key required. 24h in-memory cache (books change rarely).
 */

export interface BookResult {
  title: string
  authors: string[]
  publishYear?: number
  publisher?: string
  isbn?: string
  coverUrl?: string
  subjects?: string[]
  pageCount?: number
  openLibraryUrl: string
}

// ── In-memory cache ──────────────────────────────────────────────────────────

interface CacheEntry<T> {
  data: T
  expiry: number
}

const CACHE_TTL_MS = 24 * 60 * 60 * 1000 // 24 hours
const _cache = new Map<string, CacheEntry<unknown>>()

function getCached<T>(key: string): T | null {
  const entry = _cache.get(key)
  if (!entry) return null
  if (Date.now() > entry.expiry) { _cache.delete(key); return null }
  return entry.data as T
}

function setCached(key: string, data: unknown): void {
  _cache.set(key, { data, expiry: Date.now() + CACHE_TTL_MS })
}

// ── ISBN validation ──────────────────────────────────────────────────────────

/** Validates ISBN-10 and ISBN-13. Accepts hyphens and spaces. */
export function isValidISBN(input: string): boolean {
  const s = input.replace(/[\s-]/g, '').toUpperCase()

  if (s.length === 10) {
    if (!/^\d{9}[\dX]$/.test(s)) return false
    let sum = 0
    for (let i = 0; i < 9; i++) sum += (i + 1) * parseInt(s[i])
    const last = s[9] === 'X' ? 10 : parseInt(s[9])
    sum += 10 * last
    return sum % 11 === 0
  }

  if (s.length === 13) {
    if (!/^\d{13}$/.test(s)) return false
    let sum = 0
    for (let i = 0; i < 12; i++) sum += parseInt(s[i]) * (i % 2 === 0 ? 1 : 3)
    const check = (10 - (sum % 10)) % 10
    return check === parseInt(s[12])
  }

  return false
}

export function cleanISBN(input: string): string {
  return input.replace(/[\s-]/g, '').toUpperCase()
}

// ── Parsers ──────────────────────────────────────────────────────────────────

/** Parse a single doc from the /api/books endpoint (jscmd=data). */
function parseBookData(data: Record<string, unknown>, isbn?: string): BookResult {
  const authorsRaw = data.authors as Array<{ name: string }> | undefined
  const authors = authorsRaw?.map(a => a.name).filter(Boolean) ?? ['Unbekannt']

  const publishDate = data.publish_date as string | undefined
  const yearMatch = publishDate?.match(/\d{4}/)
  const publishYear = yearMatch ? parseInt(yearMatch[0]) : undefined

  const publishersRaw = data.publishers as Array<{ name: string }> | undefined
  const publisher = publishersRaw?.[0]?.name

  const identifiers = data.identifiers as Record<string, string[]> | undefined
  const resolvedIsbn = isbn
    ?? identifiers?.['isbn_13']?.[0]
    ?? identifiers?.['isbn_10']?.[0]

  const coversRaw = data.cover as Record<string, string> | undefined
  const coverUrl = coversRaw?.large
    ?? coversRaw?.medium
    ?? coversRaw?.small
    ?? (resolvedIsbn ? `https://covers.openlibrary.org/b/isbn/${resolvedIsbn}-L.jpg` : undefined)

  const subjectsRaw = data.subjects as Array<{ name: string }> | undefined
  const subjects = subjectsRaw?.slice(0, 5).map(s => s.name)

  const pageCount = data.number_of_pages as number | undefined

  const keyRaw = data.key as string | undefined

  return {
    title: (data.title as string) || 'Unbekannter Titel',
    authors,
    publishYear: publishYear && !isNaN(publishYear) ? publishYear : undefined,
    publisher,
    isbn: resolvedIsbn,
    coverUrl,
    subjects,
    pageCount,
    openLibraryUrl: keyRaw ? `https://openlibrary.org${keyRaw}` : 'https://openlibrary.org',
  }
}

/** Parse a doc from the /search.json endpoint. */
function parseSearchDoc(doc: Record<string, unknown>): BookResult {
  const isbns = doc.isbn as string[] | undefined
  const isbn13 = isbns?.find(i => i.length === 13)
  const isbn10 = isbns?.find(i => i.length === 10)
  const isbn = isbn13 ?? isbn10

  const coverId = doc.cover_i as number | undefined
  const coverUrl = isbn
    ? `https://covers.openlibrary.org/b/isbn/${isbn}-M.jpg`
    : coverId
      ? `https://covers.openlibrary.org/b/id/${coverId}-M.jpg`
      : undefined

  const authorNames = doc.author_name as string[] | undefined
  const publishYear = doc.first_publish_year as number | undefined
  const publishers = doc.publisher as string[] | undefined
  const subjectsRaw = doc.subject as string[] | undefined
  const pageCount = doc.number_of_pages_median as number | undefined

  return {
    title: (doc.title as string) || 'Unbekannter Titel',
    authors: authorNames ?? ['Unbekannt'],
    publishYear,
    publisher: publishers?.[0],
    isbn,
    coverUrl,
    subjects: subjectsRaw?.slice(0, 5),
    pageCount,
    openLibraryUrl: `https://openlibrary.org${doc.key as string}`,
  }
}

// ── API functions ────────────────────────────────────────────────────────────

/** Look up a book by ISBN (10 or 13 digits). Returns null if not found. */
export async function getBookByISBN(isbn: string): Promise<BookResult | null> {
  const cleaned = cleanISBN(isbn)
  if (!isValidISBN(cleaned)) return null

  const cacheKey = `isbn:${cleaned}`
  const cached = getCached<BookResult>(cacheKey)
  if (cached) return cached

  try {
    const url =
      `https://openlibrary.org/api/books?bibkeys=ISBN:${cleaned}&format=json&jscmd=data`
    const res = await fetch(url, { signal: AbortSignal.timeout(6000) })
    if (!res.ok) return null

    const json = await res.json() as Record<string, unknown>
    const bookData = json[`ISBN:${cleaned}`] as Record<string, unknown> | undefined
    if (!bookData) return null

    const result = parseBookData(bookData, cleaned)
    setCached(cacheKey, result)
    return result
  } catch {
    return null
  }
}

/** Search books by title / author / keyword. Returns up to 5 results. */
export async function searchBooks(query: string): Promise<BookResult[]> {
  const trimmed = query.trim()
  if (trimmed.length < 2) return []

  const cacheKey = `search:${trimmed.toLowerCase()}`
  const cached = getCached<BookResult[]>(cacheKey)
  if (cached) return cached

  try {
    const url =
      `https://openlibrary.org/search.json?q=${encodeURIComponent(trimmed)}&limit=5&lang=de`
    const res = await fetch(url, { signal: AbortSignal.timeout(6000) })
    if (!res.ok) return []

    const json = await res.json() as { docs?: Record<string, unknown>[] }
    const results = (json.docs ?? []).map(parseSearchDoc)

    setCached(cacheKey, results)
    return results
  } catch {
    return []
  }
}
