-- Channel categories column
ALTER TABLE chat_channels ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'Allgemein';

-- ── Polls ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS channel_polls (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id  uuid REFERENCES chat_channels(id) ON DELETE CASCADE,
  created_by  uuid REFERENCES profiles(id) ON DELETE CASCADE,
  question    text NOT NULL,
  options     jsonb NOT NULL DEFAULT '[]',
  ends_at     timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS poll_votes (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id      uuid REFERENCES channel_polls(id) ON DELETE CASCADE,
  user_id      uuid REFERENCES profiles(id) ON DELETE CASCADE,
  option_index int NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(poll_id, user_id)
);

ALTER TABLE channel_polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_votes    ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "everyone can read polls" ON channel_polls;
CREATE POLICY "everyone can read polls" ON channel_polls FOR SELECT USING (true);
DROP POLICY IF EXISTS "members can create polls" ON channel_polls;
CREATE POLICY "members can create polls" ON channel_polls FOR INSERT WITH CHECK (auth.uid() = created_by);

DROP POLICY IF EXISTS "everyone can read votes" ON poll_votes;
CREATE POLICY "everyone can read votes" ON poll_votes FOR SELECT USING (true);
DROP POLICY IF EXISTS "members can vote" ON poll_votes;
CREATE POLICY "members can vote" ON poll_votes FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "members can change vote" ON poll_votes;
CREATE POLICY "members can change vote" ON poll_votes FOR DELETE USING (auth.uid() = user_id);

-- ── Channel Events (Scheduled Live Rooms) ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS channel_events (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id   uuid REFERENCES chat_channels(id) ON DELETE CASCADE,
  created_by   uuid REFERENCES profiles(id) ON DELETE CASCADE,
  title        text NOT NULL,
  scheduled_at timestamptz NOT NULL,
  room_name    text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS event_rsvps (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id   uuid REFERENCES channel_events(id) ON DELETE CASCADE,
  user_id    uuid REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(event_id, user_id)
);

ALTER TABLE channel_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_rsvps    ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "everyone can read events" ON channel_events;
CREATE POLICY "everyone can read events" ON channel_events FOR SELECT USING (true);
DROP POLICY IF EXISTS "members can create events" ON channel_events;
CREATE POLICY "members can create events" ON channel_events FOR INSERT WITH CHECK (auth.uid() = created_by);
DROP POLICY IF EXISTS "admin can delete events" ON channel_events;
CREATE POLICY "admin can delete events" ON channel_events FOR DELETE USING (auth.uid() = created_by);

DROP POLICY IF EXISTS "everyone can read rsvps" ON event_rsvps;
CREATE POLICY "everyone can read rsvps" ON event_rsvps FOR SELECT USING (true);
DROP POLICY IF EXISTS "members can rsvp" ON event_rsvps;
CREATE POLICY "members can rsvp" ON event_rsvps FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "members can un-rsvp" ON event_rsvps;
CREATE POLICY "members can un-rsvp" ON event_rsvps FOR DELETE USING (auth.uid() = user_id);
