-- ============================================================
-- MENSAENA – Interaction System Migration
-- Full lifecycle: request → accept → in_progress → complete → rate
-- ============================================================

-- ── 1. Extend interactions table ────────────────────────────────────
ALTER TABLE interactions ADD COLUMN IF NOT EXISTS helped_id UUID REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE interactions ADD COLUMN IF NOT EXISTS match_id UUID; -- FK added after matches table exists (see matching_system migration)
ALTER TABLE interactions ADD COLUMN IF NOT EXISTS response_message TEXT;
ALTER TABLE interactions ADD COLUMN IF NOT EXISTS cancel_reason TEXT;
ALTER TABLE interactions ADD COLUMN IF NOT EXISTS completed_by UUID REFERENCES profiles(id);
ALTER TABLE interactions ADD COLUMN IF NOT EXISTS completion_notes TEXT;
ALTER TABLE interactions ADD COLUMN IF NOT EXISTS conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL;

-- Add constraint checks for text lengths
ALTER TABLE interactions DROP CONSTRAINT IF EXISTS chk_message_len;
ALTER TABLE interactions ADD CONSTRAINT chk_message_len CHECK (message IS NULL OR char_length(message) <= 2000);
ALTER TABLE interactions DROP CONSTRAINT IF EXISTS chk_response_message_len;
ALTER TABLE interactions ADD CONSTRAINT chk_response_message_len CHECK (response_message IS NULL OR char_length(response_message) <= 2000);
ALTER TABLE interactions DROP CONSTRAINT IF EXISTS chk_cancel_reason_len;
ALTER TABLE interactions ADD CONSTRAINT chk_cancel_reason_len CHECK (cancel_reason IS NULL OR char_length(cancel_reason) <= 1000);
ALTER TABLE interactions DROP CONSTRAINT IF EXISTS chk_completion_notes_len;
ALTER TABLE interactions ADD CONSTRAINT chk_completion_notes_len CHECK (completion_notes IS NULL OR char_length(completion_notes) <= 2000);

-- Expand status CHECK to include new statuses
ALTER TABLE interactions DROP CONSTRAINT IF EXISTS interactions_status_check;
ALTER TABLE interactions ADD CONSTRAINT interactions_status_check
  CHECK (status IN ('pending','requested','accepted','in_progress','completed','cancelled','cancelled_by_helper','cancelled_by_helped','disputed','resolved'));

-- Drop the unique constraint that prevents multiple interactions per post
ALTER TABLE interactions DROP CONSTRAINT IF EXISTS interactions_post_id_helper_id_key;

-- Make post_id optional (interactions can come from matches without a direct post)
ALTER TABLE interactions ALTER COLUMN post_id DROP NOT NULL;

-- Backfill helped_id from posts for existing interactions
UPDATE interactions i
SET helped_id = p.user_id
FROM posts p
WHERE i.post_id = p.id
  AND i.helped_id IS NULL;

-- ── 2. New indexes ──────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_interactions_helper_status ON interactions(helper_id, status);
CREATE INDEX IF NOT EXISTS idx_interactions_helped_status ON interactions(helped_id, status);
CREATE INDEX IF NOT EXISTS idx_interactions_match_id ON interactions(match_id);
CREATE INDEX IF NOT EXISTS idx_interactions_status ON interactions(status);
CREATE INDEX IF NOT EXISTS idx_interactions_created_desc ON interactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_interactions_conversation ON interactions(conversation_id);

