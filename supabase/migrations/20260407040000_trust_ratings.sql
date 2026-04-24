-- ═══════════════════════════════════════════════════════════════════════
-- TRUST RATINGS & BEWERTUNGSSYSTEM – Erweiterte Bewertungen
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1. Erweiterte Spalten: trust_ratings ─────────────────────────────

-- Rename 'score' to 'rating' for consistency (if score exists, add rating alias)
ALTER TABLE trust_ratings ADD COLUMN IF NOT EXISTS rating INTEGER;
-- Copy existing score data to rating column
UPDATE trust_ratings SET rating = score WHERE rating IS NULL AND score IS NOT NULL;

ALTER TABLE trust_ratings ADD COLUMN IF NOT EXISTS interaction_id UUID REFERENCES interactions(id) ON DELETE SET NULL;
ALTER TABLE trust_ratings ADD COLUMN IF NOT EXISTS categories JSONB DEFAULT '[]'::jsonb;
ALTER TABLE trust_ratings ADD COLUMN IF NOT EXISTS helpful BOOLEAN;
ALTER TABLE trust_ratings ADD COLUMN IF NOT EXISTS would_recommend BOOLEAN;
ALTER TABLE trust_ratings ADD COLUMN IF NOT EXISTS response TEXT;
ALTER TABLE trust_ratings ADD COLUMN IF NOT EXISTS response_at TIMESTAMPTZ;
ALTER TABLE trust_ratings ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;
ALTER TABLE trust_ratings ADD COLUMN IF NOT EXISTS reported BOOLEAN DEFAULT false;

-- ── 2. Erweiterte Spalten: interactions ──────────────────────────────

ALTER TABLE interactions ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
ALTER TABLE interactions ADD COLUMN IF NOT EXISTS rating_requested BOOLEAN DEFAULT false;
ALTER TABLE interactions ADD COLUMN IF NOT EXISTS helper_rated BOOLEAN DEFAULT false;
ALTER TABLE interactions ADD COLUMN IF NOT EXISTS helped_rated BOOLEAN DEFAULT false;

-- ── 3. Erweiterte Spalten: profiles ──────────────────────────────────

-- trust_score already exists as INTEGER, add new fields
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS trust_score_count INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS trust_level INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS trust_updated_at TIMESTAMPTZ;

-- ── 4. Indizes ──────────────────────────────────────────────────────

-- Unique per interaction (if interaction_id provided)
CREATE UNIQUE INDEX IF NOT EXISTS idx_trust_ratings_interaction_unique
  ON trust_ratings(rater_id, rated_id, interaction_id) WHERE interaction_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_trust_ratings_rater_id
  ON trust_ratings(rater_id);

CREATE INDEX IF NOT EXISTS idx_trust_ratings_created_at
  ON trust_ratings(created_at DESC);

-- ── 5. RLS Policies for trust_ratings ───────────────────────────────

-- Drop old narrower policies if they exist, then recreate
DO $$ BEGIN
  -- Ensure update policy allows both rater and rated to update
  IF EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'trust_ratings' AND policyname = 'trust_ratings_update'
  ) THEN
    DROP POLICY "trust_ratings_update" ON trust_ratings;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'trust_ratings' AND policyname = 'trust_ratings_update_rater_or_rated'
  ) THEN
    CREATE POLICY "trust_ratings_update_rater_or_rated"
      ON trust_ratings FOR UPDATE
      USING (auth.uid() = rater_id OR auth.uid() = rated_id)
      WITH CHECK (auth.uid() = rater_id OR auth.uid() = rated_id);
  END IF;
END $$;

-- ── 6. RPC: calculate_trust_score ───────────────────────────────────

