import { type NextRequest, NextResponse } from 'next/server'

// Beim Static Export übernimmt der clientseitige Auth Guard die Absicherung.
// Die Middleware leitet nur weiter, wenn explizit notwendig.
export async function middleware(request: NextRequest) {
  return NextResponse.next()
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
