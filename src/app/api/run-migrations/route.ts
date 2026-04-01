import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

// Each migration step: we use supabase-js with service role to run DDL
// Supabase service role can call RPC. We first create a helper function,
// then use it to run each migration statement.
const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
})

// Migrations as individual statements
const STEPS = [
  // ─── 004: profiles extra columns ──────────────────────────────
  [`ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user'`, 'profiles.role'],
  [`ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_email BOOLEAN DEFAULT TRUE`, 'profiles.notify_email'],
  [`ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_messages BOOLEAN DEFAULT TRUE`, 'profiles.notify_messages'],
  [`ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_interactions BOOLEAN DEFAULT TRUE`, 'profiles.notify_interactions'],
  [`ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_community BOOLEAN DEFAULT FALSE`, 'profiles.notify_community'],
  [`ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_crisis BOOLEAN DEFAULT TRUE`, 'profiles.notify_crisis'],
  [`ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_location BOOLEAN DEFAULT TRUE`, 'profiles.privacy_location'],
  [`ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_email BOOLEAN DEFAULT FALSE`, 'profiles.privacy_email'],
  [`ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_phone BOOLEAN DEFAULT FALSE`, 'profiles.privacy_phone'],
  [`ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_public BOOLEAN DEFAULT TRUE`, 'profiles.privacy_public'],
  [`ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_postal_code TEXT`, 'profiles.home_postal_code'],
  [`ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_city TEXT`, 'profiles.home_city'],
  [`ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_lat DOUBLE PRECISION`, 'profiles.home_lat'],
  [`ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_lng DOUBLE PRECISION`, 'profiles.home_lng'],
  // ─── 004: posts extra columns ─────────────────────────────────
  [`ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT FALSE`, 'posts.is_anonymous'],
  [`ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS image_url TEXT`, 'posts.image_url'],
  [`ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS event_date DATE`, 'posts.event_date'],
  [`ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS event_time TEXT`, 'posts.event_time'],
  [`ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS duration_hours NUMERIC(4,1)`, 'posts.duration_hours'],
  // ─── 005: conversations / members ─────────────────────────────
  [`ALTER TABLE public.conversation_members ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMPTZ DEFAULT NOW()`, 'cm.last_read_at'],
  [`ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW()`, 'conv.updated_at'],
  [`ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS is_locked BOOLEAN DEFAULT FALSE`, 'conv.is_locked'],
  [`ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS locked_reason TEXT`, 'conv.locked_reason'],
  [`INSERT INTO public.conversations (type, title) SELECT 'system', 'Community Chat' WHERE NOT EXISTS (SELECT 1 FROM public.conversations WHERE type='system' AND title='Community Chat')`, 'Community Chat conv'],
  // ─── 006: messages ────────────────────────────────────────────
  [`ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ`, 'msg.deleted_at'],
  [`ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ`, 'msg.edited_at'],
  [`ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE`, 'msg.is_pinned'],
  // ─── 006: message_reactions ───────────────────────────────────
  [`CREATE TABLE IF NOT EXISTS public.message_reactions (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE, user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, emoji TEXT NOT NULL, created_at TIMESTAMPTZ DEFAULT NOW(), UNIQUE(message_id, user_id, emoji))`, 'CREATE message_reactions'],
  [`ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY`, 'RLS message_reactions'],
  // ─── 006: chat_banned_users ───────────────────────────────────
  [`CREATE TABLE IF NOT EXISTS public.chat_banned_users (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, banned_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, reason TEXT, banned_at TIMESTAMPTZ DEFAULT NOW(), expires_at TIMESTAMPTZ, UNIQUE(user_id))`, 'CREATE chat_banned_users'],
  [`ALTER TABLE public.chat_banned_users ENABLE ROW LEVEL SECURITY`, 'RLS chat_banned_users'],
  // ─── 007: conversation_members.role ──────────────────────────
  [`ALTER TABLE public.conversation_members ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'member'`, 'cm.role'],
  // ─── 007: chat_channels ──────────────────────────────────────
  [`CREATE TABLE IF NOT EXISTS public.chat_channels (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), name TEXT NOT NULL, description TEXT, emoji TEXT DEFAULT '💬', slug TEXT UNIQUE NOT NULL, is_default BOOLEAN DEFAULT FALSE, is_locked BOOLEAN DEFAULT FALSE, locked_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL, locked_at TIMESTAMPTZ, locked_reason TEXT, sort_order INTEGER DEFAULT 0, created_at TIMESTAMPTZ DEFAULT NOW(), conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE)`, 'CREATE chat_channels'],
  [`ALTER TABLE public.chat_channels ENABLE ROW LEVEL SECURITY`, 'RLS chat_channels'],
  // seed channels (idempotent DO blocks)
  [`DO $do$ DECLARE v UUID; BEGIN SELECT id INTO v FROM public.conversations WHERE type='system' AND title='Community Chat' LIMIT 1; IF v IS NOT NULL THEN INSERT INTO public.chat_channels(name,description,emoji,slug,is_default,sort_order,conversation_id) VALUES('Allgemein','Allgemeine Diskussion','💬','allgemein',TRUE,1,v) ON CONFLICT(slug) DO NOTHING; END IF; END $do$`, 'Channel: Allgemein'],
  [`INSERT INTO public.conversations(type,title) SELECT 'system','Kanal: Hilfe gesucht' WHERE NOT EXISTS(SELECT 1 FROM public.conversations WHERE title='Kanal: Hilfe gesucht')`, 'Conv: Hilfe gesucht'],
  [`DO $do$ DECLARE v UUID; BEGIN SELECT id INTO v FROM public.conversations WHERE title='Kanal: Hilfe gesucht' LIMIT 1; IF v IS NOT NULL THEN INSERT INTO public.chat_channels(name,description,emoji,slug,sort_order,conversation_id) VALUES('Hilfe gesucht','Hilfe anfragen','🆘','hilfe-gesucht',2,v) ON CONFLICT(slug) DO NOTHING; END IF; END $do$`, 'Channel: Hilfe gesucht'],
  [`INSERT INTO public.conversations(type,title) SELECT 'system','Kanal: Hilfe anbieten' WHERE NOT EXISTS(SELECT 1 FROM public.conversations WHERE title='Kanal: Hilfe anbieten')`, 'Conv: Hilfe anbieten'],
  [`DO $do$ DECLARE v UUID; BEGIN SELECT id INTO v FROM public.conversations WHERE title='Kanal: Hilfe anbieten' LIMIT 1; IF v IS NOT NULL THEN INSERT INTO public.chat_channels(name,description,emoji,slug,sort_order,conversation_id) VALUES('Hilfe anbieten','Hilfe anbieten','🤝','hilfe-anbieten',3,v) ON CONFLICT(slug) DO NOTHING; END IF; END $do$`, 'Channel: Hilfe anbieten'],
  [`INSERT INTO public.conversations(type,title) SELECT 'system','Kanal: Tiere & Natur' WHERE NOT EXISTS(SELECT 1 FROM public.conversations WHERE title='Kanal: Tiere & Natur')`, 'Conv: Tiere & Natur'],
  [`DO $do$ DECLARE v UUID; BEGIN SELECT id INTO v FROM public.conversations WHERE title='Kanal: Tiere & Natur' LIMIT 1; IF v IS NOT NULL THEN INSERT INTO public.chat_channels(name,description,emoji,slug,sort_order,conversation_id) VALUES('Tiere & Natur','Austausch über Tiere','🐾','tiere-natur',4,v) ON CONFLICT(slug) DO NOTHING; END IF; END $do$`, 'Channel: Tiere & Natur'],
  // ─── 007: message_pins ───────────────────────────────────────
  [`CREATE TABLE IF NOT EXISTS public.message_pins (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE, conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE, pinned_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, pinned_at TIMESTAMPTZ DEFAULT NOW(), UNIQUE(message_id))`, 'CREATE message_pins'],
  [`ALTER TABLE public.message_pins ENABLE ROW LEVEL SECURITY`, 'RLS message_pins'],
  // ─── 007: chat_announcements ─────────────────────────────────
  [`CREATE TABLE IF NOT EXISTS public.chat_announcements (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), title TEXT NOT NULL, content TEXT NOT NULL, type TEXT DEFAULT 'info', is_active BOOLEAN DEFAULT TRUE, created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL, created_at TIMESTAMPTZ DEFAULT NOW(), expires_at TIMESTAMPTZ)`, 'CREATE chat_announcements'],
  [`ALTER TABLE public.chat_announcements ENABLE ROW LEVEL SECURITY`, 'RLS chat_announcements'],
] as const

