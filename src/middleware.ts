import { NextRequest, NextResponse } from 'next/server'

// Middleware tut nichts – Auth-Guard läuft client-seitig im DashboardLayout
export async function middleware(_request: NextRequest) {
  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon\\.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
}
