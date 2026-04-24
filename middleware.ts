import { NextRequest, NextResponse } from 'next/server'
import { createServerClient, type CookieOptions } from '@supabase/ssr'

export async function middleware(request: NextRequest) {
  const res = NextResponse.next()

  // Only protect /dashboard routes
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

    // D1.4 Server-side admin route protection
    // Protect /dashboard/admin – only admin/moderator roles can access
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
    // Client-side auth guard in DashboardShell handles the rest
  }

  return res
}

export const config = {
  matcher: ['/dashboard/:path*'],
}
