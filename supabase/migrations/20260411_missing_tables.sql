-- ============================================================================
-- Migration 20260411: Create 8 missing tables required by the frontend
-- Tables: crisis_helpers, crisis_updates, emergency_numbers, match_preferences,
--         organization_review_helpful, organization_suggestions, post_reactions, reports
-- ============================================================================
-- Run via: Supabase SQL Editor  OR  exec_sql()
-- Date: 2026-04-11
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. crisis_helpers – Volunteers offering help during a crisis
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.crisis_helpers (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  crisis_id     UUID NOT NULL REFERENCES public.crises(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status        TEXT NOT NULL DEFAULT 'offered'
                  CHECK (status IN ('offered','accepted','on_way','arrived','completed','withdrawn')),
  message       TEXT,
  skills        TEXT[] NOT NULL DEFAULT '{}',
  eta_minutes   INT,
  latitude      DOUBLE PRECISION,
  longitude     DOUBLE PRECISION,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (crisis_id, user_id)  -- one offer per user per crisis
);

CREATE INDEX IF NOT EXISTS idx_crisis_helpers_crisis  ON public.crisis_helpers(crisis_id);
CREATE INDEX IF NOT EXISTS idx_crisis_helpers_user    ON public.crisis_helpers(user_id);
CREATE INDEX IF NOT EXISTS idx_crisis_helpers_status  ON public.crisis_helpers(status);

-- updated_at trigger
CREATE OR REPLACE FUNCTION public.trg_crisis_helpers_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS crisis_helpers_updated_at ON public.crisis_helpers;
CREATE TRIGGER crisis_helpers_updated_at BEFORE UPDATE ON public.crisis_helpers
  FOR EACH ROW EXECUTE FUNCTION public.trg_crisis_helpers_updated_at();

-- RLS
ALTER TABLE public.crisis_helpers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "crisis_helpers_select" ON public.crisis_helpers;
CREATE POLICY "crisis_helpers_select" ON public.crisis_helpers FOR SELECT
  USING (true);  -- anyone can see helpers

DROP POLICY IF EXISTS "crisis_helpers_insert" ON public.crisis_helpers;
CREATE POLICY "crisis_helpers_insert" ON public.crisis_helpers FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "crisis_helpers_update" ON public.crisis_helpers;
CREATE POLICY "crisis_helpers_update" ON public.crisis_helpers FOR UPDATE
  USING (auth.uid() = user_id
    OR auth.uid() IN (SELECT creator_id FROM public.crises WHERE id = crisis_id)
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

DROP POLICY IF EXISTS "crisis_helpers_delete" ON public.crisis_helpers;
CREATE POLICY "crisis_helpers_delete" ON public.crisis_helpers FOR DELETE
  USING (auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

-- Realtime (idempotent – table may already be in publication from 20260408_crisis_system.sql)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'crisis_helpers') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.crisis_helpers;
  END IF;
END $$;


-- ============================================================================
-- 2. crisis_updates – Timeline updates for a crisis
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.crisis_updates (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  crisis_id     UUID NOT NULL REFERENCES public.crises(id) ON DELETE CASCADE,
  author_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content       TEXT NOT NULL,
  update_type   TEXT NOT NULL DEFAULT 'info'
                  CHECK (update_type IN ('info','status_change','resource_update','helper_update','resolution','warning','official')),
  image_url     TEXT,
  is_pinned     BOOLEAN NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crisis_updates_crisis ON public.crisis_updates(crisis_id);
CREATE INDEX IF NOT EXISTS idx_crisis_updates_author ON public.crisis_updates(author_id);

ALTER TABLE public.crisis_updates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "crisis_updates_select" ON public.crisis_updates;
CREATE POLICY "crisis_updates_select" ON public.crisis_updates FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "crisis_updates_insert" ON public.crisis_updates;
CREATE POLICY "crisis_updates_insert" ON public.crisis_updates FOR INSERT
  WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "crisis_updates_update" ON public.crisis_updates;
CREATE POLICY "crisis_updates_update" ON public.crisis_updates FOR UPDATE
  USING (auth.uid() = author_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

DROP POLICY IF EXISTS "crisis_updates_delete" ON public.crisis_updates;
CREATE POLICY "crisis_updates_delete" ON public.crisis_updates FOR DELETE
  USING (auth.uid() = author_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'crisis_updates') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.crisis_updates;
  END IF;
END $$;


-- ============================================================================
-- 3. emergency_numbers – Static emergency hotlines for DE/AT/CH
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.emergency_numbers (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  country       TEXT NOT NULL CHECK (country IN ('DE','AT','CH')),
  category      TEXT NOT NULL DEFAULT 'emergency',
  label         TEXT NOT NULL,
  number        TEXT NOT NULL,
  description   TEXT,
  is_24h        BOOLEAN NOT NULL DEFAULT true,
  is_free       BOOLEAN NOT NULL DEFAULT true,
  sort_order    INT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_emergency_numbers_country ON public.emergency_numbers(country);

ALTER TABLE public.emergency_numbers ENABLE ROW LEVEL SECURITY;

-- Read-only for all authenticated users; only admins can modify
DROP POLICY IF EXISTS "emergency_numbers_select" ON public.emergency_numbers;
CREATE POLICY "emergency_numbers_select" ON public.emergency_numbers FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "emergency_numbers_admin" ON public.emergency_numbers;
CREATE POLICY "emergency_numbers_admin" ON public.emergency_numbers FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));


-- Seed essential numbers
INSERT INTO public.emergency_numbers (country, category, label, number, description, is_24h, is_free, sort_order) VALUES
  -- Deutschland
  ('DE', 'emergency', 'Notruf', '112', 'Feuerwehr & Rettungsdienst', true, true, 1),
  ('DE', 'emergency', 'Polizei', '110', 'Polizei-Notruf', true, true, 2),
  ('DE', 'crisis', 'Telefonseelsorge', '0800 111 0 111', 'Kostenlose Krisenhotline, 24/7', true, true, 10),
  ('DE', 'crisis', 'Telefonseelsorge', '0800 111 0 222', 'Kostenlose Krisenhotline, 24/7', true, true, 11),
  ('DE', 'children', 'Nummer gegen Kummer', '116 111', 'Kinder- und Jugendtelefon', false, true, 20),
  ('DE', 'children', 'Elterntelefon', '0800 111 0 550', 'Beratung für Eltern', false, true, 21),
  ('DE', 'women', 'Hilfetelefon Gewalt', '08000 116 016', 'Gewalt gegen Frauen, 24/7', true, true, 30),
  ('DE', 'poison', 'Giftnotruf Berlin', '030 19240', 'Giftinformationszentrale', true, true, 40),
  -- Österreich
  ('AT', 'emergency', 'Notruf', '112', 'EU-weiter Notruf', true, true, 1),
  ('AT', 'emergency', 'Rettung', '144', 'Rettungsdienst', true, true, 2),
  ('AT', 'emergency', 'Polizei', '133', 'Polizei-Notruf', true, true, 3),
  ('AT', 'emergency', 'Feuerwehr', '122', 'Feuerwehr-Notruf', true, true, 4),
  ('AT', 'crisis', 'Telefonseelsorge', '142', 'Krisenhotline, 24/7', true, true, 10),
  ('AT', 'children', 'Rat auf Draht', '147', 'Kinder- und Jugendhotline', true, true, 20),
  ('AT', 'women', 'Frauenhelpline', '0800 222 555', 'Gewalt gegen Frauen, 24/7', true, true, 30),
  ('AT', 'poison', 'Vergiftungsinformation', '01 406 43 43', 'Vergiftungszentrale Wien', true, true, 40),
  -- Schweiz
  ('CH', 'emergency', 'Notruf', '112', 'EU-weiter Notruf', true, true, 1),
  ('CH', 'emergency', 'Sanität', '144', 'Sanitätsnotruf', true, true, 2),
  ('CH', 'emergency', 'Polizei', '117', 'Polizei-Notruf', true, true, 3),
  ('CH', 'emergency', 'Feuerwehr', '118', 'Feuerwehr-Notruf', true, true, 4),
  ('CH', 'crisis', 'Die Dargebotene Hand', '143', 'Krisenhotline, 24/7', true, true, 10),
  ('CH', 'children', 'Pro Juventute', '147', 'Kinder- und Jugendhotline', true, true, 20),
  ('CH', 'women', 'Opferhilfe', '0800 811 100', 'Gewalt gegen Frauen', true, true, 30),
  ('CH', 'poison', 'Tox Info Suisse', '145', 'Vergiftungsnotfall, 24/7', true, true, 40)
ON CONFLICT DO NOTHING;


-- ============================================================================
-- 4. match_preferences – User matching preferences
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.match_preferences (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  matching_enabled      BOOLEAN NOT NULL DEFAULT true,
  max_distance_km       INT NOT NULL DEFAULT 25,
  preferred_categories  TEXT[] NOT NULL DEFAULT '{}',
  excluded_categories   TEXT[] NOT NULL DEFAULT '{}',
  min_trust_score       NUMERIC(3,1) NOT NULL DEFAULT 0,
  max_matches_per_day   INT NOT NULL DEFAULT 5,
  notify_on_match       BOOLEAN NOT NULL DEFAULT true,
  auto_accept_threshold NUMERIC(5,2),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_match_preferences_user ON public.match_preferences(user_id);

CREATE OR REPLACE FUNCTION public.trg_match_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS match_preferences_updated_at ON public.match_preferences;
CREATE TRIGGER match_preferences_updated_at BEFORE UPDATE ON public.match_preferences
  FOR EACH ROW EXECUTE FUNCTION public.trg_match_preferences_updated_at();

ALTER TABLE public.match_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "match_prefs_own" ON public.match_preferences;
CREATE POLICY "match_prefs_own" ON public.match_preferences FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "match_prefs_admin_read" ON public.match_preferences;
CREATE POLICY "match_prefs_admin_read" ON public.match_preferences FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')));


-- ============================================================================
-- 5. organization_review_helpful – "Was this review helpful?" votes
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.organization_review_helpful (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id     UUID NOT NULL REFERENCES public.organization_reviews(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (review_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_org_review_helpful_review ON public.organization_review_helpful(review_id);
CREATE INDEX IF NOT EXISTS idx_org_review_helpful_user   ON public.organization_review_helpful(user_id);

ALTER TABLE public.organization_review_helpful ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "org_review_helpful_select" ON public.organization_review_helpful;
CREATE POLICY "org_review_helpful_select" ON public.organization_review_helpful FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "org_review_helpful_insert" ON public.organization_review_helpful;
CREATE POLICY "org_review_helpful_insert" ON public.organization_review_helpful FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "org_review_helpful_delete" ON public.organization_review_helpful;
CREATE POLICY "org_review_helpful_delete" ON public.organization_review_helpful FOR DELETE
  USING (auth.uid() = user_id);


-- ============================================================================
-- 6. organization_suggestions – Community-submitted organization suggestions
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.organization_suggestions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  description   TEXT,
  category      TEXT NOT NULL,
  address       TEXT,
  city          TEXT,
  country       TEXT NOT NULL DEFAULT 'DE',
  phone         TEXT,
  email         TEXT,
  website       TEXT,
  status        TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','approved','rejected')),
  admin_notes   TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_org_suggestions_user   ON public.organization_suggestions(user_id);
CREATE INDEX IF NOT EXISTS idx_org_suggestions_status ON public.organization_suggestions(status);

ALTER TABLE public.organization_suggestions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "org_suggestions_select_own" ON public.organization_suggestions;
CREATE POLICY "org_suggestions_select_own" ON public.organization_suggestions FOR SELECT
  USING (auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

DROP POLICY IF EXISTS "org_suggestions_insert" ON public.organization_suggestions;
CREATE POLICY "org_suggestions_insert" ON public.organization_suggestions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "org_suggestions_update_admin" ON public.organization_suggestions;
CREATE POLICY "org_suggestions_update_admin" ON public.organization_suggestions FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')));

DROP POLICY IF EXISTS "org_suggestions_delete_admin" ON public.organization_suggestions;
CREATE POLICY "org_suggestions_delete_admin" ON public.organization_suggestions FOR DELETE
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')));


-- ============================================================================
-- 7. post_reactions – Emoji reactions on posts (heart, thanks, support, compassion)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.post_reactions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id       UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reaction_type TEXT NOT NULL CHECK (reaction_type IN ('heart','thanks','support','compassion')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)  -- one reaction per user per post
);

CREATE INDEX IF NOT EXISTS idx_post_reactions_post ON public.post_reactions(post_id);
CREATE INDEX IF NOT EXISTS idx_post_reactions_user ON public.post_reactions(user_id);

ALTER TABLE public.post_reactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "post_reactions_select" ON public.post_reactions;
CREATE POLICY "post_reactions_select" ON public.post_reactions FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "post_reactions_insert" ON public.post_reactions;
CREATE POLICY "post_reactions_insert" ON public.post_reactions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "post_reactions_update" ON public.post_reactions;
CREATE POLICY "post_reactions_update" ON public.post_reactions FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "post_reactions_delete" ON public.post_reactions;
CREATE POLICY "post_reactions_delete" ON public.post_reactions FOR DELETE
  USING (auth.uid() = user_id);


-- ============================================================================
-- 8. reports – Generic content/user reports (used by PostDetailPage, ProfileView, Settings)
--    NOTE: content_reports already exists for the admin ReportsTab & ReportButton.
--    This "reports" table is used by other frontend components independently.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.reports (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content_type  TEXT NOT NULL CHECK (content_type IN ('post','user','comment','board_post','event','organization','message')),
  content_id    UUID NOT NULL,
  reason        TEXT NOT NULL,
  comment       TEXT,
  status        TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','reviewing','resolved','dismissed')),
  resolved_by   UUID REFERENCES auth.users(id),
  resolved_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reports_reporter     ON public.reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_content      ON public.reports(content_type, content_id);
CREATE INDEX IF NOT EXISTS idx_reports_status       ON public.reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_created      ON public.reports(created_at DESC);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reports_select" ON public.reports;
CREATE POLICY "reports_select" ON public.reports FOR SELECT
  USING (auth.uid() = reporter_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

DROP POLICY IF EXISTS "reports_insert" ON public.reports;
CREATE POLICY "reports_insert" ON public.reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

DROP POLICY IF EXISTS "reports_update_admin" ON public.reports;
CREATE POLICY "reports_update_admin" ON public.reports FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')));

DROP POLICY IF EXISTS "reports_delete" ON public.reports;
CREATE POLICY "reports_delete" ON public.reports FOR DELETE
  USING (auth.uid() = reporter_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );


-- ============================================================================
-- 9. Helper RPCs used by the frontend
-- ============================================================================

-- get_crisis_stats: Returns crisis statistics
CREATE OR REPLACE FUNCTION public.get_crisis_stats()
RETURNS TABLE(
  active_count         BIGINT,
  total_active_helpers BIGINT,
  resolved_last_30_days BIGINT,
  avg_resolution_hours  NUMERIC
) LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    (SELECT count(*) FROM public.crises WHERE status IN ('active','in_progress')),
    (SELECT count(*) FROM public.crisis_helpers WHERE status IN ('offered','accepted','on_way','arrived')),
    (SELECT count(*) FROM public.crises WHERE status = 'resolved' AND resolved_at > now() - interval '30 days'),
    COALESCE(
      (SELECT round(avg(EXTRACT(EPOCH FROM (resolved_at - created_at)) / 3600)::numeric, 1)
       FROM public.crises WHERE status = 'resolved' AND resolved_at IS NOT NULL),
      0
    );
$$;

-- increment/decrement helpful RPCs for organization reviews
CREATE OR REPLACE FUNCTION public.increment_helpful(p_review_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.organization_reviews
  SET helpful_count = COALESCE(helpful_count, 0) + 1
  WHERE id = p_review_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.decrement_helpful(p_review_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.organization_reviews
  SET helpful_count = GREATEST(0, COALESCE(helpful_count, 0) - 1)
  WHERE id = p_review_id;
END;
$$;

-- Ensure helpful_count column exists on organization_reviews
DO $$ BEGIN
  ALTER TABLE public.organization_reviews ADD COLUMN IF NOT EXISTS helpful_count INT NOT NULL DEFAULT 0;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Ensure is_reported and report_reason columns exist on organization_reviews
DO $$ BEGIN
  ALTER TABLE public.organization_reviews ADD COLUMN IF NOT EXISTS is_reported BOOLEAN NOT NULL DEFAULT false;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE public.organization_reviews ADD COLUMN IF NOT EXISTS report_reason TEXT;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE public.organization_reviews ADD COLUMN IF NOT EXISTS admin_response TEXT;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE public.organization_reviews ADD COLUMN IF NOT EXISTS admin_response_at TIMESTAMPTZ;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Ensure ban columns exist on profiles (C3.1 user ban system)
DO $$ BEGIN
  ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_banned BOOLEAN NOT NULL DEFAULT false;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS banned_until TIMESTAMPTZ;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS ban_reason TEXT;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Ensure crisis_banned_until column exists on profiles
DO $$ BEGIN
  ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS crisis_banned_until TIMESTAMPTZ;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_crisis_volunteer BOOLEAN NOT NULL DEFAULT false;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS crisis_skills TEXT[] DEFAULT '{}';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ============================================================================
-- 10. audit_logs – Admin action audit trail (C4)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id    UUID NOT NULL REFERENCES auth.users(id),
  action      TEXT NOT NULL,  -- e.g. 'ban_user', 'delete_post', 'change_role', 'resolve_report'
  target_type TEXT,           -- e.g. 'user', 'post', 'crisis', 'report'
  target_id   UUID,
  details     JSONB DEFAULT '{}',
  ip_address  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor    ON public.audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action   ON public.audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target   ON public.audit_logs(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created  ON public.audit_logs(created_at DESC);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Only admins can read/write audit logs
DROP POLICY IF EXISTS "audit_logs_admin" ON public.audit_logs;
CREATE POLICY "audit_logs_admin" ON public.audit_logs FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- ============================================================================
-- 11. Missing RPCs used by the frontend
-- ============================================================================

-- search_posts: Full-text + geo search for posts
CREATE OR REPLACE FUNCTION public.search_posts(
  p_query      TEXT     DEFAULT NULL,
  p_type       TEXT     DEFAULT NULL,
  p_category   TEXT     DEFAULT NULL,
  p_lat        DOUBLE PRECISION DEFAULT NULL,
  p_lng        DOUBLE PRECISION DEFAULT NULL,
  p_radius_km  INT     DEFAULT 50,
  p_limit      INT     DEFAULT 20,
  p_offset     INT     DEFAULT 0
)
RETURNS SETOF JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT
      p.id, p.title, p.description, p.type, p.category, p.status, p.urgency,
      p.user_id, p.location_text, p.latitude, p.longitude, p.lat, p.lng,
      p.media_urls, p.tags, p.is_anonymous, p.contact_phone, p.contact_email,
      p.contact_whatsapp, p.privacy_phone, p.privacy_email,
      p.availability_days, p.availability_start, p.availability_end,
      p.created_at, p.updated_at,
      pr.name AS author_name, pr.avatar_url AS author_avatar,
      CASE
        WHEN p_lat IS NOT NULL AND p_lng IS NOT NULL
             AND COALESCE(p.latitude, p.lat) IS NOT NULL
             AND COALESCE(p.longitude, p.lng) IS NOT NULL
        THEN round((
          6371 * acos(
            LEAST(1.0, GREATEST(-1.0,
              cos(radians(p_lat)) * cos(radians(COALESCE(p.latitude, p.lat)))
              * cos(radians(COALESCE(p.longitude, p.lng)) - radians(p_lng))
              + sin(radians(p_lat)) * sin(radians(COALESCE(p.latitude, p.lat)))
            ))
          )
        )::numeric, 1)
        ELSE NULL
      END AS distance_km
    FROM public.posts p
    LEFT JOIN public.profiles pr ON pr.id = p.user_id
    WHERE p.status = 'active'
      AND (p_type IS NULL OR p.type = p_type)
      AND (p_category IS NULL OR p.category = p_category)
      AND (p_query IS NULL OR p_query = ''
           OR p.title ILIKE '%' || p_query || '%'
           OR p.description ILIKE '%' || p_query || '%'
           OR p.location_text ILIKE '%' || p_query || '%'
           OR p_query = ANY(p.tags))
      AND (p_lat IS NULL OR p_lng IS NULL
           OR COALESCE(p.latitude, p.lat) IS NULL
           OR COALESCE(p.longitude, p.lng) IS NULL
           OR (
             6371 * acos(
               LEAST(1.0, GREATEST(-1.0,
                 cos(radians(p_lat)) * cos(radians(COALESCE(p.latitude, p.lat)))
                 * cos(radians(COALESCE(p.longitude, p.lng)) - radians(p_lng))
                 + sin(radians(p_lat)) * sin(radians(COALESCE(p.latitude, p.lat)))
               ))
             ) <= p_radius_km
           ))
    ORDER BY
      CASE WHEN p.urgency IN ('critical','high') THEN 0 ELSE 1 END,
      p.created_at DESC
    LIMIT p_limit OFFSET p_offset
  LOOP
    RETURN NEXT to_jsonb(rec);
  END LOOP;
END;
$$;


-- search_board_posts: Full-text search for board posts
CREATE OR REPLACE FUNCTION public.search_board_posts(
  p_query    TEXT DEFAULT NULL,
  p_category TEXT DEFAULT NULL,
  p_limit    INT DEFAULT 20,
  p_offset   INT DEFAULT 0
)
RETURNS SETOF JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT
      bp.id, bp.content, bp.category, bp.color, bp.status, bp.author_id,
      bp.pin_count, bp.comment_count, bp.image_url,
      bp.created_at, bp.updated_at,
      pr.name AS author_name, pr.avatar_url AS author_avatar
    FROM public.board_posts bp
    LEFT JOIN public.profiles pr ON pr.id = bp.author_id
    WHERE bp.status = 'active'
      AND (p_category IS NULL OR bp.category = p_category)
      AND (p_query IS NULL OR p_query = ''
           OR bp.content ILIKE '%' || p_query || '%')
    ORDER BY bp.created_at DESC
    LIMIT p_limit OFFSET p_offset
  LOOP
    RETURN NEXT to_jsonb(rec);
  END LOOP;
END;
$$;


-- check_rate_limit: Rate-limit check via rate_limits table
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_user_id       UUID,
  p_action        TEXT,
  p_max_per_hour  INT DEFAULT 30,
  p_max_per_minute INT DEFAULT 5
)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  cnt_minute INT;
  cnt_hour   INT;
BEGIN
  -- Count actions in the last minute
  SELECT count(*) INTO cnt_minute
  FROM public.rate_limits
  WHERE user_id = p_user_id AND action = p_action
    AND created_at > now() - interval '1 minute';

  IF cnt_minute >= p_max_per_minute THEN
    RETURN false;  -- rate-limited
  END IF;

  -- Count actions in the last hour
  SELECT count(*) INTO cnt_hour
  FROM public.rate_limits
  WHERE user_id = p_user_id AND action = p_action
    AND created_at > now() - interval '1 hour';

  IF cnt_hour >= p_max_per_hour THEN
    RETURN false;  -- rate-limited
  END IF;

  -- Record this action
  INSERT INTO public.rate_limits (user_id, action, created_at)
  VALUES (p_user_id, p_action, now());

  -- Cleanup old entries (older than 2 hours) to keep table small
  DELETE FROM public.rate_limits
  WHERE user_id = p_user_id AND action = p_action
    AND created_at < now() - interval '2 hours';

  RETURN true;  -- allowed
END;
$$;


-- admin_delete_post: Cascade-delete a post and all related data
CREATE OR REPLACE FUNCTION public.admin_delete_post(p_post_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Check admin/moderator role
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  DELETE FROM public.post_reactions WHERE post_id = p_post_id;
  DELETE FROM public.post_comments WHERE post_id = p_post_id;
  DELETE FROM public.post_votes WHERE post_id = p_post_id;
  DELETE FROM public.post_shares WHERE post_id = p_post_id;
  DELETE FROM public.saved_posts WHERE post_id = p_post_id;
  DELETE FROM public.content_reports WHERE content_id = p_post_id AND content_type = 'post';
  DELETE FROM public.reports WHERE content_id = p_post_id AND content_type = 'post';
  DELETE FROM public.interactions WHERE post_id = p_post_id;
  DELETE FROM public.posts WHERE id = p_post_id;
END;
$$;


-- admin_delete_event: Cascade-delete an event and related data
CREATE OR REPLACE FUNCTION public.admin_delete_event(p_event_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  DELETE FROM public.event_attendees WHERE event_id = p_event_id;
  DELETE FROM public.content_reports WHERE content_id = p_event_id AND content_type = 'event';
  DELETE FROM public.events WHERE id = p_event_id;
END;
$$;


-- admin_delete_board_post: Cascade-delete a board post
CREATE OR REPLACE FUNCTION public.admin_delete_board_post(p_board_post_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  DELETE FROM public.board_comments WHERE board_post_id = p_board_post_id;
  DELETE FROM public.board_pins WHERE board_post_id = p_board_post_id;
  DELETE FROM public.content_reports WHERE content_id = p_board_post_id AND content_type = 'board_post';
  DELETE FROM public.board_posts WHERE id = p_board_post_id;
END;
$$;


-- admin_delete_crisis: Cascade-delete a crisis
CREATE OR REPLACE FUNCTION public.admin_delete_crisis(p_crisis_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  DELETE FROM public.crisis_updates WHERE crisis_id = p_crisis_id;
  DELETE FROM public.crisis_helpers WHERE crisis_id = p_crisis_id;
  DELETE FROM public.content_reports WHERE content_id = p_crisis_id AND content_type = 'crisis';
  DELETE FROM public.crises WHERE id = p_crisis_id;
END;
$$;


-- run_scheduled_cleanup: Scheduled cleanup of old data (called by SystemTab)
CREATE OR REPLACE FUNCTION public.run_scheduled_cleanup()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  result JSONB := '{}'::jsonb;
  cnt INT;
BEGIN
  -- Check admin role
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- Clean old rate limits (older than 24h)
  DELETE FROM public.rate_limits WHERE created_at < now() - interval '24 hours';
  GET DIAGNOSTICS cnt = ROW_COUNT;
  result := result || jsonb_build_object('rate_limits_cleaned', cnt);

  -- Clean old read notifications (older than 90 days)
  DELETE FROM public.notifications WHERE read = true AND created_at < now() - interval '90 days';
  GET DIAGNOSTICS cnt = ROW_COUNT;
  result := result || jsonb_build_object('old_notifications_cleaned', cnt);

  -- Clean resolved reports older than 180 days
  DELETE FROM public.reports WHERE status IN ('resolved','dismissed') AND created_at < now() - interval '180 days';
  GET DIAGNOSTICS cnt = ROW_COUNT;
  result := result || jsonb_build_object('old_reports_cleaned', cnt);

  -- Clean expired matches (already in matching_system, but extra safety)
  UPDATE public.matches SET status = 'expired' WHERE status = 'suggested' AND expires_at < now();
  GET DIAGNOSTICS cnt = ROW_COUNT;
  result := result || jsonb_build_object('expired_matches', cnt);

  result := result || jsonb_build_object('cleanup_at', now());
  RETURN result;
END;
$$;

COMMIT;
