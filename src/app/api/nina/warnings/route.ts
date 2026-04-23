import { NextResponse } from 'next/server'
import { fetchNinaWarnings } from '@/lib/nina-api'

export async function GET() {
  try {
    const warnings = await fetchNinaWarnings()
    return NextResponse.json({ warnings, timestamp: new Date().toISOString() })
  } catch {
    return NextResponse.json({ warnings: [], timestamp: new Date().toISOString() }, { status: 200 })
  }
}

// 15 Minuten ISR Revalidation
export const revalidate = 900
