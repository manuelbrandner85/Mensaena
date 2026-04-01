-- ============================================================
-- Migration 004: Verbesserungen aller Funktionen
-- ============================================================

-- 1. profiles: Einstellungen, Rolle, PLZ-Ort, anon-flag
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS role              TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user','admin','moderator')),
  ADD COLUMN IF NOT EXISTS notify_email      BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS notify_messages   BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS notify_interactions BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS notify_community  BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS notify_crisis     BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS privacy_location  BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS privacy_email     BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS privacy_phone     BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS privacy_public    BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS home_postal_code  TEXT,
  ADD COLUMN IF NOT EXISTS home_city         TEXT,
  ADD COLUMN IF NOT EXISTS home_lat          DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS home_lng          DOUBLE PRECISION;

-- 2. posts: Anonymität, Bild-URLs, Datum/Zeit für Mobilität, Stunden für Zeitbank
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS is_anonymous      BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS image_url         TEXT,
  ADD COLUMN IF NOT EXISTS event_date        DATE,
  ADD COLUMN IF NOT EXISTS event_time        TEXT,
  ADD COLUMN IF NOT EXISTS duration_hours    NUMERIC(4,1);

-- 3. post_votes: Community-Voting
CREATE TABLE IF NOT EXISTS public.post_votes (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id    UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  vote       SMALLINT NOT NULL CHECK (vote IN (1, -1)),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_votes_post ON public.post_votes(post_id);
ALTER TABLE public.post_votes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "votes_read"   ON public.post_votes FOR SELECT USING (TRUE);
CREATE POLICY "votes_write"  ON public.post_votes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "votes_update" ON public.post_votes FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "votes_delete" ON public.post_votes FOR DELETE USING (auth.uid() = user_id);

-- 4. Hilfsfunktion: Abstand in km (Haversine)
CREATE OR REPLACE FUNCTION public.distance_km(lat1 DOUBLE PRECISION, lng1 DOUBLE PRECISION, lat2 DOUBLE PRECISION, lng2 DOUBLE PRECISION)
RETURNS DOUBLE PRECISION AS $$
  SELECT 6371 * 2 * ASIN(SQRT(
    POWER(SIN((RADIANS(lat2) - RADIANS(lat1)) / 2), 2) +
    COS(RADIANS(lat1)) * COS(RADIANS(lat2)) *
    POWER(SIN((RADIANS(lng2) - RADIANS(lng1)) / 2), 2)
  ))
$$ LANGUAGE sql IMMUTABLE;

