-- ════════════════════════════════════════════════════════════════════════
-- Live-Rooms — Channel-Livestreams
--
-- Tabelle fuer aktive/beendete Live-Rooms in Community-Channels.
-- DM-Calls nutzen die separate `dm_calls`-Tabelle.
-- ════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.live_rooms (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_name   text NOT NULL UNIQUE,
  channel_id  uuid REFERENCES public.chat_channels(id) ON DELETE CASCADE,
  host_id     uuid NOT NULL REFERENCES auth.users(id),
  topic       text,
  status      text NOT NULL DEFAULT 'live' CHECK (status IN ('live','ended')),
  started_at  timestamptz NOT NULL DEFAULT now(),
  ended_at    timestamptz
);

CREATE INDEX IF NOT EXISTS live_rooms_channel_active_idx
  ON public.live_rooms(channel_id)
  WHERE status = 'live';

CREATE INDEX IF NOT EXISTS live_rooms_started_at_idx
  ON public.live_rooms(started_at DESC);

ALTER TABLE public.live_rooms ENABLE ROW LEVEL SECURITY;

-- Realtime-Publish (fuer Flutter-Live-Banner-Subscribe)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'live_rooms'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.live_rooms;
  END IF;
END $$;

DROP POLICY IF EXISTS live_rooms_read_all ON public.live_rooms;
CREATE POLICY live_rooms_read_all
  ON public.live_rooms
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS live_rooms_host_insert ON public.live_rooms;
CREATE POLICY live_rooms_host_insert
  ON public.live_rooms
  FOR INSERT
  WITH CHECK (auth.uid() = host_id);

DROP POLICY IF EXISTS live_rooms_host_update ON public.live_rooms;
CREATE POLICY live_rooms_host_update
  ON public.live_rooms
  FOR UPDATE
  USING (auth.uid() = host_id)
  WITH CHECK (auth.uid() = host_id);

DROP POLICY IF EXISTS live_rooms_host_delete ON public.live_rooms;
CREATE POLICY live_rooms_host_delete
  ON public.live_rooms
  FOR DELETE
  USING (auth.uid() = host_id);
