import { createBrowserClient } from '@supabase/ssr'

// NEXT_PUBLIC_* vars are inlined at build time by Next.js and Cloudflare Workers.
// Fallbacks exist only for dev/build where env might not be loaded yet.
// SECURITY NOTE: The anon key is a PUBLIC key by design (similar to a Firebase API key).
// All data access is controlled by Supabase Row-Level Security (RLS) policies.
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5ODcxMTgsImV4cCI6MjA5MDU2MzExOH0.Q5ciM8f--f1xAsKyr9-hv1mz7GGbJ6vbxPe4Cj5mgYE'

// createBrowserClient (from @supabase/ssr) stores the session in BOTH
// cookies AND localStorage, so server-side API routes can read the session.
export function createClient() {
  return createBrowserClient(SUPABASE_URL, SUPABASE_ANON_KEY)
}
