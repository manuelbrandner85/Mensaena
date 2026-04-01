import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

// One-time migration endpoint - secured via secret header
export async function GET(req: Request) {
  const secret = new URL(req.url).searchParams.get('secret')
  if (secret !== 'mensaena_migrate_2026') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } }
  )

  const statements = [
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user'`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_email BOOLEAN DEFAULT TRUE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_messages BOOLEAN DEFAULT TRUE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_interactions BOOLEAN DEFAULT TRUE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_community BOOLEAN DEFAULT FALSE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_crisis BOOLEAN DEFAULT TRUE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_location BOOLEAN DEFAULT TRUE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_email BOOLEAN DEFAULT FALSE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_phone BOOLEAN DEFAULT FALSE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_public BOOLEAN DEFAULT TRUE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_postal_code TEXT`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_city TEXT`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_lat DOUBLE PRECISION`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_lng DOUBLE PRECISION`,
    `ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT FALSE`,
    `ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS image_url TEXT`,
    `ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS event_date DATE`,
    `ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS event_time TEXT`,
    `ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS duration_hours NUMERIC(4,1)`,
    `CREATE TABLE IF NOT EXISTS public.post_votes (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      vote SMALLINT NOT NULL CHECK (vote IN (1,-1)),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(post_id, user_id)
    )`,
    `ALTER TABLE public.post_votes ENABLE ROW LEVEL SECURITY`,
    `DO $$ BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='post_votes' AND policyname='votes_read') THEN
        CREATE POLICY "votes_read" ON public.post_votes FOR SELECT USING (TRUE);
      END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='post_votes' AND policyname='votes_write') THEN
        CREATE POLICY "votes_write" ON public.post_votes FOR INSERT WITH CHECK (auth.uid() = user_id);
      END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='post_votes' AND policyname='votes_delete') THEN
        CREATE POLICY "votes_delete" ON public.post_votes FOR DELETE USING (auth.uid() = user_id);
      END IF;
    END $$`,
    // Migration 005: Chat improvements
    `ALTER TABLE public.conversation_members ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMPTZ DEFAULT NOW()`,
    `ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS post_id UUID REFERENCES public.posts(id) ON DELETE SET NULL`,
    `ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW()`,
    `CREATE INDEX IF NOT EXISTS idx_conversations_post_id ON public.conversations(post_id)`,
    `CREATE OR REPLACE FUNCTION public.update_conversation_on_message()
     RETURNS TRIGGER AS $$
     BEGIN
       UPDATE public.conversations SET updated_at = NOW() WHERE id = NEW.conversation_id;
       RETURN NEW;
     END;
     $$ LANGUAGE plpgsql`,
    `DROP TRIGGER IF EXISTS message_updates_conversation ON public.messages`,
    `CREATE TRIGGER message_updates_conversation
       AFTER INSERT ON public.messages
       FOR EACH ROW EXECUTE FUNCTION public.update_conversation_on_message()`,
    `DO $$ BEGIN
       IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='conversation_members' AND policyname='conv_members_update') THEN
         CREATE POLICY "conv_members_update" ON public.conversation_members FOR UPDATE USING (user_id = auth.uid());
       END IF;
     END $$`,
    // Community system room (idempotent)
    `DO $$
     DECLARE v_room_id UUID;
     BEGIN
       SELECT id INTO v_room_id FROM public.conversations WHERE type = 'system' AND title = 'Community Chat' LIMIT 1;
       IF v_room_id IS NULL THEN
         INSERT INTO public.conversations (type, title) VALUES ('system', 'Community Chat');
       END IF;
     END $$`,
    // Updated RLS for system rooms
    `DO $$ BEGIN
       IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='conversations' AND policyname='community_room_read') THEN
         CREATE POLICY "community_room_read" ON public.conversations FOR SELECT USING (
           type = 'system' OR EXISTS (SELECT 1 FROM public.conversation_members WHERE conversation_id = id AND user_id = auth.uid())
         );
       END IF;
     END $$`,
    `DO $$ BEGIN
       IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='messages' AND policyname='community_room_messages_read') THEN
         CREATE POLICY "community_room_messages_read" ON public.messages FOR SELECT USING (
           EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = messages.conversation_id AND (c.type = 'system' OR EXISTS (SELECT 1 FROM public.conversation_members cm WHERE cm.conversation_id = c.id AND cm.user_id = auth.uid())))
         );
       END IF;
     END $$`,
    `DO $$ BEGIN
       IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='messages' AND policyname='community_room_messages_insert') THEN
         CREATE POLICY "community_room_messages_insert" ON public.messages FOR INSERT WITH CHECK (
           sender_id = auth.uid() AND EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = messages.conversation_id AND (c.type = 'system' OR EXISTS (SELECT 1 FROM public.conversation_members cm WHERE cm.conversation_id = c.id AND cm.user_id = auth.uid())))
         );
       END IF;
     END $$`,
  ]

  const results: { sql: string; ok: boolean; error?: string }[] = []
  
  for (const sql of statements) {
    const { error } = await supabase.rpc('exec_migration', { sql_statement: sql })
    if (error && !error.message.includes('already exists') && !error.message.includes('duplicate')) {
      results.push({ sql: sql.slice(0, 60), ok: false, error: error.message })
    } else {
      results.push({ sql: sql.slice(0, 60), ok: true })
    }
  }

  return NextResponse.json({ results })
}
