-- ═══════════════════════════════════════════════════════════════════════
-- MATCHING: Benachrichtigung bei neuem Match + Auto-Accept in DB
-- ═══════════════════════════════════════════════════════════════════════

-- Ersetzt generate_matches_for_post um Notifications für beide User zu
-- senden wenn ein neues Match erstellt wird (nur wenn notify_on_match = true).

CREATE OR REPLACE FUNCTION generate_matches_for_post(p_post_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_post posts%ROWTYPE;
  v_post_prefs match_preferences%ROWTYPE;
  v_search_type TEXT;
  v_candidate RECORD;
  v_score NUMERIC;
  v_score_breakdown JSONB;
  v_distance NUMERIC;
  v_inserted INTEGER := 0;
  v_cat_score NUMERIC;
  v_dist_score NUMERIC;
  v_trust_score NUMERIC;
  v_avail_score NUMERIC;
  v_activity_score NUMERIC;
  v_partner_prefs match_preferences%ROWTYPE;
  v_offer_user UUID;
  v_request_user UUID;
  v_offer_post UUID;
  v_request_post UUID;
  v_notify_offer BOOLEAN;
  v_notify_request BOOLEAN;
  v_auto_offer NUMERIC;
  v_auto_request NUMERIC;
BEGIN
  SELECT * INTO v_post FROM posts WHERE id = p_post_id AND status = 'active';
  IF v_post IS NULL THEN RETURN 0; END IF;

  SELECT * INTO v_post_prefs FROM match_preferences WHERE user_id = v_post.user_id;
  IF v_post_prefs.matching_enabled = false THEN RETURN 0; END IF;

  -- Determine search direction
  IF v_post.type IN ('help_offered', 'sharing') THEN
    v_search_type := 'help_needed';
  ELSE
    v_search_type := 'help_offered';
  END IF;

  -- Check daily rate limit for the post owner
  IF (
    SELECT COUNT(*) FROM matches
    WHERE (offer_user_id = v_post.user_id OR request_user_id = v_post.user_id)
      AND created_at > NOW() - INTERVAL '1 day'
  ) >= COALESCE(v_post_prefs.max_matches_per_day, 5) THEN
    RETURN 0;
  END IF;

  FOR v_candidate IN
    SELECT
      p.id AS post_id,
      p.user_id AS candidate_user_id,
      p.category,
      p.type,
      p.latitude AS candidate_lat,
      p.longitude AS candidate_lon,
      pr.trust_score,
      pr.last_active_at
    FROM posts p
    JOIN profiles pr ON pr.id = p.user_id
    WHERE p.status = 'active'
      AND p.type::text = v_search_type
      AND p.user_id != v_post.user_id
      -- No existing match pair
      AND NOT EXISTS (
        SELECT 1 FROM matches m
        WHERE (m.offer_post_id = p_post_id AND m.request_post_id = p.id)
           OR (m.offer_post_id = p.id AND m.request_post_id = p_post_id)
      )
    ORDER BY RANDOM()
    LIMIT 50
  LOOP
    -- Load partner preferences
    SELECT * INTO v_partner_prefs FROM match_preferences WHERE user_id = v_candidate.candidate_user_id;
    IF v_partner_prefs.matching_enabled = false THEN CONTINUE; END IF;

    -- Distance
    IF v_post.latitude IS NOT NULL AND v_post.longitude IS NOT NULL
       AND v_candidate.candidate_lat IS NOT NULL AND v_candidate.candidate_lon IS NOT NULL THEN
      v_distance := 6371 * acos(
        LEAST(1.0, GREATEST(-1.0,
          cos(radians(v_post.latitude)) * cos(radians(v_candidate.candidate_lat))
          * cos(radians(v_candidate.candidate_lon) - radians(v_post.longitude))
          + sin(radians(v_post.latitude)) * sin(radians(v_candidate.candidate_lat))
        ))
      );
    ELSE
      v_distance := NULL;
    END IF;

    -- Max distance check
    IF v_distance IS NOT NULL AND v_distance > COALESCE(v_post_prefs.max_distance_km, 25) THEN CONTINUE; END IF;
    IF v_distance IS NOT NULL AND v_distance > COALESCE(v_partner_prefs.max_distance_km, 25) THEN CONTINUE; END IF;

    -- Excluded categories
    IF v_post_prefs.excluded_categories @> ARRAY[v_candidate.category::text] THEN CONTINUE; END IF;
    IF v_partner_prefs.excluded_categories @> ARRAY[v_post.category::text] THEN CONTINUE; END IF;

    -- Trust score check
    IF v_candidate.trust_score < COALESCE(v_post_prefs.min_trust_score, 0) THEN CONTINUE; END IF;

    -- Scoring
    IF v_post.category IS NOT NULL AND v_candidate.category IS NOT NULL
       AND v_post.category = v_candidate.category THEN
      v_cat_score := 30;
    ELSIF v_post.type = v_candidate.type THEN
      v_cat_score := 20;
    ELSE
      v_cat_score := 5;
    END IF;

    IF v_post_prefs.preferred_categories @> ARRAY[v_candidate.category::text] THEN
      v_cat_score := LEAST(30, v_cat_score + 5);
    END IF;

    IF v_distance IS NULL THEN v_dist_score := 12.5;
    ELSIF v_distance <= 2  THEN v_dist_score := 25;
    ELSIF v_distance <= 5  THEN v_dist_score := 22;
    ELSIF v_distance <= 10 THEN v_dist_score := 18;
    ELSIF v_distance <= 25 THEN v_dist_score := 12;
    ELSIF v_distance <= 50 THEN v_dist_score := 6;
    ELSE v_dist_score := 2;
    END IF;

    v_trust_score := LEAST(20, COALESCE(v_candidate.trust_score, 0) * 4);

    v_avail_score := 7.5;

    IF v_candidate.last_active_at IS NULL THEN v_activity_score := 5;
    ELSIF v_candidate.last_active_at > NOW() - INTERVAL '1 day'  THEN v_activity_score := 10;
    ELSIF v_candidate.last_active_at > NOW() - INTERVAL '3 days' THEN v_activity_score := 8;
    ELSIF v_candidate.last_active_at > NOW() - INTERVAL '7 days' THEN v_activity_score := 6;
    ELSIF v_candidate.last_active_at > NOW() - INTERVAL '14 days' THEN v_activity_score := 3;
    ELSE v_activity_score := 1;
    END IF;

    v_score := v_cat_score + v_dist_score + v_trust_score + v_avail_score + v_activity_score;
    IF v_score < 20 THEN CONTINUE; END IF;

    v_score_breakdown := jsonb_build_object(
      'category_match', v_cat_score,
      'distance_score', v_dist_score,
      'trust_score', v_trust_score,
      'availability_score', v_avail_score,
      'activity_score', v_activity_score
    );

    -- Determine offer/request sides
    IF v_post.type IN ('help_offered', 'sharing') THEN
      v_offer_user := v_post.user_id;
      v_request_user := v_candidate.candidate_user_id;
      v_offer_post := p_post_id;
      v_request_post := v_candidate.post_id;
    ELSE
      v_offer_user := v_candidate.candidate_user_id;
      v_request_user := v_post.user_id;
      v_offer_post := v_candidate.post_id;
      v_request_post := p_post_id;
    END IF;

    INSERT INTO matches (
      offer_post_id, request_post_id, offer_user_id, request_user_id,
      match_score, score_breakdown, status, distance_km,
      created_at, updated_at
    )
    VALUES (
      v_offer_post, v_request_post, v_offer_user, v_request_user,
      ROUND(v_score::numeric, 2), v_score_breakdown, 'suggested', v_distance,
      NOW(), NOW()
    )
    ON CONFLICT (offer_post_id, request_post_id) DO NOTHING;

    IF FOUND THEN
      v_inserted := v_inserted + 1;

      -- ── Notifications bei neuem Match ─────────────────────────────
      -- Nur wenn notify_on_match = true in den jeweiligen Präferenzen

      -- Offer-User benachrichtigen
      v_notify_offer := COALESCE(
        (SELECT notify_on_match FROM match_preferences WHERE user_id = v_offer_user),
        true
      );
      IF v_notify_offer THEN
        BEGIN
          INSERT INTO notifications (user_id, type, category, title, content, link, actor_id, metadata)
          VALUES (
            v_offer_user,
            'new_match',
            'interaction',
            'Neuer Match-Vorschlag',
            'Es gibt einen neuen Vorschlag für eines deiner Angebote. Schau ihn dir an!',
            '/dashboard/matching',
            v_request_user,
            jsonb_build_object(
              'match_score', ROUND(v_score::numeric, 0),
              'offer_post_id', v_offer_post,
              'request_post_id', v_request_post
            )
          );
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
      END IF;

      -- Request-User benachrichtigen
      v_notify_request := COALESCE(
        (SELECT notify_on_match FROM match_preferences WHERE user_id = v_request_user),
        true
      );
      IF v_notify_request THEN
        BEGIN
          INSERT INTO notifications (user_id, type, category, title, content, link, actor_id, metadata)
          VALUES (
            v_request_user,
            'new_match',
            'interaction',
            'Neuer Match-Vorschlag',
            'Es gibt einen neuen Vorschlag für eines deiner Gesuche. Schau ihn dir an!',
            '/dashboard/matching',
            v_offer_user,
            jsonb_build_object(
              'match_score', ROUND(v_score::numeric, 0),
              'offer_post_id', v_offer_post,
              'request_post_id', v_request_post
            )
          );
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
      END IF;

      -- ── Auto-Accept wenn Score >= auto_accept_threshold ───────────
      v_auto_offer := (SELECT auto_accept_threshold FROM match_preferences WHERE user_id = v_offer_user);
      v_auto_request := (SELECT auto_accept_threshold FROM match_preferences WHERE user_id = v_request_user);

      IF v_auto_offer IS NOT NULL AND v_score >= v_auto_offer THEN
        UPDATE matches SET
          offer_responded = true, offer_accepted = true,
          status = CASE
            WHEN v_auto_request IS NOT NULL AND v_score >= v_auto_request THEN 'accepted'::match_status
            ELSE 'pending'::match_status
          END
        WHERE offer_post_id = v_offer_post AND request_post_id = v_request_post;
      END IF;

      IF v_auto_request IS NOT NULL AND v_score >= v_auto_request THEN
        UPDATE matches SET
          request_responded = true, request_accepted = true,
          status = CASE
            WHEN offer_responded AND offer_accepted THEN 'accepted'::match_status
            ELSE 'pending'::match_status
          END
        WHERE offer_post_id = v_offer_post AND request_post_id = v_request_post;
      END IF;
    END IF;

    EXIT WHEN v_inserted >= 10;
  END LOOP;

  RETURN v_inserted;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
