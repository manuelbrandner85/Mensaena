-- ════════════════════════════════════════════════════════════════════════
-- DM-Calls Realtime + FCM-Tokens Index
--
-- Behebt 2 kritische Gaps aus dem 2026-05-23-Audit:
--   1. dm_calls ist nicht in supabase_realtime publication → kein
--      automatischer Realtime-Stream fuer Incoming-Call-Listener.
--   2. fcm_tokens.last_seen_at fehlt im Schema (Flutter schreibt es,
--      Migration legt Spalte an wenn nicht vorhanden).
-- ════════════════════════════════════════════════════════════════════════

-- ── 1. dm_calls zu Realtime-Publication hinzufuegen ──────────────────
DO $$
BEGIN
  -- Pruefe ob Tabelle bereits in Publication ist
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'dm_calls'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.dm_calls;
  END IF;
END $$;

-- REPLICA IDENTITY FULL erlaubt OLD-Werte bei UPDATE-Events
-- (wichtig fuer status-change-Erkennung im Listener).
ALTER TABLE public.dm_calls REPLICA IDENTITY FULL;

-- ── 2. fcm_tokens last_seen_at + platform ────────────────────────────
ALTER TABLE public.fcm_tokens
  ADD COLUMN IF NOT EXISTS last_seen_at timestamptz DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS platform text;

CREATE INDEX IF NOT EXISTS fcm_tokens_user_active_idx
  ON public.fcm_tokens(user_id) WHERE active = true;

COMMENT ON COLUMN public.fcm_tokens.last_seen_at IS
  'Updated whenever the client re-registers, used to identify stale tokens';
COMMENT ON COLUMN public.fcm_tokens.platform IS
  'android | ios | web — von Client gesetzt beim Register';
