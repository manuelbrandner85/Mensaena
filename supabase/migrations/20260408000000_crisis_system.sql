-- ============================================================================
-- CRISIS SYSTEM – Full Migration
-- Tables: crises, crisis_helpers, crisis_updates, emergency_numbers
-- RPC: get_nearby_crises, get_crisis_stats, mobilize_nearby_helpers
-- Storage: crisis-images bucket
-- ============================================================================

-- ── 1. TABLES ─────────────────────────────────────────────────────────────

-- 1a. crises
CREATE TABLE IF NOT EXISTS crises (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  creator_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title           TEXT NOT NULL CHECK (char_length(title) BETWEEN 5 AND 200),
  description     TEXT NOT NULL CHECK (char_length(description) BETWEEN 10 AND 5000),
  category        TEXT NOT NULL CHECK (category IN (
    'medical','fire','flood','storm','accident','violence',
    'missing_person','infrastructure','supply','evacuation','other'
  )),
  urgency         TEXT NOT NULL DEFAULT 'high' CHECK (urgency IN ('critical','high','medium','low')),
  status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
    'active','in_progress','resolved','false_alarm','cancelled'
  )),
  location_text   TEXT,
  latitude        DOUBLE PRECISION,
  longitude       DOUBLE PRECISION,
  radius_km       DOUBLE PRECISION DEFAULT 5,
  affected_count  INTEGER DEFAULT 0 CHECK (affected_count >= 0),
  image_urls      TEXT[] DEFAULT '{}',
  contact_phone   TEXT,
  contact_name    TEXT,
  is_anonymous    BOOLEAN DEFAULT FALSE,
  is_verified     BOOLEAN DEFAULT FALSE,
  verified_by     UUID REFERENCES auth.users(id),
  verified_at     TIMESTAMPTZ,
  resolved_at     TIMESTAMPTZ,
  resolved_by     UUID REFERENCES auth.users(id),
  false_alarm_by  UUID REFERENCES auth.users(id),
  helper_count    INTEGER DEFAULT 0,
  needed_helpers  INTEGER DEFAULT 5,
  needed_skills   TEXT[] DEFAULT '{}',
  needed_resources TEXT[] DEFAULT '{}',
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- 1b. crisis_helpers
CREATE TABLE IF NOT EXISTS crisis_helpers (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  crisis_id     UUID NOT NULL REFERENCES crises(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status        TEXT NOT NULL DEFAULT 'offered' CHECK (status IN (
    'offered','accepted','on_way','arrived','completed','withdrawn'
  )),
  message       TEXT,
  skills        TEXT[] DEFAULT '{}',
  eta_minutes   INTEGER,
  latitude      DOUBLE PRECISION,
  longitude     DOUBLE PRECISION,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE(crisis_id, user_id)
);

-- 1c. crisis_updates
CREATE TABLE IF NOT EXISTS crisis_updates (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  crisis_id     UUID NOT NULL REFERENCES crises(id) ON DELETE CASCADE,
  author_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content       TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 2000),
  update_type   TEXT NOT NULL DEFAULT 'info' CHECK (update_type IN (
    'info','status_change','resource_update','helper_update','resolution','warning','official'
  )),
  image_url     TEXT,
  is_pinned     BOOLEAN DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- 1d. emergency_numbers
CREATE TABLE IF NOT EXISTS emergency_numbers (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  country       TEXT NOT NULL CHECK (country IN ('DE','AT','CH')),
  category      TEXT NOT NULL CHECK (category IN ('emergency','crisis','children','women','poison','other')),
  label         TEXT NOT NULL,
  number        TEXT NOT NULL,
  description   TEXT,
  is_24h        BOOLEAN DEFAULT TRUE,
  is_free       BOOLEAN DEFAULT TRUE,
  sort_order    INTEGER DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- ── 2. INDEXES ────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_crises_status ON crises(status);
CREATE INDEX IF NOT EXISTS idx_crises_urgency ON crises(urgency);
CREATE INDEX IF NOT EXISTS idx_crises_creator ON crises(creator_id);
CREATE INDEX IF NOT EXISTS idx_crises_location ON crises(latitude, longitude) WHERE latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_crises_created ON crises(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_crises_status_urgency ON crises(status, urgency);

CREATE INDEX IF NOT EXISTS idx_crisis_helpers_crisis ON crisis_helpers(crisis_id);
CREATE INDEX IF NOT EXISTS idx_crisis_helpers_user ON crisis_helpers(user_id);
CREATE INDEX IF NOT EXISTS idx_crisis_helpers_status ON crisis_helpers(status);

CREATE INDEX IF NOT EXISTS idx_crisis_updates_crisis ON crisis_updates(crisis_id);
CREATE INDEX IF NOT EXISTS idx_crisis_updates_created ON crisis_updates(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_emergency_numbers_country ON emergency_numbers(country, sort_order);

-- ── 3. TRIGGERS ───────────────────────────────────────────────────────────

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_crisis_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_crises_updated_at ON crises;
CREATE TRIGGER trg_crises_updated_at
  BEFORE UPDATE ON crises
  FOR EACH ROW EXECUTE FUNCTION update_crisis_updated_at();

DROP TRIGGER IF EXISTS trg_crisis_helpers_updated_at ON crisis_helpers;
CREATE TRIGGER trg_crisis_helpers_updated_at
  BEFORE UPDATE ON crisis_helpers
  FOR EACH ROW EXECUTE FUNCTION update_crisis_updated_at();

-- Auto-update helper_count on crises
CREATE OR REPLACE FUNCTION update_crisis_helper_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    UPDATE crises SET helper_count = (
      SELECT COUNT(*) FROM crisis_helpers
      WHERE crisis_id = NEW.crisis_id AND status NOT IN ('withdrawn','completed')
    ) WHERE id = NEW.crisis_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE crises SET helper_count = (
      SELECT COUNT(*) FROM crisis_helpers
      WHERE crisis_id = OLD.crisis_id AND status NOT IN ('withdrawn','completed')
    ) WHERE id = OLD.crisis_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_crisis_helper_count ON crisis_helpers;
CREATE TRIGGER trg_crisis_helper_count
  AFTER INSERT OR UPDATE OR DELETE ON crisis_helpers
  FOR EACH ROW EXECUTE FUNCTION update_crisis_helper_count();

-- ── 4. ROW LEVEL SECURITY ─────────────────────────────────────────────────

ALTER TABLE crises ENABLE ROW LEVEL SECURITY;
ALTER TABLE crisis_helpers ENABLE ROW LEVEL SECURITY;
ALTER TABLE crisis_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_numbers ENABLE ROW LEVEL SECURITY;

-- crises: all authenticated can read; creator or admin can update; creator can insert
DROP POLICY IF EXISTS crises_select ON crises;
CREATE POLICY crises_select ON crises FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS crises_insert ON crises;
CREATE POLICY crises_insert ON crises FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = creator_id);

DROP POLICY IF EXISTS crises_update ON crises;
CREATE POLICY crises_update ON crises FOR UPDATE TO authenticated
  USING (auth.uid() = creator_id OR EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  ));

DROP POLICY IF EXISTS crises_delete ON crises;
CREATE POLICY crises_delete ON crises FOR DELETE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  ));

