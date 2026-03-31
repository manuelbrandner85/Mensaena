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

  // WICHTIG: Zuerst getSession() prüfen (kein Netzwerk-Call nötig!)
  // getUser() verifiziert beim Supabase-Server – das kostet Zeit und kann fehlschlagen
  let user = null
  try {
    // Zuerst lokale Session prüfen (schnell, kein Netzwerkaufruf)
    const { data: sessionData } = await supabase.auth.getSession()
    
    if (sessionData.session) {
      // Session lokal vorhanden → User aus Session nehmen, kein getUser()-Call nötig
      user = sessionData.session.user
    } else if (isDashboard) {
      // Nur für Dashboard-Schutz getUser() aufrufen (mit Timeout)
      const userResult = await Promise.race([
        supabase.auth.getUser(),
        new Promise<{ data: { user: null } }>((resolve) =>
          setTimeout(() => resolve({ data: { user: null } }), 3000)
        ),
      ])
      user = (userResult as { data: { user: typeof user } }).data.user
    }
  } catch {
    // Bei Fehler: client-seitiger Guard in DashboardLayout übernimmt
    user = null
  }

  // Dashboard ohne Login → Redirect zu /login
  if (isDashboard && !user) {
    const url = request.nextUrl.clone()
    url.pathname = '/login'
    return NextResponse.redirect(url)
  }

  // Eingeloggt auf Auth-Seite → Dashboard
  // ABER NUR wenn wir eine lokale Session haben (kein getUser()-Call für Auth-Pages!)
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
