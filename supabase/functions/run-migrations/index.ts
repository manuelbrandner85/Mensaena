import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''

const MIGRATION_SECRET = 'mensaena-migrate-2026'

const STEPS: [string, string][] = [
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
  [`ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT FALSE`, 'posts.is_anonymous'],
  [`ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS image_url TEXT`, 'posts.image_url'],
  [`ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS event_date DATE`, 'posts.event_date'],
  [`ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS event_time TEXT`, 'posts.event_time'],
  [`ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS duration_hours NUMERIC(4,1)`, 'posts.duration_hours'],
  [`ALTER TABLE public.conversation_members ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMPTZ DEFAULT NOW()`, 'cm.last_read_at'],
  [`ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW()`, 'conv.updated_at'],
  [`ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS is_locked BOOLEAN DEFAULT FALSE`, 'conv.is_locked'],
  [`ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS locked_reason TEXT`, 'conv.locked_reason'],
  [`INSERT INTO public.conversations (type, title) SELECT 'system', 'Community Chat' WHERE NOT EXISTS (SELECT 1 FROM public.conversations WHERE type='system' AND title='Community Chat')`, 'Community Chat conv'],
  [`ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ`, 'msg.deleted_at'],
  [`ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ`, 'msg.edited_at'],
  [`ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE`, 'msg.is_pinned'],
  [`CREATE TABLE IF NOT EXISTS public.message_reactions (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE, user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, emoji TEXT NOT NULL, created_at TIMESTAMPTZ DEFAULT NOW(), UNIQUE(message_id, user_id, emoji))`, 'CREATE message_reactions'],
  [`ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY`, 'RLS message_reactions'],
  [`CREATE TABLE IF NOT EXISTS public.chat_banned_users (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, banned_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, reason TEXT, banned_at TIMESTAMPTZ DEFAULT NOW(), expires_at TIMESTAMPTZ, UNIQUE(user_id))`, 'CREATE chat_banned_users'],
  [`ALTER TABLE public.chat_banned_users ENABLE ROW LEVEL SECURITY`, 'RLS chat_banned_users'],
  [`ALTER TABLE public.conversation_members ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'member'`, 'cm.role'],
  [`CREATE TABLE IF NOT EXISTS public.chat_channels (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), name TEXT NOT NULL, description TEXT, emoji TEXT DEFAULT '💬', slug TEXT UNIQUE NOT NULL, is_default BOOLEAN DEFAULT FALSE, is_locked BOOLEAN DEFAULT FALSE, locked_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL, locked_at TIMESTAMPTZ, locked_reason TEXT, sort_order INTEGER DEFAULT 0, created_at TIMESTAMPTZ DEFAULT NOW(), conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE)`, 'CREATE chat_channels'],
  [`ALTER TABLE public.chat_channels ENABLE ROW LEVEL SECURITY`, 'RLS chat_channels'],
  [`DO $do$ DECLARE v UUID; BEGIN SELECT id INTO v FROM public.conversations WHERE type='system' AND title='Community Chat' LIMIT 1; IF v IS NOT NULL THEN INSERT INTO public.chat_channels(name,description,emoji,slug,is_default,sort_order,conversation_id) VALUES('Allgemein','Allgemeine Diskussion','💬','allgemein',TRUE,1,v) ON CONFLICT(slug) DO NOTHING; END IF; END $do$`, 'Channel: Allgemein'],
  [`INSERT INTO public.conversations(type,title) SELECT 'system','Kanal: Hilfe gesucht' WHERE NOT EXISTS(SELECT 1 FROM public.conversations WHERE title='Kanal: Hilfe gesucht')`, 'Conv: Hilfe gesucht'],
  [`DO $do$ DECLARE v UUID; BEGIN SELECT id INTO v FROM public.conversations WHERE title='Kanal: Hilfe gesucht' LIMIT 1; IF v IS NOT NULL THEN INSERT INTO public.chat_channels(name,description,emoji,slug,sort_order,conversation_id) VALUES('Hilfe gesucht','Hilfe anfragen','🆘','hilfe-gesucht',2,v) ON CONFLICT(slug) DO NOTHING; END IF; END $do$`, 'Channel: Hilfe gesucht'],
  [`INSERT INTO public.conversations(type,title) SELECT 'system','Kanal: Hilfe anbieten' WHERE NOT EXISTS(SELECT 1 FROM public.conversations WHERE title='Kanal: Hilfe anbieten')`, 'Conv: Hilfe anbieten'],
  [`DO $do$ DECLARE v UUID; BEGIN SELECT id INTO v FROM public.conversations WHERE title='Kanal: Hilfe anbieten' LIMIT 1; IF v IS NOT NULL THEN INSERT INTO public.chat_channels(name,description,emoji,slug,sort_order,conversation_id) VALUES('Hilfe anbieten','Hilfe anbieten','🤝','hilfe-anbieten',3,v) ON CONFLICT(slug) DO NOTHING; END IF; END $do$`, 'Channel: Hilfe anbieten'],
  [`INSERT INTO public.conversations(type,title) SELECT 'system','Kanal: Tiere & Natur' WHERE NOT EXISTS(SELECT 1 FROM public.conversations WHERE title='Kanal: Tiere & Natur')`, 'Conv: Tiere & Natur'],
  [`DO $do$ DECLARE v UUID; BEGIN SELECT id INTO v FROM public.conversations WHERE title='Kanal: Tiere & Natur' LIMIT 1; IF v IS NOT NULL THEN INSERT INTO public.chat_channels(name,description,emoji,slug,sort_order,conversation_id) VALUES('Tiere & Natur','Austausch über Tiere','🐾','tiere-natur',4,v) ON CONFLICT(slug) DO NOTHING; END IF; END $do$`, 'Channel: Tiere & Natur'],
  [`CREATE TABLE IF NOT EXISTS public.message_pins (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE, conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE, pinned_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, pinned_at TIMESTAMPTZ DEFAULT NOW(), UNIQUE(message_id))`, 'CREATE message_pins'],
  [`ALTER TABLE public.message_pins ENABLE ROW LEVEL SECURITY`, 'RLS message_pins'],
  [`CREATE TABLE IF NOT EXISTS public.chat_announcements (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), title TEXT NOT NULL, content TEXT NOT NULL, type TEXT DEFAULT 'info', is_active BOOLEAN DEFAULT TRUE, created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL, created_at TIMESTAMPTZ DEFAULT NOW(), expires_at TIMESTAMPTZ)`, 'CREATE chat_announcements'],
  [`ALTER TABLE public.chat_announcements ENABLE ROW LEVEL SECURITY`, 'RLS chat_announcements'],
]

Deno.serve(async (req: Request) => {
  const secret = req.headers.get('x-migration-secret')
  if (secret !== MIGRATION_SECRET) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false }
  })

  const results: { label: string; status: string; msg: string }[] = []
  
  for (const [sql, label] of STEPS) {
    const { error } = await supabase.rpc('exec_sql', { sql_text: sql })
    if (!error || error.message?.includes('already exists') || error.message?.includes('duplicate')) {
      results.push({ label, status: '✅', msg: error?.message || 'ok' })
    } else if (error.message?.includes('PGRST202') || error.message?.includes('could not find')) {
      results.push({ label, status: '⚠️', msg: 'no exec_sql RPC' })
      break
    } else {
      results.push({ label, status: '❌', msg: error.message })
    }
  }

  return new Response(JSON.stringify({ results }, null, 2), {
    headers: { 'Content-Type': 'application/json' }
  })
})
