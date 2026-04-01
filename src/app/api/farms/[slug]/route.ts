// src/app/api/farms/[slug]/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export const runtime = 'edge'
export const dynamic = 'force-dynamic'

export async function GET(
  _req: NextRequest,
  { params }: { params: { slug: string } }
) {
  const cookieStore = await cookies()
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll: () => {},
      },
    }
  )

  const { data, error } = await supabase
    .from('farm_listings')
    .select('*')
    .eq('slug', params.slug)
    .eq('is_public', true)
    .single()

  if (error || !data) {
    return NextResponse.json({ error: 'Betrieb nicht gefunden' }, { status: 404 })
  }

  return NextResponse.json({ farm: data })
}