-- crisis_helpers: all authenticated can read; own rows can insert/update/delete
DROP POLICY IF EXISTS crisis_helpers_select ON crisis_helpers;
CREATE POLICY crisis_helpers_select ON crisis_helpers FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS crisis_helpers_insert ON crisis_helpers;
CREATE POLICY crisis_helpers_insert ON crisis_helpers FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS crisis_helpers_update ON crisis_helpers;
CREATE POLICY crisis_helpers_update ON crisis_helpers FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS crisis_helpers_delete ON crisis_helpers;
CREATE POLICY crisis_helpers_delete ON crisis_helpers FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- crisis_updates: all authenticated can read; author can insert
DROP POLICY IF EXISTS crisis_updates_select ON crisis_updates;
CREATE POLICY crisis_updates_select ON crisis_updates FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS crisis_updates_insert ON crisis_updates;
CREATE POLICY crisis_updates_insert ON crisis_updates FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = author_id);

-- emergency_numbers: everyone can read, only admins can modify
DROP POLICY IF EXISTS emergency_numbers_select ON emergency_numbers;
CREATE POLICY emergency_numbers_select ON emergency_numbers FOR SELECT USING (true);

DROP POLICY IF EXISTS emergency_numbers_admin ON emergency_numbers;
CREATE POLICY emergency_numbers_admin ON emergency_numbers FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  ));