CREATE OR REPLACE FUNCTION calculate_trust_score(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  result JSON;
  v_avg NUMERIC;
  v_count INTEGER;
  v_helpful_pct NUMERIC;
  v_recommend_pct NUMERIC;
  v_level INTEGER;
BEGIN
  -- Calculate stats
  SELECT
    COALESCE(AVG(COALESCE(rating, score)), 0),
    COUNT(*),
    CASE WHEN COUNT(*) FILTER (WHERE helpful IS NOT NULL) > 0
      THEN ROUND(COUNT(*) FILTER (WHERE helpful = true)::numeric / NULLIF(COUNT(*) FILTER (WHERE helpful IS NOT NULL), 0) * 100, 1)
      ELSE 0
    END,
    CASE WHEN COUNT(*) FILTER (WHERE would_recommend IS NOT NULL) > 0
      THEN ROUND(COUNT(*) FILTER (WHERE would_recommend = true)::numeric / NULLIF(COUNT(*) FILTER (WHERE would_recommend IS NOT NULL), 0) * 100, 1)
      ELSE 0
    END
  INTO v_avg, v_count, v_helpful_pct, v_recommend_pct
  FROM trust_ratings
  WHERE rated_id = p_user_id;

  -- Calculate level (0-5)
  v_level := CASE
    WHEN v_count >= 20 AND v_avg >= 4.5 THEN 5
    WHEN v_count >= 15 AND v_avg >= 4.0 THEN 4
    WHEN v_count >= 10 AND v_avg >= 3.5 THEN 3
    WHEN v_count >= 5  AND v_avg >= 3.0 THEN 2
    WHEN v_count >= 2  AND v_avg >= 2.0 THEN 1
    ELSE 0
  END;

  -- Update cached fields in profiles
  UPDATE profiles
  SET
    trust_score = COALESCE(ROUND(v_avg * 20), 0)::INTEGER,
    trust_score_count = v_count,
    trust_level = v_level,
    trust_updated_at = NOW()
  WHERE id = p_user_id;

  -- Build distribution
  result := json_build_object(
    'average', ROUND(v_avg::numeric, 2),
    'count', v_count,
    'level', v_level,
    'helpful_percent', v_helpful_pct,
    'recommend_percent', v_recommend_pct,
    'distribution', (
      SELECT json_build_object(
        '1', COUNT(*) FILTER (WHERE COALESCE(rating, score) = 1),
        '2', COUNT(*) FILTER (WHERE COALESCE(rating, score) = 2),
        '3', COUNT(*) FILTER (WHERE COALESCE(rating, score) = 3),
        '4', COUNT(*) FILTER (WHERE COALESCE(rating, score) = 4),
        '5', COUNT(*) FILTER (WHERE COALESCE(rating, score) = 5)
      )
      FROM trust_ratings WHERE rated_id = p_user_id
    ),
    'recent_trend', (
      SELECT CASE
        WHEN COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '30 days') = 0 THEN 'stable'
        WHEN AVG(COALESCE(rating, score)) FILTER (WHERE created_at > NOW() - INTERVAL '30 days')
           > AVG(COALESCE(rating, score)) FILTER (WHERE created_at <= NOW() - INTERVAL '30 days' AND created_at > NOW() - INTERVAL '60 days') + 0.1
        THEN 'up'
        WHEN AVG(COALESCE(rating, score)) FILTER (WHERE created_at > NOW() - INTERVAL '30 days')
           < AVG(COALESCE(rating, score)) FILTER (WHERE created_at <= NOW() - INTERVAL '30 days' AND created_at > NOW() - INTERVAL '60 days') - 0.1
        THEN 'down'
        ELSE 'stable'
      END
      FROM trust_ratings WHERE rated_id = p_user_id
    )
  );

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 7. RPC: get_pending_ratings ─────────────────────────────────────

CREATE OR REPLACE FUNCTION get_pending_ratings(p_user_id UUID)
RETURNS JSON AS $$
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  FROM (
    SELECT
      i.id AS interaction_id,
      i.post_id,
      i.helper_id,
      i.completed_at,
      p.title AS post_title,
      CASE
        WHEN i.helper_id = p_user_id THEN po.id
        ELSE i.helper_id
      END AS partner_id,
      CASE
        WHEN i.helper_id = p_user_id THEN po_prof.name
        ELSE h_prof.name
      END AS partner_name,
      CASE
        WHEN i.helper_id = p_user_id THEN po_prof.avatar_url
        ELSE h_prof.avatar_url
      END AS partner_avatar
    FROM interactions i
    JOIN posts p ON p.id = i.post_id
    JOIN profiles h_prof ON h_prof.id = i.helper_id
    JOIN profiles po_prof ON po_prof.id = p.user_id
    LEFT JOIN profiles po ON po.id = p.user_id
    WHERE i.status = 'completed'
      AND i.completed_at IS NOT NULL
      AND (
        (i.helper_id = p_user_id AND i.helper_rated = false)
        OR (p.user_id = p_user_id AND i.helped_rated = false)
      )
      -- Only show interactions completed in the last 30 days
      AND i.completed_at > NOW() - INTERVAL '30 days'
    ORDER BY i.completed_at DESC
    LIMIT 10
  ) t;
$$ LANGUAGE sql SECURITY DEFINER;

-- ── 8. Trigger: update_trust_score_on_rating ─────────────────────────

CREATE OR REPLACE FUNCTION update_trust_score_on_rating()
RETURNS TRIGGER AS $$
BEGIN
  -- Recalculate trust score for the rated user
  PERFORM calculate_trust_score(NEW.rated_id);

  -- Mark the interaction as rated (if linked)
  IF NEW.interaction_id IS NOT NULL THEN
    -- Determine if rater is helper or post owner
    UPDATE interactions
    SET helper_rated = true
    WHERE id = NEW.interaction_id
      AND helper_id = NEW.rater_id;

    UPDATE interactions
    SET helped_rated = true
    WHERE id = NEW.interaction_id
      AND id IN (
        SELECT i.id FROM interactions i
        JOIN posts p ON p.id = i.post_id
        WHERE i.id = NEW.interaction_id AND p.user_id = NEW.rater_id
      );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Replace existing trigger with new one
DROP TRIGGER IF EXISTS on_trust_rating_insert ON trust_ratings;

CREATE TRIGGER on_trust_rating_change
  AFTER INSERT OR UPDATE ON trust_ratings
  FOR EACH ROW EXECUTE FUNCTION update_trust_score_on_rating();

-- ═══════════════════════════════════════════════════════════════════════
-- DONE
-- ═══════════════════════════════════════════════════════════════════════
