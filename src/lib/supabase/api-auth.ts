import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import { NextResponse } from 'next/server'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5ODcxMTgsImV4cCI6MjA5MDU2MzExOH0.Q5ciM8f--f1xAsKyr9-hv1mz7GGbJ6vbxPe4Cj5mgYE'

// Supabase-Client für API Route Handler (liest Session aus Cookies)
export async function getApiClient() {
  const cookieStore = await cookies()

  const supabase = createServerClient(
    SUPABASE_URL,
    SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() { return cookieStore.getAll() },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options)
          )
        },
      },
    }
  )

  const { data: { user } } = await supabase.auth.getUser()
  return { supabase, user }
}

// Standard-Antworten
export const err = {
  unauthorized: () =>
    NextResponse.json({ error: 'Nicht angemeldet' }, { status: 401 }),
  forbidden: () =>
    NextResponse.json({ error: 'Keine Berechtigung' }, { status: 403 }),
  notFound: (msg = 'Nicht gefunden') =>
    NextResponse.json({ error: msg }, { status: 404 }),
  bad: (msg: string) =>
    NextResponse.json({ error: msg }, { status: 400 }),
  conflict: (msg: string) =>
    NextResponse.json({ error: msg }, { status: 409 }),
  internal: (msg: string) =>
    NextResponse.json({ error: msg }, { status: 500 }),
}