-- ── 5. PROFILE EXTENSIONS ─────────────────────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='crisis_banned_until') THEN
    ALTER TABLE profiles ADD COLUMN crisis_banned_until TIMESTAMPTZ;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='is_crisis_volunteer') THEN
    ALTER TABLE profiles ADD COLUMN is_crisis_volunteer BOOLEAN DEFAULT FALSE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='crisis_skills') THEN
    ALTER TABLE profiles ADD COLUMN crisis_skills TEXT[] DEFAULT '{}';
  END IF;
END $$;

-- ── 6. RPC FUNCTIONS ──────────────────────────────────────────────────────

-- 6a. get_nearby_crises
CREATE OR REPLACE FUNCTION get_nearby_crises(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 50,
  p_status TEXT DEFAULT 'active',
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  category TEXT,
  urgency TEXT,
  status TEXT,
  location_text TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  affected_count INTEGER,
  helper_count INTEGER,
  needed_helpers INTEGER,
  creator_id UUID,
  is_verified BOOLEAN,
  created_at TIMESTAMPTZ,
  distance_km DOUBLE PRECISION
)
LANGUAGE sql STABLE
AS $$
  SELECT
    c.id, c.title, c.description, c.category, c.urgency, c.status,
    c.location_text, c.latitude, c.longitude,
    c.affected_count, c.helper_count, c.needed_helpers,
    c.creator_id, c.is_verified, c.created_at,
    (6371 * acos(
      LEAST(1, GREATEST(-1,
        cos(radians(p_lat)) * cos(radians(c.latitude)) *
        cos(radians(c.longitude) - radians(p_lng)) +
        sin(radians(p_lat)) * sin(radians(c.latitude))
      ))
    )) AS distance_km
  FROM crises c
  WHERE c.status = p_status
    AND c.latitude IS NOT NULL
    AND c.longitude IS NOT NULL
    AND (6371 * acos(
      LEAST(1, GREATEST(-1,
        cos(radians(p_lat)) * cos(radians(c.latitude)) *
        cos(radians(c.longitude) - radians(p_lng)) +
        sin(radians(p_lat)) * sin(radians(c.latitude))
      ))
    )) <= p_radius_km
  ORDER BY
    CASE c.urgency
      WHEN 'critical' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      WHEN 'low' THEN 4
    END,
    distance_km ASC
  LIMIT p_limit;
$$;

-- 6b. get_crisis_stats
CREATE OR REPLACE FUNCTION get_crisis_stats()
RETURNS TABLE (
  active_count BIGINT,
  total_active_helpers BIGINT,
  resolved_last_30_days BIGINT,
  avg_resolution_hours NUMERIC
)
LANGUAGE sql STABLE
AS $$
  SELECT
    (SELECT COUNT(*) FROM crises WHERE status IN ('active','in_progress')) AS active_count,
    (SELECT COUNT(*) FROM crisis_helpers WHERE status NOT IN ('withdrawn','completed')
      AND crisis_id IN (SELECT id FROM crises WHERE status IN ('active','in_progress'))
    ) AS total_active_helpers,
    (SELECT COUNT(*) FROM crises WHERE status = 'resolved'
      AND resolved_at >= now() - INTERVAL '30 days'
    ) AS resolved_last_30_days,
    (SELECT COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (resolved_at - created_at)) / 3600)::NUMERIC, 1), 0)
      FROM crises WHERE status = 'resolved' AND resolved_at IS NOT NULL
      AND resolved_at >= now() - INTERVAL '30 days'
    ) AS avg_resolution_hours;