-- ── 3. interaction_updates table ────────────────────────────────────
CREATE TABLE IF NOT EXISTS interaction_updates (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  interaction_id  uuid NOT NULL REFERENCES interactions(id) ON DELETE CASCADE,
  author_id       uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  update_type     text NOT NULL CHECK (update_type IN (
    'created','accepted','declined','in_progress','completed',
    'cancelled','disputed','resolved','message','status_change'
  )),
  content         text CHECK (content IS NULL OR char_length(content) <= 2000),
  old_status      text,
  new_status      text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_interaction_updates_interaction_time
  ON interaction_updates(interaction_id, created_at);

-- ── 4. RLS Policies ─────────────────────────────────────────────────

-- Drop old policies
DROP POLICY IF EXISTS "interactions_read" ON interactions;
DROP POLICY IF EXISTS "interactions_insert" ON interactions;
DROP POLICY IF EXISTS "interactions_update" ON interactions;
DROP POLICY IF EXISTS interactions_select_involved ON interactions;
DROP POLICY IF EXISTS interactions_insert_auth ON interactions;
DROP POLICY IF EXISTS interactions_update_involved ON interactions;

-- New policies for interactions
CREATE POLICY interactions_select_involved ON interactions
  FOR SELECT USING (
    auth.uid() = helper_id
    OR auth.uid() = helped_id
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY interactions_insert_auth ON interactions
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY interactions_update_involved ON interactions
  FOR UPDATE USING (
    auth.uid() = helper_id
    OR auth.uid() = helped_id
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- RLS for interaction_updates
ALTER TABLE interaction_updates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS interaction_updates_select ON interaction_updates;
CREATE POLICY interaction_updates_select ON interaction_updates
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM interactions
      WHERE interactions.id = interaction_updates.interaction_id
        AND (interactions.helper_id = auth.uid() OR interactions.helped_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS interaction_updates_insert ON interaction_updates;
CREATE POLICY interaction_updates_insert ON interaction_updates
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM interactions
      WHERE interactions.id = interaction_updates.interaction_id
        AND (interactions.helper_id = auth.uid() OR interactions.helped_id = auth.uid())
    )
  );

-- ── 5. Enable realtime ──────────────────────────────────────────────
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE interaction_updates;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 6. RPC Functions ────────────────────────────────────────────────

-- get_my_interactions
CREATE OR REPLACE FUNCTION get_my_interactions(
  p_role text DEFAULT 'all',
  p_status text DEFAULT 'all',
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid, post_id uuid, match_id uuid, helper_id uuid, helped_id uuid,
  status text, message text, response_message text, cancel_reason text,
  completed_at timestamptz, completed_by uuid, completion_notes text,
  helper_rated boolean, helped_rated boolean, rating_requested boolean,
  conversation_id uuid, created_at timestamptz, updated_at timestamptz,
  post_title text, post_category text, post_type text,
  partner_id uuid, partner_name text, partner_avatar_url text,
  partner_trust_score numeric, partner_trust_count integer,
  my_role text, match_score numeric
) AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  RETURN QUERY
  SELECT
    i.id, i.post_id, i.match_id, i.helper_id, i.helped_id,
    i.status, i.message, i.response_message, i.cancel_reason,
    i.completed_at, i.completed_by, i.completion_notes,
    i.helper_rated, i.helped_rated, i.rating_requested,
    i.conversation_id, i.created_at, i.updated_at,
    p.title AS post_title,
    p.category::text AS post_category,
    p.type::text AS post_type,
    -- Partner info (the other user)
    CASE WHEN i.helper_id = v_uid THEN i.helped_id ELSE i.helper_id END AS partner_id,
    CASE WHEN i.helper_id = v_uid THEN hp.name ELSE hlp.name END AS partner_name,
    CASE WHEN i.helper_id = v_uid THEN hp.avatar_url ELSE hlp.avatar_url END AS partner_avatar_url,
    CASE WHEN i.helper_id = v_uid THEN hp.trust_score ELSE hlp.trust_score END AS partner_trust_score,
    CASE WHEN i.helper_id = v_uid THEN hp.trust_score_count ELSE hlp.trust_score_count END AS partner_trust_count,
    CASE WHEN i.helper_id = v_uid THEN 'helper'::text ELSE 'helped'::text END AS my_role,
    m.match_score
  FROM interactions i
  LEFT JOIN posts p ON p.id = i.post_id
  LEFT JOIN profiles hp ON hp.id = i.helped_id
  LEFT JOIN profiles hlp ON hlp.id = i.helper_id
  LEFT JOIN matches m ON m.id = i.match_id
  WHERE
    -- Role filter
    CASE
      WHEN p_role = 'helper' THEN i.helper_id = v_uid
      WHEN p_role = 'helped' THEN i.helped_id = v_uid
      ELSE (i.helper_id = v_uid OR i.helped_id = v_uid)
    END
    -- Status filter
    AND CASE
      WHEN p_status = 'all' THEN true
      WHEN p_status = 'active' THEN i.status IN ('requested','accepted','in_progress')
      WHEN p_status = 'completed' THEN i.status = 'completed'
      WHEN p_status = 'cancelled' THEN i.status IN ('cancelled','cancelled_by_helper','cancelled_by_helped','disputed','resolved')
      ELSE i.status = p_status
    END
  ORDER BY
    CASE WHEN i.status IN ('requested','accepted','in_progress') THEN 0 ELSE 1 END,
    i.updated_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_interaction_stats
CREATE OR REPLACE FUNCTION get_interaction_stats(p_user_id uuid DEFAULT NULL)
RETURNS jsonb AS $$
DECLARE
  v_uid uuid;
  v_total_helper integer;
  v_total_helped integer;
  v_completed integer;
  v_active integer;
  v_cancelled integer;
  v_disputed integer;
  v_avg_hours numeric;
  v_top_cat text;
BEGIN
  v_uid := COALESCE(p_user_id, auth.uid());

  SELECT count(*) INTO v_total_helper FROM interactions WHERE helper_id = v_uid;
  SELECT count(*) INTO v_total_helped FROM interactions WHERE helped_id = v_uid;
  SELECT count(*) INTO v_completed FROM interactions
    WHERE (helper_id = v_uid OR helped_id = v_uid) AND status = 'completed';
  SELECT count(*) INTO v_active FROM interactions
    WHERE (helper_id = v_uid OR helped_id = v_uid) AND status IN ('requested','accepted','in_progress');
  SELECT count(*) INTO v_cancelled FROM interactions
    WHERE (helper_id = v_uid OR helped_id = v_uid) AND status LIKE 'cancelled%';
  SELECT count(*) INTO v_disputed FROM interactions
    WHERE (helper_id = v_uid OR helped_id = v_uid) AND status = 'disputed';

  SELECT AVG(EXTRACT(EPOCH FROM i.completed_at - i.created_at)/3600)
  INTO v_avg_hours
  FROM interactions i
  WHERE (i.helper_id = v_uid OR i.helped_id = v_uid)
    AND i.status = 'completed' AND i.completed_at IS NOT NULL;

  SELECT p.category::text INTO v_top_cat
  FROM interactions i
  JOIN posts p ON p.id = i.post_id
  WHERE i.helper_id = v_uid AND i.status = 'completed' AND p.category IS NOT NULL
  GROUP BY p.category
  ORDER BY count(*) DESC
  LIMIT 1;

  RETURN jsonb_build_object(
    'total_as_helper', v_total_helper,
    'total_as_helped', v_total_helped,
    'completed', v_completed,
    'active', v_active,
    'cancelled', v_cancelled,
    'disputed', v_disputed,
    'average_completion_hours', v_avg_hours,
    'most_helped_category', v_top_cat
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_interaction_counts
CREATE OR REPLACE FUNCTION get_interaction_counts(p_user_id uuid DEFAULT NULL)
RETURNS jsonb AS $$
DECLARE
  v_uid uuid;
  v_requested integer;
  v_active integer;
  v_awaiting_rating integer;
BEGIN
  v_uid := COALESCE(p_user_id, auth.uid());

  -- Requests directed at me (I'm the post owner being asked, or I'm the helped being offered to)
  SELECT count(*) INTO v_requested FROM interactions
    WHERE helped_id = v_uid AND status = 'requested';

  SELECT count(*) INTO v_active FROM interactions
    WHERE (helper_id = v_uid OR helped_id = v_uid)
      AND status IN ('accepted','in_progress');

  SELECT count(*) INTO v_awaiting_rating FROM interactions
    WHERE (helper_id = v_uid OR helped_id = v_uid)
      AND status = 'completed'
      AND ((helper_id = v_uid AND (helper_rated = false OR helper_rated IS NULL))
        OR (helped_id = v_uid AND (helped_rated = false OR helped_rated IS NULL)));

  RETURN jsonb_build_object(
    'requested', v_requested,
    'active', v_active,
    'awaiting_rating', v_awaiting_rating
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- create_interaction_from_match
CREATE OR REPLACE FUNCTION create_interaction_from_match(p_match_id uuid)
RETURNS uuid AS $$
DECLARE
  v_match record;
  v_interaction_id uuid;
  v_offer_name text;
  v_request_name text;
  v_post_title text;
BEGIN
  SELECT * INTO v_match FROM matches WHERE id = p_match_id;
  IF v_match IS NULL THEN
    RAISE EXCEPTION 'Match nicht gefunden';
  END IF;
  IF v_match.status != 'accepted' THEN
    RAISE EXCEPTION 'Match ist nicht im Status accepted';
  END IF;

  SELECT name INTO v_offer_name FROM profiles WHERE id = v_match.offer_user_id;
  SELECT name INTO v_request_name FROM profiles WHERE id = v_match.request_user_id;
  SELECT title INTO v_post_title FROM posts WHERE id = v_match.request_post_id;

  INSERT INTO interactions (
    post_id, match_id, helper_id, helped_id, status,
    conversation_id, message
  ) VALUES (
    v_match.request_post_id,
    p_match_id,
    v_match.offer_user_id,
    v_match.request_user_id,
    'accepted',
    v_match.conversation_id,
    'Interaktion aus Match erstellt'
  ) RETURNING id INTO v_interaction_id;

  INSERT INTO interaction_updates (interaction_id, author_id, update_type, content)
  VALUES (v_interaction_id, v_match.offer_user_id, 'created', 'Interaktion aus Match erstellt');

  UPDATE matches SET status = 'completed' WHERE id = p_match_id;

  -- Notifications
  BEGIN
    INSERT INTO notifications (user_id, type, category, title, content, link, actor_id, metadata)
    VALUES
      (v_match.offer_user_id, 'interaction_created', 'interaction',
       'Neue Interaktion gestartet',
       'Interaktion mit ' || COALESCE(v_request_name, 'Partner') || ' wurde erstellt',
       '/dashboard/interactions/' || v_interaction_id::text,
       v_match.request_user_id,
       jsonb_build_object('interaction_id', v_interaction_id, 'partner_name', v_request_name, 'post_title', v_post_title)),
      (v_match.request_user_id, 'interaction_created', 'interaction',
       'Neue Interaktion gestartet',
       'Interaktion mit ' || COALESCE(v_offer_name, 'Partner') || ' wurde erstellt',
       '/dashboard/interactions/' || v_interaction_id::text,
       v_match.offer_user_id,
       jsonb_build_object('interaction_id', v_interaction_id, 'partner_name', v_offer_name, 'post_title', v_post_title));
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN v_interaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
