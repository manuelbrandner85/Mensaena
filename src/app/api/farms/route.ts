// src/app/api/farms/route.ts
// Static Export kompatibel - wird nicht mehr als API Route verwendet
// Daten werden direkt client-side über Supabase abgerufen
export const dynamic = 'force-static'

export async function GET() {
  return new Response(JSON.stringify({ message: 'Use client-side Supabase directly' }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
}