$$;

-- 6c. mobilize_nearby_helpers
CREATE OR REPLACE FUNCTION mobilize_nearby_helpers(
  p_crisis_id UUID,
  p_radius_km DOUBLE PRECISION DEFAULT 10
)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_crisis RECORD;
  v_notified INTEGER := 0;
  v_user RECORD;
BEGIN
  -- Get crisis details
  SELECT * INTO v_crisis FROM crises WHERE id = p_crisis_id;
  IF v_crisis IS NULL OR v_crisis.latitude IS NULL THEN
    RETURN 0;
  END IF;

  -- Notify nearby users (volunteers first, then others)
  FOR v_user IN
    SELECT p.id as user_id
    FROM profiles p
    WHERE p.id != v_crisis.creator_id
      AND p.latitude IS NOT NULL
      AND p.longitude IS NOT NULL
      AND (p.crisis_banned_until IS NULL OR p.crisis_banned_until < now())
      AND (6371 * acos(
        LEAST(1, GREATEST(-1,
          cos(radians(v_crisis.latitude)) * cos(radians(p.latitude)) *
          cos(radians(p.longitude) - radians(v_crisis.longitude)) +
          sin(radians(v_crisis.latitude)) * sin(radians(p.latitude))
        ))
      )) <= p_radius_km
    ORDER BY p.is_crisis_volunteer DESC NULLS LAST, random()
    LIMIT 200
  LOOP
    INSERT INTO notifications (user_id, type, title, body, link, priority)
    VALUES (
      v_user.user_id,
      'crisis_alert',
      '🚨 Krise in deiner Nähe: ' || v_crisis.title,
      'Kategorie: ' || v_crisis.category || ' – Dringlichkeit: ' || v_crisis.urgency,
      '/dashboard/crisis/' || v_crisis.id,
      'critical'
    )
    ON CONFLICT DO NOTHING;
    v_notified := v_notified + 1;
  END LOOP;

  RETURN v_notified;
END;
$$;

-- ── 7. SEED EMERGENCY NUMBERS ─────────────────────────────────────────────

