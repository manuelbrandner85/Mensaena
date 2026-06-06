-- ════════════════════════════════════════════════════════════════════════
-- Calls + Livestream Infrastructure — idempotent
-- Tabellen: dm_calls, live_rooms, fcm_tokens. Alle mit RLS + Realtime.
-- ════════════════════════════════════════════════════════════════════════

-- ── dm_calls ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.dm_calls (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  caller_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  callee_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  room_name       text NOT NULL,
  status          text NOT NULL DEFAULT 'ringing'
                       CHECK (status IN ('ringing','active','ended','cancelled','missed')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  answered_at     timestamptz,
  ended_at        timestamptz
);

CREATE INDEX IF NOT EXISTS dm_calls_callee_ringing_idx
  ON public.dm_calls(callee_id, created_at DESC)
  WHERE status = 'ringing';
CREATE INDEX IF NOT EXISTS dm_calls_conversation_idx
  ON public.dm_calls(conversation_id, created_at DESC);

ALTER TABLE public.dm_calls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dm_calls_select_participants ON public.dm_calls;
CREATE POLICY dm_calls_select_participants ON public.dm_calls
  FOR SELECT TO authenticated
  USING (auth.uid() = caller_id OR auth.uid() = callee_id);

DROP POLICY IF EXISTS dm_calls_insert_caller ON public.dm_calls;
CREATE POLICY dm_calls_insert_caller ON public.dm_calls
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = caller_id);

DROP POLICY IF EXISTS dm_calls_update_participants ON public.dm_calls;
CREATE POLICY dm_calls_update_participants ON public.dm_calls
  FOR UPDATE TO authenticated
  USING (auth.uid() = caller_id OR auth.uid() = callee_id)
  WITH CHECK (auth.uid() = caller_id OR auth.uid() = callee_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'dm_calls'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.dm_calls;
  END IF;
END $$;

-- ── live_rooms ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.live_rooms (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id      uuid REFERENCES public.chat_channels(id) ON DELETE CASCADE,
  conversation_id uuid REFERENCES public.conversations(id) ON DELETE CASCADE,
  host_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  room_name       text NOT NULL,
  topic           text,
  status          text NOT NULL DEFAULT 'live'
                       CHECK (status IN ('live','ended')),
  started_at      timestamptz NOT NULL DEFAULT now(),
  ended_at        timestamptz
);

-- conversation_id may be missing if the table was created by an earlier
-- migration without this column; add it idempotently before indexing.
ALTER TABLE public.live_rooms
  ADD COLUMN IF NOT EXISTS conversation_id uuid
    REFERENCES public.conversations(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS live_rooms_channel_active_idx
  ON public.live_rooms(channel_id)
  WHERE status = 'live';
CREATE INDEX IF NOT EXISTS live_rooms_conv_active_idx
  ON public.live_rooms(conversation_id)
  WHERE status = 'live';

ALTER TABLE public.live_rooms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS live_rooms_select_all ON public.live_rooms;
CREATE POLICY live_rooms_select_all ON public.live_rooms
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS live_rooms_insert_host ON public.live_rooms;
CREATE POLICY live_rooms_insert_host ON public.live_rooms
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = host_id);

DROP POLICY IF EXISTS live_rooms_update_host ON public.live_rooms;
CREATE POLICY live_rooms_update_host ON public.live_rooms
  FOR UPDATE TO authenticated
  USING (auth.uid() = host_id)
  WITH CHECK (auth.uid() = host_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'live_rooms'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.live_rooms;
  END IF;
END $$;

-- ── fcm_tokens ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token        text NOT NULL,
  platform     text NOT NULL DEFAULT 'android',
  active       boolean NOT NULL DEFAULT true,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, token)
);

CREATE INDEX IF NOT EXISTS fcm_tokens_user_active_idx
  ON public.fcm_tokens(user_id) WHERE active = true;

ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fcm_tokens_owner_all ON public.fcm_tokens;
CREATE POLICY fcm_tokens_owner_all ON public.fcm_tokens
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
