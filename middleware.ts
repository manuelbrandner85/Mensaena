import { NextRequest, NextResponse } from 'next/server'
import { createServerClient, type CookieOptions } from '@supabase/ssr'

// ── Country → Locale mapping ────────────────────────────────────────────
// Default is 'de' (DE/AT/CH and anything not listed below).
const COUNTRY_TO_LOCALE: Record<string, string> = {
  // German
  DE: 'de', AT: 'de', CH: 'de', LI: 'de', LU: 'de',
  // English
  GB: 'en', US: 'en', CA: 'en', AU: 'en', IE: 'en', NZ: 'en', IN: 'en', ZA: 'en',
  // Italian
  IT: 'it', SM: 'it', VA: 'it',
  // Turkish
  TR: 'tr', CY: 'tr',
  // Ukrainian
  UA: 'uk',
  // Arabic
  SA: 'ar', AE: 'ar', EG: 'ar', MA: 'ar', DZ: 'ar', TN: 'ar', LY: 'ar',
  IQ: 'ar', JO: 'ar', LB: 'ar', SY: 'ar', YE: 'ar', OM: 'ar', QA: 'ar',
  BH: 'ar', KW: 'ar', SD: 'ar', PS: 'ar',
}

const VALID_LOCALES = ['de', 'en', 'it', 'tr', 'uk', 'ar']

function detectLocaleFromCountry(country: string | null): string {
  if (!country) return 'de'
  return COUNTRY_TO_LOCALE[country.toUpperCase()] ?? 'de'
}

export async function middleware(request: NextRequest) {
  const res = NextResponse.next()

  // ── 1. Auto-detect locale from country if cookie not set ──
  const existingLocale = request.cookies.get('NEXT_LOCALE')?.value
  if (!existingLocale || !VALID_LOCALES.includes(existingLocale)) {
    // Cloudflare provides CF-IPCountry on every request when proxied through CF
    const country = request.headers.get('cf-ipcountry') ?? request.headers.get('x-vercel-ip-country')
    const locale = detectLocaleFromCountry(country)
    // Set on request so the i18n config + Server Components see it during this request
    request.cookies.set('NEXT_LOCALE', locale)
    // Set on response so the browser stores it for future requests
    res.cookies.set('NEXT_LOCALE', locale, {
      path: '/',
      maxAge: 60 * 60 * 24 * 365, // 1 year
      sameSite: 'lax',
    })
  }

  // ── 2. Auth protection — only for /dashboard routes ──
  if (!request.nextUrl.pathname.startsWith('/dashboard')) {
    return res
  }

  try {
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() {
            return request.cookies.getAll()
          },
          setAll(cookiesToSet: Array<{ name: string; value: string; options: CookieOptions }>) {
            cookiesToSet.forEach(({ name, value, options }) => {
              request.cookies.set(name, value)
              res.cookies.set(name, value, options)
            })
          },
        },
      }
    )

    const { data: { user } } = await supabase.auth.getUser()

    if (!user) {
      const loginUrl = new URL('/auth?mode=login', request.url)
      loginUrl.searchParams.set('redirect', request.nextUrl.pathname)
      return NextResponse.redirect(loginUrl)
    }

    if (request.nextUrl.pathname.startsWith('/dashboard/admin')) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single()

      const role = profile?.role ?? 'user'
      if (role !== 'admin' && role !== 'moderator') {
        return NextResponse.redirect(new URL('/dashboard', request.url))
      }
    }
  } catch {
    // If Supabase SSR fails (e.g., missing env vars on Cloudflare), fall through
  }

  return res
}

export const config = {
  // Run on all routes EXCEPT static assets, API routes, and Next.js internals.
  // This ensures locale auto-detection runs on landing page + dashboard.
  matcher: [
    '/((?!api|_next/static|_next/image|favicon.ico|icons|sounds|fonts|images|.*\\..*).*)',
  ],
}
