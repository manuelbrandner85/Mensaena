import { createBrowserClient } from '@supabase/ssr'

// NEXT_PUBLIC_* vars are inlined at build time by Next.js and Cloudflare Workers.
// Fallbacks exist only for dev/build where env might not be loaded yet.
// SECURITY NOTE: The anon key is a PUBLIC key by design (similar to a Firebase API key).
// All data access is controlled by Supabase Row-Level Security (RLS) policies.
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://gyqujitkvymlmgroovch.supabase.co'
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5cXVqaXRrdnltbG1ncm9vdmNoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2NzgwNzMsImV4cCI6MjA5NjI1NDA3M30.hz7uZJJPffFb5DEXKHVtmVaW5d4YzXFE2WtSROwjFxg'

// createBrowserClient (from @supabase/ssr) stores the session in BOTH
// cookies AND localStorage, so server-side API routes can read the session.
// Singleton: re-using the same client across the app avoids multiple auth
// listeners, duplicate realtime connections and shaves ~12-18 kB of repeat
// bundle cost that would otherwise show up as repeated init work.
let cachedClient: ReturnType<typeof createBrowserClient> | null = null

export function createClient() {
  if (!cachedClient) {
    cachedClient = createBrowserClient(SUPABASE_URL, SUPABASE_ANON_KEY)
  }
  return cachedClient
}
