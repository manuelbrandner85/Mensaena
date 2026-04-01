-- ============================================================
-- MENSAENA – Migration 005: Chat-Erweiterungen
-- - last_read_at pro conversation_member (für Unread-Badges)
-- - post_id Referenz auf messages (DM aus Inserat heraus)
-- - community_room: System-Gruppenraum für öffentlichen Chat
-- ============================================================

-- 1. last_read_at auf conversation_members
ALTER TABLE public.conversation_members
  ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMPTZ DEFAULT NOW();

-- 2. Referenz: von welchem Inserat wurde die DM gestartet
ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS post_id UUID REFERENCES public.posts(id) ON DELETE SET NULL;

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Index für schnelles Finden per post_id
CREATE INDEX IF NOT EXISTS idx_conversations_post_id ON public.conversations(post_id);

-- 3. Trigger: conversations.updated_at automatisch setzen
CREATE OR REPLACE FUNCTION public.handle_conversations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS conversations_updated_at ON public.conversations;
CREATE TRIGGER conversations_updated_at
  BEFORE UPDATE ON public.conversations
  FOR EACH ROW EXECUTE FUNCTION public.handle_conversations_updated_at();

-- 4. Trigger: conversations.updated_at beim neuen Message aktualisieren
CREATE OR REPLACE FUNCTION public.update_conversation_on_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.conversations SET updated_at = NOW() WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS message_updates_conversation ON public.messages;
CREATE TRIGGER message_updates_conversation
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.update_conversation_on_message();

-- 5. RLS: Mitglieder dürfen last_read_at updaten
DROP POLICY IF EXISTS "conv_members_update" ON public.conversation_members;
CREATE POLICY "conv_members_update" ON public.conversation_members
  FOR UPDATE USING (user_id = auth.uid());

-- 6. Community-Gruppen-Raum anlegen (idempotent via DO-Block)
DO $$
DECLARE
  v_room_id UUID;
BEGIN
  -- Prüfe ob Community-Raum bereits existiert
  SELECT id INTO v_room_id
  FROM public.conversations
  WHERE type = 'system' AND title = 'Community Chat'
  LIMIT 1;

  IF v_room_id IS NULL THEN
    INSERT INTO public.conversations (type, title)
    VALUES ('system', 'Community Chat')
    RETURNING id INTO v_room_id;
  END IF;
END $$;

-- 7. Policy: System-Raum ist für alle authentifizierten Nutzer lesbar
DROP POLICY IF EXISTS "community_room_read" ON public.conversations;
CREATE POLICY "community_room_read" ON public.conversations
  FOR SELECT USING (
    type = 'system'
    OR EXISTS (
      SELECT 1 FROM public.conversation_members
      WHERE conversation_id = id AND user_id = auth.uid()
    )
  );

-- 8. Policy: Nachrichten in System-Raum für alle Auth-Nutzer
DROP POLICY IF EXISTS "community_room_messages_read" ON public.messages;
CREATE POLICY "community_room_messages_read" ON public.messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = messages.conversation_id
      AND (
        c.type = 'system'
        OR EXISTS (
          SELECT 1 FROM public.conversation_members cm
          WHERE cm.conversation_id = c.id AND cm.user_id = auth.uid()
        )
      )
    )
  );

DROP POLICY IF EXISTS "community_room_messages_insert" ON public.messages;
CREATE POLICY "community_room_messages_insert" ON public.messages
  FOR INSERT WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = messages.conversation_id
      AND (
        c.type = 'system'
        OR EXISTS (
          SELECT 1 FROM public.conversation_members cm
          WHERE cm.conversation_id = c.id AND cm.user_id = auth.uid()
        )
      )
    )
  );

-- Realtime für conversations (für last_message Updates in der Liste)
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_members;