// Run a DDL statement via a temporary PL/pgSQL wrapper RPC
// This works because Supabase service role can call any existing function
// We create a one-time wrapper function and call it
async function runDDL(sql: string): Promise<{ ok: boolean; msg: string }> {
  // Use the exec_sql helper if it exists, otherwise try direct approach
  const { error } = await supabaseAdmin.rpc('exec_sql', { sql_text: sql })
  if (!error) return { ok: true, msg: 'ok via exec_sql rpc' }

  // Try the Supabase admin API endpoint for raw SQL
  const res = await fetch(`${SUPABASE_URL}/rest/v1/`, {
    method: 'OPTIONS',
    headers: { 'apikey': SERVICE_KEY, 'Authorization': `Bearer ${SERVICE_KEY}` }
  })

  // Since direct DDL isn't possible via REST, we'll report error but continue
  const msg = error.message || 'unknown error'
  // "could not find function" means the exec_sql rpc doesn't exist yet
  if (msg.includes('could not find') || msg.includes('PGRST202')) {
    return { ok: false, msg: 'No exec_sql RPC available - need to create it first' }
  }
  if (msg.includes('already exists') || msg.includes('duplicate')) {
    return { ok: true, msg: 'already exists (ok)' }
  }
  return { ok: false, msg }
}

