import { createClient as supabaseCreateClient } from '@supabase/supabase-js'

let client: ReturnType<typeof supabaseCreateClient> | null = null

// NEXT_PUBLIC_* vars are inlined at build time by Next.js.
// Fallback to wrangler.toml values if env is not set (should not happen in prod).
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5ODcxMTgsImV4cCI6MjA5MDU2MzExOH0.Q5ciM8f--f1xAsKyr9-hv1mz7GGbJ6vbxPe4Cj5mgYE'

export function createClient() {
  if (!client) {
    client = supabaseCreateClient(SUPABASE_URL, SUPABASE_ANON_KEY)
  }
  return client
}
