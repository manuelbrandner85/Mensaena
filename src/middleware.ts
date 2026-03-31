import { NextRequest, NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  // Nur für Dashboard und Auth-Seiten aktiv
  const isDashboard = pathname.startsWith('/dashboard')
  const isAuthPage  = pathname === '/login' || pathname === '/register'

  // Alle anderen Seiten direkt durchlassen (kein Supabase-Aufruf!)
  if (!isDashboard && !isAuthPage) {
    return NextResponse.next()
  }

  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet: { name: string; value: string; options?: Record<string, unknown> }[]) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          )
          supabaseResponse = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(
              name,
              value,
              options as Parameters<typeof supabaseResponse.cookies.set>[2]
            )
          )
        },
      },
    }
  )

  // getUser() nur wenn wirklich gebraucht (Dashboard oder Auth-Redirect)
  let user = null
  try {
    const { data } = await supabase.auth.getUser()
    user = data.user
  } catch {
    // Bei Netzwerkfehler: client-seitiger Guard übernimmt
  }

  // Dashboard ohne Login → Redirect
  if (isDashboard && !user) {
    const url = request.nextUrl.clone()
    url.pathname = '/login'
    return NextResponse.redirect(url)
  }

  // Eingeloggt auf Auth-Seite → Dashboard
  if (isAuthPage && user) {
    const url = request.nextUrl.clone()
    url.pathname = '/dashboard'
    return NextResponse.redirect(url)
  }

  return supabaseResponse
}

export const config = {
  // Nur Dashboard und Auth-Seiten – keine statischen Dateien, keine API-Routes
  matcher: ['/dashboard/:path*', '/login', '/register'],
}