export async function POST(req: Request) {
  const secret = req.headers.get('x-migration-secret')
  if (secret !== 'mensaena-migrate-2026') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  // Step 1: Create the exec_sql helper function
  // We bootstrap by calling it via a special Supabase endpoint
  const bootstrapSQL = `
    CREATE OR REPLACE FUNCTION public.exec_sql(sql_text TEXT)
    RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
    BEGIN EXECUTE sql_text; END;
    $$;
  `

  // Try to create the function via a raw HTTP call to the admin endpoint
  const bootstrapResp = await fetch(`${SUPABASE_URL}/pg/query`, {
    method: 'POST',
    headers: { 'apikey': SERVICE_KEY, 'Authorization': `Bearer ${SERVICE_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: bootstrapSQL })
  })

  const bootstrapText = await bootstrapResp.text()
  const bootstrapOk = bootstrapResp.ok

  // Now run all migrations
  const results: { label: string; status: string; msg: string }[] = []

  for (const [sql, label] of STEPS) {
    const r = await runDDL(sql)
    results.push({ label, status: r.ok ? '✅' : '❌', msg: r.msg })
  }

  const okCount  = results.filter(r => r.status === '✅').length
  const errCount = results.filter(r => r.status === '❌').length

  return NextResponse.json({
    bootstrap: { ok: bootstrapOk, response: bootstrapText.slice(0, 200) },
    summary: { total: results.length, ok: okCount, errors: errCount },
    results,
  })
}

export async function GET() {
  // Quick status check
  const { data, error } = await supabaseAdmin.from('chat_channels').select('id').limit(1)
  const { data: p, error: pe } = await supabaseAdmin.from('profiles').select('notify_email').limit(1)
  return NextResponse.json({
    chat_channels: error ? `MISSING: ${error.message}` : 'OK',
    notify_email: pe ? `MISSING: ${pe.message}` : 'OK',
    message: 'POST with header x-migration-secret: mensaena-migrate-2026 to run migrations',
  })
}
