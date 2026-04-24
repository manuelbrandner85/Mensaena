-- ============================================================
-- MENSAENA – Matching System Migration
-- Automatically pairs offer posts with request posts
-- ============================================================

-- ── Match status enum ───────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE match_status AS ENUM (
    'suggested',   -- System generated, neither user has responded
    'pending',     -- One user accepted, waiting for the other
    'accepted',    -- Both users accepted
    'declined',    -- One or both declined
    'expired',     -- Auto-expired after timeout
    'completed',   -- Successfully completed interaction
    'cancelled'    -- Cancelled after acceptance
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── Matches table ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS matches (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_post_id   uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  request_post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  offer_user_id   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  request_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  match_score     numeric(5,2) NOT NULL DEFAULT 0,
  score_breakdown jsonb NOT NULL DEFAULT '{}'::jsonb,
  status          match_status NOT NULL DEFAULT 'suggested',
  distance_km     numeric(8,2),
  offer_responded boolean NOT NULL DEFAULT false,
  request_responded boolean NOT NULL DEFAULT false,
  offer_accepted  boolean,
  request_accepted boolean,
  conversation_id uuid REFERENCES conversations(id) ON DELETE SET NULL,
  seen_by_offer   boolean NOT NULL DEFAULT false,
  seen_by_request boolean NOT NULL DEFAULT false,
  declined_by     uuid REFERENCES auth.users(id),
  decline_reason  text,
  expires_at      timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  completed_at    timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  -- Prevent duplicate matches for same post pair
  CONSTRAINT unique_match_pair UNIQUE (offer_post_id, request_post_id)
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_matches_offer_user_status ON matches(offer_user_id, status);
CREATE INDEX IF NOT EXISTS idx_matches_request_user_status ON matches(request_user_id, status);
CREATE INDEX IF NOT EXISTS idx_matches_status_score ON matches(status, match_score DESC);
CREATE INDEX IF NOT EXISTS idx_matches_expires_at ON matches(expires_at) WHERE status IN ('suggested', 'pending');
CREATE INDEX IF NOT EXISTS idx_matches_created_at ON matches(created_at DESC);

-- ── Match preferences table ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS match_preferences (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  matching_enabled      boolean NOT NULL DEFAULT true,
  max_distance_km       integer NOT NULL DEFAULT 25,
  preferred_categories  text[] DEFAULT '{}',
  excluded_categories   text[] DEFAULT '{}',
  min_trust_score       numeric(3,1) NOT NULL DEFAULT 0,
  max_matches_per_day   integer NOT NULL DEFAULT 5,
  notify_on_match       boolean NOT NULL DEFAULT true,
  auto_accept_threshold numeric(5,2) DEFAULT NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT unique_user_preferences UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_match_preferences_user ON match_preferences(user_id);

-- ── Updated_at trigger ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_matches_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_matches_updated_at ON matches;
CREATE TRIGGER trg_matches_updated_at
  BEFORE UPDATE ON matches
  FOR EACH ROW EXECUTE FUNCTION update_matches_updated_at();

DROP TRIGGER IF EXISTS trg_match_preferences_updated_at ON match_preferences;
CREATE TRIGGER trg_match_preferences_updated_at
  BEFORE UPDATE ON match_preferences
  FOR EACH ROW EXECUTE FUNCTION update_matches_updated_at();

-- ── RLS Policies ────────────────────────────────────────────────────
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_preferences ENABLE ROW LEVEL SECURITY;

-- Matches: Users can see matches where they are involved
DROP POLICY IF EXISTS matches_select_own ON matches;
CREATE POLICY matches_select_own ON matches
  FOR SELECT USING (
    auth.uid() = offer_user_id OR auth.uid() = request_user_id
  );

-- Matches: Users can update matches where they are involved
DROP POLICY IF EXISTS matches_update_own ON matches;
CREATE POLICY matches_update_own ON matches
  FOR UPDATE USING (
    auth.uid() = offer_user_id OR auth.uid() = request_user_id
  );

-- Matches: Only system/RPC can insert (service role or via RPC)
DROP POLICY IF EXISTS matches_insert_system ON matches;
CREATE POLICY matches_insert_system ON matches
  FOR INSERT WITH CHECK (
    auth.uid() = offer_user_id OR auth.uid() = request_user_id
  );

-- Match preferences: Users can only manage their own
DROP POLICY IF EXISTS match_prefs_select_own ON match_preferences;
CREATE POLICY match_prefs_select_own ON match_preferences
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS match_prefs_insert_own ON match_preferences;
CREATE POLICY match_prefs_insert_own ON match_preferences
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS match_prefs_update_own ON match_preferences;
CREATE POLICY match_prefs_update_own ON match_preferences
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS match_prefs_delete_own ON match_preferences;
CREATE POLICY match_prefs_delete_own ON match_preferences
  FOR DELETE USING (auth.uid() = user_id);

-- ── Enable realtime for matches ─────────────────────────────────────
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE matches;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ════════════════════════════════════════════════════════════════════
-- RPC FUNCTIONS
-- ════════════════════════════════════════════════════════════════════

-- ── Haversine distance function ─────────────────────────────────────
CREATE OR REPLACE FUNCTION haversine_km(
  lat1 double precision,
  lon1 double precision,
  lat2 double precision,
  lon2 double precision
) RETURNS double precision AS $$
DECLARE
  R constant double precision := 6371.0;
  dlat double precision;
  dlon double precision;
  a double precision;
BEGIN
  IF lat1 IS NULL OR lon1 IS NULL OR lat2 IS NULL OR lon2 IS NULL THEN
    RETURN NULL;
  END IF;
  dlat := radians(lat2 - lat1);
  dlon := radians(lon2 - lon1);
  a := sin(dlat / 2) * sin(dlat / 2) +
       cos(radians(lat1)) * cos(radians(lat2)) *
       sin(dlon / 2) * sin(dlon / 2);
  RETURN R * 2 * atan2(sqrt(a), sqrt(1.0 - a));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ── Generate matches for a post ─────────────────────────────────────
CREATE OR REPLACE FUNCTION generate_matches_for_post(p_post_id uuid)
RETURNS integer AS $$
DECLARE
  v_post record;
  v_candidate record;
  v_prefs record;
  v_my_prefs record;
  v_distance double precision;
  v_score numeric(5,2);
  v_breakdown jsonb;
  v_inserted integer := 0;
  v_today_count integer;
  v_category_score numeric;
  v_distance_score numeric;
  v_trust_score numeric;
  v_availability_score numeric;
  v_activity_score numeric;
  v_search_type text;
  v_days_since_active integer;
BEGIN
  -- Fetch the triggering post with profile info
  SELECT p.*, pr.trust_score AS author_trust, pr.trust_score_count AS author_trust_count,
         pr.latitude AS author_lat, pr.longitude AS author_lng,
         pr.updated_at AS author_last_active
  INTO v_post
  FROM posts p
  LEFT JOIN profiles pr ON pr.id = p.user_id
  WHERE p.id = p_post_id AND p.status = 'active';

  IF v_post IS NULL THEN
    RETURN 0;
  END IF;

  -- Get poster's matching preferences
  SELECT * INTO v_my_prefs FROM match_preferences WHERE user_id = v_post.user_id;

  -- If matching is disabled, skip
  IF v_my_prefs IS NOT NULL AND NOT v_my_prefs.matching_enabled THEN
    RETURN 0;
  END IF;

  -- Determine search direction: offers look for requests, requests look for offers
  -- Posts with type containing 'offer' or 'help_offered' are offers
  -- Posts with type containing 'request' or 'help_needed' are requests
  IF v_post.type IN ('help_offered', 'sharing') THEN
    v_search_type := 'request';
  ELSE
    v_search_type := 'offer';
  END IF;

  -- Find candidate posts (opposite direction)
  FOR v_candidate IN
    SELECT cp.*, cpr.trust_score AS cand_trust, cpr.trust_score_count AS cand_trust_count,
           cpr.latitude AS cand_lat, cpr.longitude AS cand_lng,
           cpr.updated_at AS cand_last_active
    FROM posts cp
    LEFT JOIN profiles cpr ON cpr.id = cp.user_id
    WHERE cp.status = 'active'
      AND cp.user_id != v_post.user_id
      AND cp.id != v_post.id
      -- Direction filter
      AND CASE
        WHEN v_search_type = 'request' THEN cp.type IN ('help_needed', 'rescue', 'crisis', 'animal', 'housing', 'supply', 'mobility', 'community')
        ELSE cp.type IN ('help_offered', 'sharing')
      END
      -- No existing match for this pair
      AND NOT EXISTS (
        SELECT 1 FROM matches m
        WHERE (m.offer_post_id = p_post_id AND m.request_post_id = cp.id)
           OR (m.offer_post_id = cp.id AND m.request_post_id = p_post_id)
      )
    ORDER BY cp.created_at DESC
    LIMIT 50
  LOOP
    -- Check candidate's preferences
    SELECT * INTO v_prefs FROM match_preferences WHERE user_id = v_candidate.user_id;

    -- Skip if candidate has matching disabled
    IF v_prefs IS NOT NULL AND NOT v_prefs.matching_enabled THEN
      CONTINUE;
    END IF;

    -- ── Calculate distance ──
    v_distance := haversine_km(
      COALESCE(v_post.latitude::double precision, v_post.author_lat::double precision),
      COALESCE(v_post.longitude::double precision, v_post.author_lng::double precision),
      COALESCE(v_candidate.latitude::double precision, v_candidate.cand_lat::double precision),
      COALESCE(v_candidate.longitude::double precision, v_candidate.cand_lng::double precision)
    );

    -- Skip if distance exceeds either user's max
    IF v_distance IS NOT NULL THEN
      IF v_my_prefs IS NOT NULL AND v_distance > COALESCE(v_my_prefs.max_distance_km, 50) THEN
        CONTINUE;
      END IF;
      IF v_prefs IS NOT NULL AND v_distance > COALESCE(v_prefs.max_distance_km, 50) THEN
        CONTINUE;
      END IF;
    END IF;

    -- Skip if trust score below threshold
    IF v_prefs IS NOT NULL AND v_prefs.min_trust_score > 0 THEN
      IF COALESCE(v_post.author_trust, 0) < v_prefs.min_trust_score THEN
        CONTINUE;
      END IF;
    END IF;
    IF v_my_prefs IS NOT NULL AND v_my_prefs.min_trust_score > 0 THEN
      IF COALESCE(v_candidate.cand_trust, 0) < v_my_prefs.min_trust_score THEN
        CONTINUE;
      END IF;
    END IF;

    -- Check excluded categories
    IF v_my_prefs IS NOT NULL AND v_my_prefs.excluded_categories IS NOT NULL
       AND array_length(v_my_prefs.excluded_categories, 1) > 0 THEN
      IF v_candidate.category = ANY(v_my_prefs.excluded_categories) THEN
        CONTINUE;
      END IF;
    END IF;

    -- ── Score: Category match (30 points) ──
    IF v_post.category IS NOT NULL AND v_candidate.category IS NOT NULL
       AND v_post.category = v_candidate.category THEN
      v_category_score := 30;
    ELSIF v_post.type = v_candidate.type THEN
      v_category_score := 20;
    ELSE
      v_category_score := 5;
    END IF;

    -- Bonus for preferred categories
    IF v_my_prefs IS NOT NULL AND v_my_prefs.preferred_categories IS NOT NULL
       AND array_length(v_my_prefs.preferred_categories, 1) > 0 THEN
      IF v_candidate.category = ANY(v_my_prefs.preferred_categories) THEN
        v_category_score := LEAST(30, v_category_score + 5);
      END IF;
    END IF;

    -- ── Score: Distance (25 points) ──
    IF v_distance IS NULL THEN
      v_distance_score := 12.5; -- half credit if unknown
    ELSIF v_distance <= 2 THEN
      v_distance_score := 25;
    ELSIF v_distance <= 5 THEN
      v_distance_score := 22;
    ELSIF v_distance <= 10 THEN
      v_distance_score := 18;
    ELSIF v_distance <= 25 THEN
      v_distance_score := 12;
    ELSIF v_distance <= 50 THEN
      v_distance_score := 6;
    ELSE
      v_distance_score := 2;
    END IF;

    -- ── Score: Trust score (20 points) ──
    v_trust_score := LEAST(20,
      COALESCE(v_candidate.cand_trust, 0) * 4
    );

    -- ── Score: Availability overlap (15 points) ──
    IF v_post.availability_start IS NOT NULL AND v_candidate.availability_start IS NOT NULL THEN
      -- Both have availability set
      IF v_post.availability_days IS NOT NULL AND v_candidate.availability_days IS NOT NULL THEN
        -- Check day overlap
        IF v_post.availability_days && v_candidate.availability_days THEN
          v_availability_score := 15;
        ELSE
          v_availability_score := 5;
        END IF;
      ELSE
        v_availability_score := 10;
      END IF;
    ELSE
      v_availability_score := 7.5; -- half credit if unspecified
    END IF;

    -- ── Score: Activity (10 points) ──
    v_days_since_active := EXTRACT(DAY FROM now() - COALESCE(v_candidate.cand_last_active, v_candidate.created_at));
    IF v_days_since_active <= 1 THEN
      v_activity_score := 10;
    ELSIF v_days_since_active <= 3 THEN
      v_activity_score := 8;
    ELSIF v_days_since_active <= 7 THEN
      v_activity_score := 6;
    ELSIF v_days_since_active <= 14 THEN
      v_activity_score := 3;
    ELSE
      v_activity_score := 1;
    END IF;

    -- ── Total score ──
    v_score := v_category_score + v_distance_score + v_trust_score + v_availability_score + v_activity_score;

    v_breakdown := jsonb_build_object(
      'category_match', v_category_score,
      'distance_score', v_distance_score,
      'trust_score', v_trust_score,
      'availability_score', v_availability_score,
      'activity_score', v_activity_score
    );

    -- Skip low-quality matches
    IF v_score < 20 THEN
      CONTINUE;
    END IF;

    -- Check daily limit for poster
    SELECT count(*) INTO v_today_count
    FROM matches
    WHERE (offer_user_id = v_post.user_id OR request_user_id = v_post.user_id)
      AND created_at >= CURRENT_DATE
      AND status = 'suggested';

    IF v_my_prefs IS NOT NULL AND v_today_count >= COALESCE(v_my_prefs.max_matches_per_day, 5) THEN
      EXIT; -- stop generating matches for today
    END IF;

    -- ── Insert match ──
    INSERT INTO matches (
      offer_post_id, request_post_id,
      offer_user_id, request_user_id,
      match_score, score_breakdown,
      distance_km, status, expires_at
    ) VALUES (
      CASE WHEN v_search_type = 'request' THEN p_post_id ELSE v_candidate.id END,
      CASE WHEN v_search_type = 'request' THEN v_candidate.id ELSE p_post_id END,
      CASE WHEN v_search_type = 'request' THEN v_post.user_id ELSE v_candidate.user_id END,
      CASE WHEN v_search_type = 'request' THEN v_candidate.user_id ELSE v_post.user_id END,
      v_score,
      v_breakdown,
      v_distance,
      'suggested',
      now() + interval '7 days'
    )
    ON CONFLICT (offer_post_id, request_post_id) DO NOTHING;

    IF FOUND THEN
      v_inserted := v_inserted + 1;

      -- Send notification to the other user
      BEGIN
        INSERT INTO notifications (user_id, type, category, title, content, link, actor_id, metadata)
        VALUES (
          v_candidate.user_id,
          'new_match',
          'interaction',
          'Neuer Matching-Vorschlag',
          'Ein passender Beitrag wurde für dich gefunden: ' || LEFT(v_post.title, 60),
          '/dashboard/matching',
          v_post.user_id,
          jsonb_build_object('match_score', v_score, 'post_title', v_post.title)
        );
      EXCEPTION WHEN OTHERS THEN
        -- Notification table might not exist or have different schema
        NULL;
      END;
    END IF;

    -- Limit to top 10 matches per post
    EXIT WHEN v_inserted >= 10;
  END LOOP;

  RETURN v_inserted;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Get my matches with full details ────────────────────────────────
CREATE OR REPLACE FUNCTION get_my_matches(
  p_status text DEFAULT NULL,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  offer_post_id uuid,
  request_post_id uuid,
  offer_user_id uuid,
  request_user_id uuid,
  match_score numeric,
  score_breakdown jsonb,
  status match_status,
  distance_km numeric,
  offer_responded boolean,
  request_responded boolean,
  offer_accepted boolean,
  request_accepted boolean,
  conversation_id uuid,
  seen_by_offer boolean,
  seen_by_request boolean,
  declined_by uuid,
  decline_reason text,
  expires_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  -- Offer post details
  offer_post_title text,
  offer_post_type text,
  offer_post_category text,
  offer_post_description text,
  offer_post_location text,
  offer_post_urgency text,
  offer_post_media text[],
  -- Request post details
  request_post_title text,
  request_post_type text,
  request_post_category text,
  request_post_description text,
  request_post_location text,
  request_post_urgency text,
  request_post_media text[],
  -- Offer user profile
  offer_user_name text,
  offer_user_avatar text,
  offer_user_trust numeric,
  offer_user_trust_count integer,
  -- Request user profile
  request_user_name text,
  request_user_avatar text,
  request_user_trust numeric,
  request_user_trust_count integer
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    m.id, m.offer_post_id, m.request_post_id,
    m.offer_user_id, m.request_user_id,
    m.match_score, m.score_breakdown,
    m.status, m.distance_km,
    m.offer_responded, m.request_responded,
    m.offer_accepted, m.request_accepted,
    m.conversation_id,
    m.seen_by_offer, m.seen_by_request,
    m.declined_by, m.decline_reason,
    m.expires_at, m.completed_at,
    m.created_at, m.updated_at,
    -- Offer post
    op.title, op.type::text, op.category::text, op.description,
    op.location_text, op.urgency::text, op.media_urls,
    -- Request post
    rp.title, rp.type::text, rp.category::text, rp.description,
    rp.location_text, rp.urgency::text, rp.media_urls,
    -- Offer user
    opr.name, opr.avatar_url, opr.trust_score, opr.trust_score_count::integer,
    -- Request user
    rpr.name, rpr.avatar_url, rpr.trust_score, rpr.trust_score_count::integer
  FROM matches m
  LEFT JOIN posts op ON op.id = m.offer_post_id
  LEFT JOIN posts rp ON rp.id = m.request_post_id
  LEFT JOIN profiles opr ON opr.id = m.offer_user_id
  LEFT JOIN profiles rpr ON rpr.id = m.request_user_id
  WHERE (m.offer_user_id = auth.uid() OR m.request_user_id = auth.uid())
    AND (p_status IS NULL OR m.status::text = p_status)
  ORDER BY
    CASE m.status
      WHEN 'suggested' THEN 0
      WHEN 'pending' THEN 1
      WHEN 'accepted' THEN 2
      ELSE 3
    END,
    m.match_score DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Cleanup expired matches ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION cleanup_expired_matches()
RETURNS integer AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE matches
  SET status = 'expired', updated_at = now()
  WHERE status IN ('suggested', 'pending')
    AND expires_at < now();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Get match counts for a user ─────────────────────────────────────
CREATE OR REPLACE FUNCTION get_match_counts(p_user_id uuid DEFAULT NULL)
RETURNS jsonb AS $$
DECLARE
  v_uid uuid;
  v_suggested integer;
  v_pending integer;
  v_accepted integer;
  v_completed integer;
BEGIN
  v_uid := COALESCE(p_user_id, auth.uid());

  SELECT count(*) INTO v_suggested
  FROM matches
  WHERE (offer_user_id = v_uid OR request_user_id = v_uid)
    AND status = 'suggested';

  SELECT count(*) INTO v_pending
  FROM matches
  WHERE (offer_user_id = v_uid OR request_user_id = v_uid)
    AND status = 'pending';

  SELECT count(*) INTO v_accepted
  FROM matches
  WHERE (offer_user_id = v_uid OR request_user_id = v_uid)
    AND status = 'accepted';

  SELECT count(*) INTO v_completed
  FROM matches
  WHERE (offer_user_id = v_uid OR request_user_id = v_uid)
    AND status = 'completed';

  RETURN jsonb_build_object(
    'suggested', v_suggested,
    'pending', v_pending,
    'accepted', v_accepted,
    'completed', v_completed
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Respond to match ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION respond_to_match(
  p_match_id uuid,
  p_accept boolean,
  p_decline_reason text DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_match matches;
  v_uid uuid := auth.uid();
  v_is_offer boolean;
  v_partner_id uuid;
  v_conv_id uuid;
  v_new_status match_status;
BEGIN
  SELECT * INTO v_match FROM matches WHERE id = p_match_id;

  IF v_match IS NULL THEN
    RETURN jsonb_build_object('error', 'Match nicht gefunden');
  END IF;

  IF v_match.status NOT IN ('suggested', 'pending') THEN
    RETURN jsonb_build_object('error', 'Match kann nicht mehr beantwortet werden');
  END IF;

  v_is_offer := (v_uid = v_match.offer_user_id);

  IF NOT v_is_offer AND v_uid != v_match.request_user_id THEN
    RETURN jsonb_build_object('error', 'Nicht autorisiert');
  END IF;

  IF p_accept THEN
    -- Mark this side as accepted
    IF v_is_offer THEN
      UPDATE matches SET
        offer_responded = true,
        offer_accepted = true,
        status = CASE
          WHEN request_responded AND request_accepted THEN 'accepted'::match_status
          ELSE 'pending'::match_status
        END
      WHERE id = p_match_id
      RETURNING status INTO v_new_status;
      v_partner_id := v_match.request_user_id;
    ELSE
      UPDATE matches SET
        request_responded = true,
        request_accepted = true,
        status = CASE
          WHEN offer_responded AND offer_accepted THEN 'accepted'::match_status
          ELSE 'pending'::match_status
        END
      WHERE id = p_match_id
      RETURNING status INTO v_new_status;
      v_partner_id := v_match.offer_user_id;
    END IF;

    -- If both accepted, create a DM conversation
    IF v_new_status = 'accepted' THEN
      INSERT INTO conversations (type, title)
      VALUES ('direct', 'Match-Konversation')
      RETURNING id INTO v_conv_id;

      INSERT INTO conversation_members (conversation_id, user_id) VALUES
        (v_conv_id, v_match.offer_user_id),
        (v_conv_id, v_match.request_user_id);

      UPDATE matches SET conversation_id = v_conv_id WHERE id = p_match_id;

      -- Notify both users
      BEGIN
        INSERT INTO notifications (user_id, type, category, title, content, link, actor_id, metadata) VALUES
          (v_match.offer_user_id, 'match_both_accepted', 'interaction', 'Match akzeptiert!',
           'Beide Seiten haben zugestimmt! Ihr könnt jetzt chatten.',
           '/dashboard/chat?conv=' || v_conv_id::text, v_match.request_user_id,
           jsonb_build_object('match_id', p_match_id, 'conversation_id', v_conv_id)),
          (v_match.request_user_id, 'match_both_accepted', 'interaction', 'Match akzeptiert!',
           'Beide Seiten haben zugestimmt! Ihr könnt jetzt chatten.',
           '/dashboard/chat?conv=' || v_conv_id::text, v_match.offer_user_id,
           jsonb_build_object('match_id', p_match_id, 'conversation_id', v_conv_id));
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    ELSE
      -- Notify partner that one side accepted
      BEGIN
        INSERT INTO notifications (user_id, type, category, title, content, link, actor_id, metadata)
        VALUES (
          v_partner_id, 'match_partner_accepted', 'interaction',
          'Match-Vorschlag wartet auf dich',
          'Jemand hat deinen Matching-Vorschlag akzeptiert!',
          '/dashboard/matching', v_uid,
          jsonb_build_object('match_id', p_match_id)
        );
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;

  ELSE
    -- Decline the match
    UPDATE matches SET
      status = 'declined',
      declined_by = v_uid,
      decline_reason = p_decline_reason,
      offer_responded = CASE WHEN v_is_offer THEN true ELSE offer_responded END,
      request_responded = CASE WHEN NOT v_is_offer THEN true ELSE request_responded END,
      offer_accepted = CASE WHEN v_is_offer THEN false ELSE offer_accepted END,
      request_accepted = CASE WHEN NOT v_is_offer THEN false ELSE request_accepted END
    WHERE id = p_match_id;
    v_new_status := 'declined';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'status', v_new_status::text,
    'conversation_id', v_conv_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Trigger: Auto-generate matches when a new post is created ───────
CREATE OR REPLACE FUNCTION trigger_generate_matches()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'active' THEN
    PERFORM generate_matches_for_post(NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_post_generate_matches ON posts;
CREATE TRIGGER trg_post_generate_matches
  AFTER INSERT ON posts
  FOR EACH ROW
  EXECUTE FUNCTION trigger_generate_matches();

-- Add FK from interactions.match_id → matches (deferred from interactions_system migration)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'interactions_match_id_fkey'
  ) THEN
    ALTER TABLE interactions
      ADD CONSTRAINT interactions_match_id_fkey
      FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE SET NULL;
  END IF;
END $$;
