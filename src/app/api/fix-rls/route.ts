import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'
const SECRET = 'mensaena-fix-rls-2026'

// All SQL statements to execute in order
const SQL_STATEMENTS: Array<[string, string]> = [
  // ── STEP 1: Create SECURITY DEFINER helper functions ───────────────────────
  [`CREATE OR REPLACE FUNCTION public.is_conversation_member(conv_id UUID, uid UUID)
    RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE AS $$
      SELECT EXISTS (
        SELECT 1 FROM public.conversation_members
        WHERE conversation_id = conv_id AND user_id = uid
      );
    $$`, 'fn: is_conversation_member'],

  [`CREATE OR REPLACE FUNCTION public.get_user_conversation_ids(uid UUID)
    RETURNS SETOF UUID LANGUAGE sql SECURITY DEFINER STABLE AS $$
      SELECT conversation_id FROM public.conversation_members WHERE user_id = uid;
    $$`, 'fn: get_user_conversation_ids'],

  [`CREATE OR REPLACE FUNCTION public.get_conversation_type(conv_id UUID)
    RETURNS TEXT LANGUAGE sql SECURITY DEFINER STABLE AS $$
      SELECT type FROM public.conversations WHERE id = conv_id;
    $$`, 'fn: get_conversation_type'],

  // ── STEP 2: Drop ALL old conversation_members policies ─────────────────────
  [`DROP POLICY IF EXISTS "conv_members_read"   ON public.conversation_members`, 'drop conv_members_read'],
  [`DROP POLICY IF EXISTS "conv_members_select" ON public.conversation_members`, 'drop conv_members_select'],
  [`DROP POLICY IF EXISTS "conv_members_insert" ON public.conversation_members`, 'drop conv_members_insert'],
  [`DROP POLICY IF EXISTS "conv_members_update" ON public.conversation_members`, 'drop conv_members_update'],
  [`DROP POLICY IF EXISTS "conv_members_delete" ON public.conversation_members`, 'drop conv_members_delete'],

  // New non-recursive policies for conversation_members
  [`CREATE POLICY "conv_members_select_own" ON public.conversation_members
    FOR SELECT USING (user_id = auth.uid())`, 'policy: conv_members_select_own'],

  [`CREATE POLICY "conv_members_insert_auth" ON public.conversation_members
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL)`, 'policy: conv_members_insert'],

  [`CREATE POLICY "conv_members_update_own" ON public.conversation_members
    FOR UPDATE USING (user_id = auth.uid())`, 'policy: conv_members_update'],

  [`CREATE POLICY "conv_members_delete_own" ON public.conversation_members
    FOR DELETE USING (user_id = auth.uid())`, 'policy: conv_members_delete'],

  // ── STEP 3: Drop and recreate conversations policies ───────────────────────
  [`DROP POLICY IF EXISTS "conversations_member_read"  ON public.conversations`, 'drop conv member_read'],
  [`DROP POLICY IF EXISTS "conversations_system_read"  ON public.conversations`, 'drop conv system_read'],
  [`DROP POLICY IF EXISTS "conversations_auth_insert"  ON public.conversations`, 'drop conv auth_insert'],
  [`DROP POLICY IF EXISTS "conversations_auth_update"  ON public.conversations`, 'drop conv auth_update'],
  [`DROP POLICY IF EXISTS "conversations_lock_admin"   ON public.conversations`, 'drop conv lock_admin'],
  [`DROP POLICY IF EXISTS "conversations_read"         ON public.conversations`, 'drop conv read'],
  [`DROP POLICY IF EXISTS "conversations_insert"       ON public.conversations`, 'drop conv insert'],
  [`DROP POLICY IF EXISTS "conversations_update"       ON public.conversations`, 'drop conv update'],

  // System conversations visible to all authenticated users; DMs only to members
  [`CREATE POLICY "conversations_read" ON public.conversations
    FOR SELECT USING (
      auth.uid() IS NOT NULL AND (
        type = 'system'
        OR public.is_conversation_member(id, auth.uid())
      )
    )`, 'policy: conversations_read'],

  [`CREATE POLICY "conversations_insert" ON public.conversations
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL)`, 'policy: conversations_insert'],

  [`CREATE POLICY "conversations_update" ON public.conversations
    FOR UPDATE USING (
      public.is_conversation_member(id, auth.uid())
      OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
      OR auth.email() = ANY(ARRAY['brandy13062@gmail.com','uwevetter@gmx.at'])
    )`, 'policy: conversations_update'],

  // ── STEP 4: Drop and recreate messages policies ────────────────────────────
  [`DROP POLICY IF EXISTS "messages_conversation_read"     ON public.messages`, 'drop msg conversation_read'],
  [`DROP POLICY IF EXISTS "messages_auth_insert"           ON public.messages`, 'drop msg auth_insert'],
  [`DROP POLICY IF EXISTS "messages_auth_update"           ON public.messages`, 'drop msg auth_update'],
  [`DROP POLICY IF EXISTS "messages_auth_delete"           ON public.messages`, 'drop msg auth_delete'],
  [`DROP POLICY IF EXISTS "community_room_messages_insert" ON public.messages`, 'drop msg community_insert'],
  [`DROP POLICY IF EXISTS "messages_admin_delete"          ON public.messages`, 'drop msg admin_delete'],
  [`DROP POLICY IF EXISTS "messages_admin_update"          ON public.messages`, 'drop msg admin_update'],
  [`DROP POLICY IF EXISTS "messages_read"                  ON public.messages`, 'drop msg read'],
  [`DROP POLICY IF EXISTS "messages_insert"                ON public.messages`, 'drop msg insert'],
  [`DROP POLICY IF EXISTS "messages_update_own"            ON public.messages`, 'drop msg update_own'],
  [`DROP POLICY IF EXISTS "messages_delete"                ON public.messages`, 'drop msg delete'],

  // READ: system conversations open for all; DMs only for members
  [`CREATE POLICY "messages_read" ON public.messages
    FOR SELECT USING (
      auth.uid() IS NOT NULL AND (
        public.get_conversation_type(conversation_id) = 'system'
        OR public.is_conversation_member(conversation_id, auth.uid())
      )
    )`, 'policy: messages_read'],

  // INSERT: authenticated users can write to system channels + their DMs
  [`CREATE POLICY "messages_insert" ON public.messages
    FOR INSERT WITH CHECK (
      auth.uid() = sender_id
      AND (
        public.get_conversation_type(conversation_id) = 'system'
        OR public.is_conversation_member(conversation_id, auth.uid())
      )
    )`, 'policy: messages_insert'],

  // UPDATE: own messages or admin
  [`CREATE POLICY "messages_update_own" ON public.messages
    FOR UPDATE USING (
      sender_id = auth.uid()
      OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
      OR auth.email() = ANY(ARRAY['brandy13062@gmail.com','uwevetter@gmx.at'])
    )`, 'policy: messages_update'],

  // DELETE: own messages or admin
  [`CREATE POLICY "messages_delete" ON public.messages
    FOR DELETE USING (
      sender_id = auth.uid()
      OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
      OR auth.email() = ANY(ARRAY['brandy13062@gmail.com','uwevetter@gmx.at'])
    )`, 'policy: messages_delete'],

  // ── STEP 5: chat_banned_users policies ─────────────────────────────────────
  [`DROP POLICY IF EXISTS "banned_read"      ON public.chat_banned_users`, 'drop banned_read'],
  [`DROP POLICY IF EXISTS "banned_admin"     ON public.chat_banned_users`, 'drop banned_admin'],
  [`DROP POLICY IF EXISTS "banned_read_own"  ON public.chat_banned_users`, 'drop banned_read_own'],
  [`DROP POLICY IF EXISTS "banned_admin_all" ON public.chat_banned_users`, 'drop banned_admin_all'],

  [`CREATE POLICY "banned_read_own" ON public.chat_banned_users
    FOR SELECT USING (user_id = auth.uid())`, 'policy: banned_read_own'],

  [`CREATE POLICY "banned_admin_all" ON public.chat_banned_users
    FOR ALL USING (
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
      OR auth.email() = ANY(ARRAY['brandy13062@gmail.com','uwevetter@gmx.at'])
    )`, 'policy: banned_admin_all'],

  // ── STEP 6: message_reactions policies ─────────────────────────────────────
  [`DROP POLICY IF EXISTS "reactions_read"   ON public.message_reactions`, 'drop reactions_read'],
  [`DROP POLICY IF EXISTS "reactions_insert" ON public.message_reactions`, 'drop reactions_insert'],
  [`DROP POLICY IF EXISTS "reactions_delete" ON public.message_reactions`, 'drop reactions_delete'],

  [`CREATE POLICY "reactions_read" ON public.message_reactions
    FOR SELECT USING (auth.uid() IS NOT NULL)`, 'policy: reactions_read'],

  [`CREATE POLICY "reactions_insert" ON public.message_reactions
    FOR INSERT WITH CHECK (auth.uid() = user_id)`, 'policy: reactions_insert'],

  [`CREATE POLICY "reactions_delete" ON public.message_reactions
    FOR DELETE USING (auth.uid() = user_id)`, 'policy: reactions_delete'],

  // ── STEP 7: message_pins policies ──────────────────────────────────────────
  [`DROP POLICY IF EXISTS "pins_read"  ON public.message_pins`, 'drop pins_read'],
  [`DROP POLICY IF EXISTS "pins_admin" ON public.message_pins`, 'drop pins_admin'],

  [`CREATE POLICY "pins_read" ON public.message_pins
    FOR SELECT USING (auth.uid() IS NOT NULL)`, 'policy: pins_read'],

  [`CREATE POLICY "pins_admin" ON public.message_pins
    FOR ALL USING (
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
      OR auth.email() = ANY(ARRAY['brandy13062@gmail.com','uwevetter@gmx.at'])
    )`, 'policy: pins_admin'],

  // ── STEP 8: chat_announcements policies ────────────────────────────────────
  [`DROP POLICY IF EXISTS "announcements_read"  ON public.chat_announcements`, 'drop ann_read'],
  [`DROP POLICY IF EXISTS "announcements_admin" ON public.chat_announcements`, 'drop ann_admin'],

  [`CREATE POLICY "announcements_read" ON public.chat_announcements
    FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = true)`, 'policy: ann_read'],

  [`CREATE POLICY "announcements_admin" ON public.chat_announcements
    FOR ALL USING (
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
      OR auth.email() = ANY(ARRAY['brandy13062@gmail.com','uwevetter@gmx.at'])
    )`, 'policy: ann_admin'],

  // ── STEP 9: user_status policies ───────────────────────────────────────────
  [`DROP POLICY IF EXISTS "status_read" ON public.user_status`, 'drop status_read'],
  [`DROP POLICY IF EXISTS "status_own"  ON public.user_status`, 'drop status_own'],

  [`CREATE POLICY "status_read" ON public.user_status
    FOR SELECT USING (auth.uid() IS NOT NULL)`, 'policy: status_read'],

  [`CREATE POLICY "status_own" ON public.user_status
    FOR ALL USING (user_id = auth.uid())`, 'policy: status_own'],

  // ── STEP 10: chat_channels policies ────────────────────────────────────────
  [`DROP POLICY IF EXISTS "channels_read"  ON public.chat_channels`, 'drop channels_read'],
  [`DROP POLICY IF EXISTS "channels_admin" ON public.chat_channels`, 'drop channels_admin'],

  [`CREATE POLICY "channels_read" ON public.chat_channels
    FOR SELECT USING (auth.uid() IS NOT NULL)`, 'policy: channels_read'],

  [`CREATE POLICY "channels_admin" ON public.chat_channels
    FOR ALL USING (
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
      OR auth.email() = ANY(ARRAY['brandy13062@gmail.com','uwevetter@gmx.at'])
    )`, 'policy: channels_admin'],

  // ── STEP 11: profiles read policy ──────────────────────────────────────────
  [`DROP POLICY IF EXISTS "profiles_read"   ON public.profiles`, 'drop profiles_read'],
  [`DROP POLICY IF EXISTS "profiles_own"    ON public.profiles`, 'drop profiles_own'],
  [`DROP POLICY IF EXISTS "profiles_public" ON public.profiles`, 'drop profiles_public'],

  [`CREATE POLICY "profiles_public" ON public.profiles
    FOR SELECT USING (auth.uid() IS NOT NULL)`, 'policy: profiles_public'],

  [`CREATE POLICY "profiles_own" ON public.profiles
    FOR ALL USING (id = auth.uid())`, 'policy: profiles_own'],

  // ── STEP 12: posts policies ─────────────────────────────────────────────────
  [`DROP POLICY IF EXISTS "posts_read"   ON public.posts`, 'drop posts_read'],
  [`DROP POLICY IF EXISTS "posts_own"    ON public.posts`, 'drop posts_own'],
  [`DROP POLICY IF EXISTS "posts_insert" ON public.posts`, 'drop posts_insert'],
  [`DROP POLICY IF EXISTS "posts_update" ON public.posts`, 'drop posts_update'],
  [`DROP POLICY IF EXISTS "posts_delete" ON public.posts`, 'drop posts_delete'],

  [`CREATE POLICY "posts_read" ON public.posts
    FOR SELECT USING (auth.uid() IS NOT NULL AND status = 'active')`, 'policy: posts_read'],

  [`CREATE POLICY "posts_insert" ON public.posts
    FOR INSERT WITH CHECK (auth.uid() = user_id)`, 'policy: posts_insert'],

  [`CREATE POLICY "posts_update" ON public.posts
    FOR UPDATE USING (auth.uid() = user_id)`, 'policy: posts_update'],

  [`CREATE POLICY "posts_delete" ON public.posts
    FOR DELETE USING (
      auth.uid() = user_id
      OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    )`, 'policy: posts_delete'],

  // ── STEP 13: notifications table ───────────────────────────────────────────
  [`CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT DEFAULT 'system',
    title TEXT,
    message TEXT,
    url TEXT DEFAULT '/dashboard',
    read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
  )`, 'CREATE notifications'],

  [`CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id, created_at DESC)`, 'idx: notifications_user'],
  [`ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY`, 'RLS notifications'],
  [`DROP POLICY IF EXISTS "notifications_own" ON public.notifications`, 'drop notifications_own'],
  [`CREATE POLICY "notifications_own" ON public.notifications
    FOR ALL USING (auth.uid() = user_id)`, 'policy: notifications_own'],

  // ── STEP 14: push_subscriptions table ──────────────────────────────────────
  [`CREATE TABLE IF NOT EXISTS public.push_subscriptions (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    endpoint TEXT NOT NULL,
    p256dh TEXT,
    auth TEXT,
    updated_at TIMESTAMPTZ DEFAULT now()
  )`, 'CREATE push_subscriptions'],

  [`ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY`, 'RLS push_subscriptions'],
  [`DROP POLICY IF EXISTS "push_own" ON public.push_subscriptions`, 'drop push_own'],
  [`CREATE POLICY "push_own" ON public.push_subscriptions
    FOR ALL USING (auth.uid() = user_id)`, 'policy: push_own'],

  // ── STEP 15: Add tags column to posts ──────────────────────────────────────
  [`ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}'`, 'posts.tags'],

  // ── STEP 16: Set admin role for known admins ────────────────────────────────
  [`UPDATE public.profiles SET role = 'admin'
    WHERE email IN ('brandy13062@gmail.com','uwevetter@gmx.at')`, 'set admin roles'],

  // ── STEP 17: Add realtime for notifications ─────────────────────────────────
  [`DO $$ BEGIN
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    EXCEPTION WHEN duplicate_object THEN NULL; END;
  END $$`, 'realtime: notifications'],
]

