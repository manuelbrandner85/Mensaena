import { NextResponse } from 'next/server'
import { fetchFoodWarnings } from '@/lib/api/foodwarnings'

export const revalidate = 7200 // 2h ISR

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const limitParam = searchParams.get('limit')
    const limit = limitParam ? Math.max(1, Math.min(100, parseInt(limitParam, 10) || 20)) : 20

    const warnings = await fetchFoodWarnings({ limit })
    return NextResponse.json(
      { warnings, timestamp: new Date().toISOString() },
      {
        headers: {
          'Cache-Control': 'public, max-age=7200, stale-while-revalidate=14400',
        },
      },
    )
  } catch {
    return NextResponse.json(
      { warnings: [], timestamp: new Date().toISOString() },
      { status: 200 },
    )
  }
}