INSERT INTO emergency_numbers (country, category, label, number, description, is_24h, is_free, sort_order) VALUES
  -- Germany (DE) – 12 entries
  ('DE', 'emergency', 'Polizei-Notruf', '110', 'Deutschlandweit kostenlos, 24/7', TRUE, TRUE, 1),
  ('DE', 'emergency', 'Feuerwehr & Rettung', '112', 'EU-weit kostenlos, 24/7', TRUE, TRUE, 2),
  ('DE', 'emergency', 'Ärztlicher Bereitschaftsdienst', '116117', 'Nicht lebensbedrohlich, kostenlos', TRUE, TRUE, 3),
  ('DE', 'crisis', 'TelefonSeelsorge (evangelisch)', '0800 111 0 111', 'Kostenlos, anonym, 24/7', TRUE, TRUE, 4),
  ('DE', 'crisis', 'TelefonSeelsorge (katholisch)', '0800 111 0 222', 'Kostenlos, anonym, 24/7', TRUE, TRUE, 5),
  ('DE', 'children', 'Kinder- & Jugendtelefon', '116 111', 'Mo–Sa 14–20 Uhr, kostenlos', FALSE, TRUE, 6),
  ('DE', 'children', 'Elterntelefon', '0800 111 0 550', 'Kostenlos, Mo–Fr 9–17 Uhr', FALSE, TRUE, 7),
  ('DE', 'women', 'Hilfetelefon Gewalt gegen Frauen', '116 016', 'Kostenlos, anonym, 24/7', TRUE, TRUE, 8),
  ('DE', 'poison', 'Giftnotruf Berlin', '030 19240', '24/7', TRUE, FALSE, 9),
  ('DE', 'poison', 'Giftnotruf Bonn', '0228 19240', '24/7', TRUE, FALSE, 10),
  ('DE', 'other', 'Krankentransport', '19222', 'Nicht lebensbedrohlich', TRUE, FALSE, 11),
  ('DE', 'crisis', 'TelefonSeelsorge (EU-weit)', '116 123', 'Kostenlos, anonym, 24/7', TRUE, TRUE, 12),

  -- Austria (AT)
  ('AT', 'emergency', 'Rettung', '144', 'Österreichweit kostenlos, 24/7', TRUE, TRUE, 1),
  ('AT', 'emergency', 'Feuerwehr', '122', 'Österreichweit kostenlos, 24/7', TRUE, TRUE, 2),
  ('AT', 'emergency', 'Polizei', '133', 'Österreichweit kostenlos, 24/7', TRUE, TRUE, 3),
  ('AT', 'emergency', 'Euro-Notruf', '112', 'EU-weit kostenlos, 24/7', TRUE, TRUE, 4),
  ('AT', 'emergency', 'Bergrettung', '140', 'Österreichweit kostenlos, 24/7', TRUE, TRUE, 5),
  ('AT', 'crisis', 'Telefonseelsorge', '142', 'Kostenlos, anonym, 24/7', TRUE, TRUE, 6),
  ('AT', 'children', 'Rat auf Draht', '147', 'Kostenlos, anonym, 24/7', TRUE, TRUE, 7),
  ('AT', 'women', 'Frauenhelpline', '0800 222 555', 'Kostenlos, 24/7', TRUE, TRUE, 8),
  ('AT', 'poison', 'Vergiftungsinfo (VIZ)', '01 406 43 43', '24/7', TRUE, FALSE, 9),

  -- Switzerland (CH)
  ('CH', 'emergency', 'Sanität / Rettung', '144', 'Schweizweit kostenlos, 24/7', TRUE, TRUE, 1),
  ('CH', 'emergency', 'Polizei', '117', 'Schweizweit kostenlos, 24/7', TRUE, TRUE, 2),
  ('CH', 'emergency', 'Feuerwehr', '118', 'Schweizweit kostenlos, 24/7', TRUE, TRUE, 3),
  ('CH', 'emergency', 'Rega (Rettungshelikopter)', '1414', '24/7', TRUE, FALSE, 4),
  ('CH', 'emergency', 'Euro-Notruf', '112', 'EU-weit kostenlos, 24/7', TRUE, TRUE, 5),
  ('CH', 'crisis', 'Die Dargebotene Hand', '143', 'Kostenlos, anonym, 24/7', TRUE, TRUE, 6),
  ('CH', 'children', 'Kinder-/Jugendtelefon', '147', 'Kostenlos, anonym, 24/7', TRUE, TRUE, 7),
  ('CH', 'women', 'Hilfetelefon Gewalt', '0800 040 040', 'Kostenlos, 24/7', TRUE, TRUE, 8),
  ('CH', 'poison', 'Tox Info Suisse', '145', 'Vergiftungen, 24/7', TRUE, FALSE, 9)
ON CONFLICT DO NOTHING;

-- ── 8. STORAGE BUCKET ─────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'crisis-images',
  'crisis-images',
  TRUE,
  5242880, -- 5 MB
  ARRAY['image/jpeg','image/png','image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
DROP POLICY IF EXISTS crisis_images_public_read ON storage.objects;
CREATE POLICY crisis_images_public_read ON storage.objects
  FOR SELECT USING (bucket_id = 'crisis-images');

DROP POLICY IF EXISTS crisis_images_auth_upload ON storage.objects;
CREATE POLICY crisis_images_auth_upload ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'crisis-images');

DROP POLICY IF EXISTS crisis_images_auth_update ON storage.objects;
CREATE POLICY crisis_images_auth_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'crisis-images');

-- ── 9. REALTIME ───────────────────────────────────────────────────────────

ALTER PUBLICATION supabase_realtime ADD TABLE crises;
ALTER PUBLICATION supabase_realtime ADD TABLE crisis_helpers;
ALTER PUBLICATION supabase_realtime ADD TABLE crisis_updates;

-- Done
