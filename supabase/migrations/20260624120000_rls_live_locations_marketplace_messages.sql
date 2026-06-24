-- RLS für live_locations und marketplace_messages aktivieren.
--
-- live_locations: Eigentümer darf CRUD; Mitglieder derselben Conversation
--   dürfen SELECT.
-- marketplace_messages: Sender/Empfänger dürfen SELECT; nur Sender darf INSERT.

-- ============================================================
-- live_locations
-- ============================================================

ALTER TABLE public.live_locations ENABLE ROW LEVEL SECURITY;

-- Owner: voller Zugriff auf eigene Zeilen
DROP POLICY IF EXISTS ll_owner ON public.live_locations;
CREATE POLICY ll_owner ON public.live_locations
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Conversation-Mitglieder: nur lesen
DROP POLICY IF EXISTS ll_conv_member_select ON public.live_locations;
CREATE POLICY ll_conv_member_select ON public.live_locations
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.conversation_members cm
      WHERE cm.conversation_id = live_locations.conversation_id
        AND cm.user_id = (SELECT auth.uid())
    )
  );

-- ============================================================
-- marketplace_messages
-- ============================================================

ALTER TABLE public.marketplace_messages ENABLE ROW LEVEL SECURITY;

-- Sender und Empfänger dürfen lesen
DROP POLICY IF EXISTS mm_select ON public.marketplace_messages;
CREATE POLICY mm_select ON public.marketplace_messages
  FOR SELECT
  USING ((SELECT auth.uid()) IN (sender_id, receiver_id));

-- Nur der Sender darf eine Nachricht anlegen
DROP POLICY IF EXISTS mm_insert ON public.marketplace_messages;
CREATE POLICY mm_insert ON public.marketplace_messages
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = sender_id);
