// src/app/api/farms/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export const dynamic = 'force-dynamic'

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url)
  const q = searchParams.get('q') || ''
  const category = searchParams.get('category') || ''
  const country = searchParams.get('country') || ''
  const state = searchParams.get('state') || ''
  const product = searchParams.get('product') || ''
  const bio = searchParams.get('bio') || ''
  const delivery = searchParams.get('delivery') || ''
  const page = parseInt(searchParams.get('page') || '1', 10)
  const limit = parseInt(searchParams.get('limit') || '24', 10)
  const offset = (page - 1) * limit

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

  let query = supabase
    .from('farm_listings')
    .select('*', { count: 'exact' })
    .eq('is_public', true)
    .order('is_verified', { ascending: false })
    .order('name', { ascending: true })
    .range(offset, offset + limit - 1)

  if (q) {
    query = query.or(
      `name.ilike.%${q}%,city.ilike.%${q}%,description.ilike.%${q}%,state.ilike.%${q}%`
    )
  }
  if (category) query = query.eq('category', category)
  if (country) query = query.eq('country', country)
  if (state) query = query.ilike('state', `%${state}%`)
  if (bio === 'true') query = query.eq('is_bio', true)
  if (product) query = query.contains('products', [product])
  if (delivery === 'true') {
    // farms with any delivery option (non-empty array)
    query = query.not('delivery_options', 'eq', '{}')
  }

  const { data, error, count } = await query

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }

  return NextResponse.json({
    farms: data || [],
    total: count || 0,
    page,
    limit,
    pages: Math.ceil((count || 0) / limit),
  })
}
