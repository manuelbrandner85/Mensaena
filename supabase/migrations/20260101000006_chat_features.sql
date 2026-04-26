-- ============================================================
-- MENSAENA – Migration 006: Chat-Features
-- - is_locked flag auf conversations (Admin kann sperren)
-- - deleted_at auf messages (Soft-Delete)
-- - message_reactions Tabelle (Emoji-Reaktionen)
-- - chat_banned_users Tabelle (Admin-Bans vom Chat)
-- ============================================================

-- 1. is_locked auf conversations
ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS is_locked BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS locked_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS locked_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS locked_reason TEXT;

-- 2. Soft-Delete auf messages
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL;

-- 3. message_reactions Tabelle
CREATE TABLE IF NOT EXISTS public.message_reactions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  message_id      UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  emoji           TEXT NOT NULL,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(message_id, user_id, emoji)
);

CREATE INDEX IF NOT EXISTS idx_msg_reactions_msg   ON public.message_reactions(message_id);
CREATE INDEX IF NOT EXISTS idx_msg_reactions_user  ON public.message_reactions(user_id);

ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "reactions_read"   ON public.message_reactions FOR SELECT USING (TRUE);
CREATE POLICY "reactions_insert" ON public.message_reactions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "reactions_delete" ON public.message_reactions FOR DELETE USING (auth.uid() = user_id);

-- 4. chat_banned_users Tabelle
CREATE TABLE IF NOT EXISTS public.chat_banned_users (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  banned_by   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason      TEXT,
  banned_at   TIMESTAMPTZ DEFAULT NOW(),
  expires_at  TIMESTAMPTZ,
  UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_banned_user ON public.chat_banned_users(user_id);

ALTER TABLE public.chat_banned_users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "chat_banned_read"   ON public.chat_banned_users FOR SELECT USING (TRUE);
CREATE POLICY "chat_banned_admin"  ON public.chat_banned_users FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  OR auth.uid()::text = ANY(ARRAY['brandy13062@gmail.com', 'uwevetter@gmx.at'])
);

-- 5. Admin darf eigene Nachrichten und alle Nachrichten löschen
DROP POLICY IF EXISTS "messages_delete" ON public.messages;
CREATE POLICY "messages_delete" ON public.messages
  FOR UPDATE USING (
    auth.uid() = sender_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 6. Admin darf conversations sperren
DROP POLICY IF EXISTS "conversations_admin_update" ON public.conversations;
CREATE POLICY "conversations_admin_update" ON public.conversations
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    OR auth.uid() IS NOT NULL
  );

-- 7. Realtime für Reaktionen und Bans
ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reactions;
