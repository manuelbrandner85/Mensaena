import { NextRequest, NextResponse } from 'next/server'

export async function middleware(request: NextRequest) {
  // Middleware nur für Login/Register Redirects – Auth-Guard ist im DashboardLayout
  return NextResponse.next()
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
