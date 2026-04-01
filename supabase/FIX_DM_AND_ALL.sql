-- ============================================================
-- MENSAENA – Complete DM Fix + Production Polish
-- Run at: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new
-- ============================================================

-- 1. Ensure helper functions exist (idempotent)
CREATE OR REPLACE FUNCTION public.is_conversation_member(conv_id UUID, uid UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.conversation_members
    WHERE conversation_id = conv_id AND user_id = uid
  );
$$;

CREATE OR REPLACE FUNCTION public.get_conversation_type(conv_id UUID)
RETURNS TEXT LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT type FROM public.conversations WHERE id = conv_id;
$$;

-- 2. Drop ALL existing policies on key tables (clean slate)
DO $$ DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT policyname, tablename FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename IN ('conversations','conversation_members','messages','message_reactions','message_pins','chat_announcements','chat_banned_users','user_status','push_subscriptions','notifications')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

-- 3. conversation_members policies
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cm_select" ON public.conversation_members
  FOR SELECT USING (
    auth.uid() IS NOT NULL AND (
      user_id = auth.uid()
      OR public.is_conversation_member(conversation_id, auth.uid())
    )
  );

CREATE POLICY "cm_insert" ON public.conversation_members
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "cm_update" ON public.conversation_members
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "cm_delete" ON public.conversation_members
  FOR DELETE USING (user_id = auth.uid() OR EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ));

-- 4. conversations policies
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "conv_select" ON public.conversations
  FOR SELECT USING (
    auth.uid() IS NOT NULL AND (
      type = 'system'
      OR public.is_conversation_member(id, auth.uid())
    )
  );

CREATE POLICY "conv_insert" ON public.conversations
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "conv_update" ON public.conversations
  FOR UPDATE USING (
    public.is_conversation_member(id, auth.uid())
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    OR auth.email() = ANY(ARRAY['brandy13062@gmail.com','uwevetter@gmx.at'])
  );

CREATE POLICY "conv_delete" ON public.conversations
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    OR auth.email() = ANY(ARRAY['brandy13062@gmail.com','uwevetter@gmx.at'])
  );

-- 5. messages policies
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "msg_select" ON public.messages
  FOR SELECT USING (
    auth.uid() IS NOT NULL AND (
      public.get_conversation_type(conversation_id) = 'system'
      OR public.is_conversation_member(conversation_id, auth.uid())
    )
  );

CREATE POLICY "msg_insert" ON public.messages
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
    AND sender_id = auth.uid()
    AND (
      public.get_conversation_type(conversation_id) = 'system'
      OR public.is_conversation_member(conversation_id, auth.uid())
    )
  );

CREATE POLICY "msg_update" ON public.messages
  FOR UPDATE USING (
    sender_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    OR auth.email() = ANY(ARRAY['brandy13062@gmail.com','uwevetter@gmx.at'])
  );

CREATE POLICY "msg_delete" ON public.messages
  FOR DELETE USING (
    sender_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    OR auth.email() = ANY(ARRAY['brandy13062@gmail.com','uwevetter@gmx.at'])
  );

-- 6. message_reactions
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "reactions_select" ON public.message_reactions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "reactions_insert" ON public.message_reactions FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());
CREATE POLICY "reactions_delete" ON public.message_reactions FOR DELETE USING (user_id = auth.uid());

-- 7. message_pins
ALTER TABLE public.message_pins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "pins_select" ON public.message_pins FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "pins_admin" ON public.message_pins FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  OR auth.email() = ANY(ARRAY['brandy13062@gmail.com','uwevetter@gmx.at'])
);

-- 8. chat_announcements
ALTER TABLE public.chat_announcements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "announce_select" ON public.chat_announcements FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "announce_admin" ON public.chat_announcements FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  OR auth.email() = ANY(ARRAY['brandy13062@gmail.com','uwevetter@gmx.at'])
);

-- 9. chat_banned_users
ALTER TABLE public.chat_banned_users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ban_select" ON public.chat_banned_users FOR SELECT USING (
  user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  OR auth.email() = ANY(ARRAY['brandy13062@gmail.com','uwevetter@gmx.at'])
);
CREATE POLICY "ban_admin" ON public.chat_banned_users FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  OR auth.email() = ANY(ARRAY['brandy13062@gmail.com','uwevetter@gmx.at'])
);

-- 10. user_status (if exists)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_status') THEN
    ALTER TABLE public.user_status ENABLE ROW LEVEL SECURITY;
    EXECUTE 'CREATE POLICY "status_select" ON public.user_status FOR SELECT USING (auth.uid() IS NOT NULL)';
    EXECUTE 'CREATE POLICY "status_own" ON public.user_status FOR ALL USING (user_id = auth.uid())';
  END IF;
END $$;

-- 11. push_subscriptions
CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  endpoint TEXT NOT NULL,
  p256dh TEXT NOT NULL,
  auth_key TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "push_own" ON public.push_subscriptions FOR ALL USING (user_id = auth.uid());

-- 12. notifications
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL DEFAULT 'info',
  title TEXT NOT NULL,
  body TEXT,
  url TEXT,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS notifications_user_idx ON public.notifications(user_id, created_at DESC);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "notifications_own" ON public.notifications FOR ALL USING (user_id = auth.uid());

-- Add to realtime if not already
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;

-- 13. Make brandy13062 and uwevetter admins
UPDATE public.profiles SET role = 'admin'
WHERE email IN ('brandy13062@gmail.com', 'uwevetter@gmx.at');

-- 14. Add tags column to posts if missing
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

-- 15. Add post_votes table if missing
CREATE TABLE IF NOT EXISTS public.post_votes (
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  vote SMALLINT NOT NULL CHECK (vote IN (-1, 1)),
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);
ALTER TABLE public.post_votes ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "votes_select" ON public.post_votes FOR SELECT USING (true);
CREATE POLICY IF NOT EXISTS "votes_own" ON public.post_votes FOR ALL USING (user_id = auth.uid());

-- 16. Add event_date, event_time, duration_hours to posts if missing
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS event_date DATE;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS event_time TIME;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS duration_hours NUMERIC(4,1);

-- 17. Add home location columns to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_city TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_postal_code TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_lat DOUBLE PRECISION;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_lng DOUBLE PRECISION;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_email BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_messages BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_interactions BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_community BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_crisis BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_location BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_email BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_phone BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_public BOOLEAN DEFAULT true;

-- 18. Verify
SELECT 
  'FIX COMPLETE' AS status,
  (SELECT COUNT(*) FROM public.conversations WHERE type = 'system') AS system_channels,
  (SELECT COUNT(*) FROM public.profiles WHERE role = 'admin') AS admins,
  (SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public' AND tablename IN ('conversations','conversation_members','messages')) AS rls_policies;