async function execSQL(sql: string): Promise<{ ok: boolean; msg: string }> {
  const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false }
  })

  // Try exec_sql RPC (if it was created before)
  const { error } = await supabase.rpc('exec_sql', { sql_text: sql })
  if (!error) return { ok: true, msg: 'ok via rpc' }

  const msg = error.message || ''
  if (msg.includes('already exists') || msg.includes('duplicate')) {
    return { ok: true, msg: 'already exists' }
  }
  if (msg.includes('does not exist') && sql.toLowerCase().startsWith('drop')) {
    return { ok: true, msg: 'already dropped' }
  }

  return { ok: false, msg }
}

export async function GET(req: Request) {
  const url = new URL(req.url)
  const secret = url.searchParams.get('secret') || req.headers.get('x-fix-secret')

  if (secret !== SECRET) {
    return NextResponse.json({
      error: 'Unauthorized',
      hint: 'Pass ?secret=mensaena-fix-rls-2026 or header x-fix-secret'
    }, { status: 401 })
  }

  // First: try to bootstrap exec_sql via the Supabase pg endpoint
  const bootstrapSQL = `
    CREATE OR REPLACE FUNCTION public.exec_sql(sql_text TEXT)
    RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
    BEGIN EXECUTE sql_text; END; $$;
    GRANT EXECUTE ON FUNCTION public.exec_sql(TEXT) TO service_role;
  `

  // Try different bootstrap methods
  let bootstrapResult = 'not attempted'

  // Method 1: Try the Supabase pg endpoint (newer Supabase versions)
  try {
    const r = await fetch(`${SUPABASE_URL}/pg/query`, {
      method: 'POST',
      headers: {
        'apikey': SERVICE_KEY,
        'Authorization': `Bearer ${SERVICE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ query: bootstrapSQL })
    })
    bootstrapResult = `pg endpoint: ${r.status} ${await r.text().then(t => t.slice(0, 100))}`
  } catch (e) {
    bootstrapResult = `pg endpoint error: ${e}`
  }

  // Method 2: Try calling existing exec_sql if it already exists
  const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false }
  })
  const { error: rpcCheckError } = await supabase.rpc('exec_sql', { sql_text: 'SELECT 1' })
  const rpcAvailable = !rpcCheckError || !rpcCheckError.message?.includes('PGRST202')

  if (!rpcAvailable) {
    // Method 3: Try to create exec_sql via the schema endpoint  
    // This is the key insight: we can use supabase.rpc with a custom function
    // that we embed in the migration steps, but we need a way to create it first
    return NextResponse.json({
      status: 'bootstrap_needed',
      bootstrap_result: bootstrapResult,
      rpc_available: rpcAvailable,
      message: 'The exec_sql function is not available. Please go to Supabase Dashboard → SQL Editor and run the BOOTSTRAP_SQL below, then call this endpoint again.',
      bootstrap_sql: bootstrapSQL.trim(),
      dashboard_url: 'https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new',
    })
  }

  // Run all SQL statements
  const results: Array<{ label: string; status: string; msg: string }> = []

  for (const [sql, label] of SQL_STATEMENTS) {
    const r = await execSQL(sql)
    results.push({ label, status: r.ok ? '✅' : '❌', msg: r.msg })
  }

  const okCount = results.filter(r => r.status === '✅').length
  const errCount = results.filter(r => r.status === '❌').length

  return NextResponse.json({
    status: errCount === 0 ? 'SUCCESS' : 'PARTIAL',
    summary: { total: results.length, ok: okCount, errors: errCount },
    results,
  })
}

// Also support POST
export async function POST(req: Request) {
  return GET(req)
}
