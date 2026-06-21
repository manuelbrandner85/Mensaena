-- ════════════════════════════════════════════════════════════════════════
-- Wiederherstellung nach DB-Reset — behebt mehrere kritische Realtime-/Push-Bugs
--
-- Symptome (vom User gemeldet + per Live-DB-Audit bestätigt):
--   • 1:1-DM-Anruf klingelt NICHT beim Angerufenen, kann nicht angenommen werden
--     (weder bei offener noch geschlossener App)
--   • Community-Livestream: niemand sieht offene Streams, kann nicht beitreten,
--     jeder öffnet nur seinen eigenen, Einladen schlägt fehl
--   • (Folge) kein Echtzeit-Chat, keine Echtzeit-Notifications
--
-- Root-Causes (durch Live-Queries belegt — Client-Code war korrekt):
--   1) pg_net war NICHT installiert  → net.http_post in allen Push-Triggern
--      wirft still → KEIN FCM-Push wird je gesendet.
--   2) supabase_realtime-Publication enthielt NUR safety_reports → kein einziges
--      Realtime-Delta für dm_calls/live_rooms/notifications/messages.
--   3) notifications_type_check kannte 'livestream_invite' nicht → Invite-Insert
--      scheiterte mit 23514.
--
-- Diese Migration ist idempotent und stellt alles wieder her.
-- ════════════════════════════════════════════════════════════════════════

-- ── 1) pg_net (für net.http_post in den Push-Triggern) ───────────────
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ── 2) Realtime-Publication reparieren ───────────────────────────────
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'dm_calls','live_rooms','notifications','messages',
    'message_reactions','livestream_messages'
  ]
  LOOP
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema='public' AND table_name=t
    ) AND NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;

-- REPLICA IDENTITY FULL, damit UPDATE-Deltas (live_rooms→ended,
-- dm_calls→answered/ended, notifications→read) vollständig ankommen.
ALTER TABLE public.dm_calls      REPLICA IDENTITY FULL;
ALTER TABLE public.live_rooms    REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- ── 3) notifications_type_check um 'livestream_invite' erweitern ──────
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check CHECK (
  type = ANY (ARRAY[
    'comment','conversation_added','crisis_alert','friend_accepted','friend_request',
    'help_found','incoming_call','interaction_created','interaction','live_room_started',
    'livestream_invite','match_both_accepted','match_partner_accepted','mention','message',
    'new_match','post_nearby','post_update','rating','system'
  ])
);
