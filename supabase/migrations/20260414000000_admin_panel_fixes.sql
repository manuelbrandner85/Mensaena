-- ============================================================================
-- Migration 20260414: Admin Panel Fixes
-- - Admin RLS bypass policies for groups, group_members, challenges,
--   challenge_progress, timebank_entries, profiles
-- - admin_delete_user() SECURITY DEFINER function
-- - get_admin_dashboard_stats() SECURITY DEFINER function
-- ============================================================================

BEGIN;

-- ── 1. groups: admin can UPDATE + DELETE ────────────────────────────────────
DROP POLICY IF EXISTS "groups_admin_update" ON public.groups;
CREATE POLICY "groups_admin_update" ON public.groups FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')));

DROP POLICY IF EXISTS "groups_admin_delete" ON public.groups;
CREATE POLICY "groups_admin_delete" ON public.groups FOR DELETE
  USING (auth.uid() = creator_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

-- ── 2. group_members: admin can DELETE any member ───────────────────────────
DROP POLICY IF EXISTS "group_members_admin_delete" ON public.group_members;
CREATE POLICY "group_members_admin_delete" ON public.group_members FOR DELETE
  USING (auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

-- ── 3. challenges: admin can UPDATE + DELETE ────────────────────────────────
DROP POLICY IF EXISTS "challenges_admin_update" ON public.challenges;
CREATE POLICY "challenges_admin_update" ON public.challenges FOR UPDATE
  USING (auth.uid() = creator_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

DROP POLICY IF EXISTS "challenges_admin_delete" ON public.challenges;
CREATE POLICY "challenges_admin_delete" ON public.challenges FOR DELETE
  USING (auth.uid() = creator_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

-- ── 4. challenge_progress: admin can UPDATE ──────────────────────────────────
DROP POLICY IF EXISTS "challenge_progress_admin_update" ON public.challenge_progress;
CREATE POLICY "challenge_progress_admin_update" ON public.challenge_progress FOR UPDATE
  USING (auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

-- ── 5. timebank_entries: admin can SELECT all + UPDATE ───────────────────────
DROP POLICY IF EXISTS "timebank_admin_read" ON public.timebank_entries;
CREATE POLICY "timebank_admin_read" ON public.timebank_entries FOR SELECT
  USING (
    auth.uid() = giver_id
    OR auth.uid() = receiver_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

DROP POLICY IF EXISTS "timebank_admin_update" ON public.timebank_entries;
CREATE POLICY "timebank_admin_update" ON public.timebank_entries FOR UPDATE
  USING (
    auth.uid() = giver_id
    OR auth.uid() = receiver_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

DROP POLICY IF EXISTS "timebank_admin_delete" ON public.timebank_entries;
CREATE POLICY "timebank_admin_delete" ON public.timebank_entries FOR DELETE
  USING (
    auth.uid() = giver_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

-- ── 6. profiles: admin can UPDATE any profile ────────────────────────────────
DROP POLICY IF EXISTS "profiles_admin_update" ON public.profiles;
CREATE POLICY "profiles_admin_update" ON public.profiles FOR UPDATE
  USING (
    auth.uid() = id
    OR EXISTS (SELECT 1 FROM public.profiles p2 WHERE p2.id = auth.uid() AND p2.role IN ('admin','moderator'))
  );

-- ── 7. admin_delete_user: cascade-delete a user ─────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_delete_user(p_user_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Only admins can call this
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: only admins can delete users';
  END IF;

  -- Delete user data in dependency order (CASCADE handles most, but be explicit)
  DELETE FROM public.timebank_entries    WHERE giver_id = p_user_id OR receiver_id = p_user_id;
  DELETE FROM public.challenge_progress  WHERE user_id = p_user_id;
  DELETE FROM public.group_members       WHERE user_id = p_user_id;
  DELETE FROM public.group_posts         WHERE user_id = p_user_id;
  DELETE FROM public.user_badges         WHERE user_id = p_user_id;
  DELETE FROM public.notifications       WHERE user_id = p_user_id;
  DELETE FROM public.post_reactions      WHERE user_id = p_user_id;
  DELETE FROM public.saved_posts         WHERE user_id = p_user_id;
  DELETE FROM public.trust_ratings       WHERE rater_id = p_user_id OR rated_id = p_user_id;
  DELETE FROM public.interactions        WHERE requester_id = p_user_id OR helper_id = p_user_id;
  DELETE FROM public.crisis_helpers      WHERE user_id = p_user_id;
  DELETE FROM public.crisis_updates      WHERE author_id = p_user_id;
  DELETE FROM public.posts               WHERE user_id = p_user_id;
  DELETE FROM public.events              WHERE author_id = p_user_id;
  DELETE FROM public.board_posts         WHERE author_id = p_user_id;
  DELETE FROM public.crises              WHERE creator_id = p_user_id;
  DELETE FROM public.groups              WHERE creator_id = p_user_id;
  DELETE FROM public.challenges          WHERE creator_id = p_user_id;

  -- Finally delete the profile (CASCADE will also remove auth.users via trigger if set up,
  -- otherwise rely on auth.admin API – here we at minimum remove the profile row)
  DELETE FROM public.profiles WHERE id = p_user_id;

  -- Log the action
  INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, details)
  VALUES (auth.uid(), 'delete_user', 'user', p_user_id, jsonb_build_object('deleted_at', now()));
END;
$$;

-- ── 8. get_admin_dashboard_stats: consolidated stats RPC ────────────────────
CREATE OR REPLACE FUNCTION public.get_admin_dashboard_stats()
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  result JSONB := '{}'::jsonb;
BEGIN
  -- Only admins/moderators can call this
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT jsonb_build_object(
    'total_users',              (SELECT count(*) FROM public.profiles),
    'active_users_30d',         (SELECT count(*) FROM public.profiles WHERE updated_at > now() - interval '30 days'),
    'new_users_7d',             (SELECT count(*) FROM public.profiles WHERE created_at > now() - interval '7 days'),
    'total_posts',              (SELECT count(*) FROM public.posts),
    'active_posts',             (SELECT count(*) FROM public.posts WHERE status = 'active'),
    'new_posts_7d',             (SELECT count(*) FROM public.posts WHERE created_at > now() - interval '7 days'),
    'total_messages',           (SELECT count(*) FROM public.messages),
    'total_conversations',      (SELECT count(*) FROM public.conversations),
    'total_interactions',       (SELECT count(*) FROM public.interactions),
    'completed_interactions',   (SELECT count(*) FROM public.interactions WHERE status = 'completed'),
    'total_events',             (SELECT count(*) FROM public.events),
    'upcoming_events',          (SELECT count(*) FROM public.events WHERE start_date > now() AND status = 'active'),
    'total_board_posts',        (SELECT count(*) FROM public.board_posts),
    'active_board_posts',       (SELECT count(*) FROM public.board_posts WHERE status = 'active'),
    'total_organizations',      (SELECT count(*) FROM public.organizations),
    'verified_organizations',   (SELECT count(*) FROM public.organizations WHERE is_verified = true),
    'total_crises',             (SELECT count(*) FROM public.crises),
    'active_crises',            (SELECT count(*) FROM public.crises WHERE status IN ('active','in_progress')),
    'total_farm_listings',      (SELECT count(*) FROM public.farm_listings),
    'verified_farms',           (SELECT count(*) FROM public.farm_listings WHERE is_verified = true),
    'total_trust_ratings',      (SELECT count(*) FROM public.trust_ratings),
    'avg_trust_score',          COALESCE((SELECT round(avg(score)::numeric, 1) FROM public.trust_ratings), 0),
    'total_notifications',      (SELECT count(*) FROM public.notifications),
    'unread_notifications',     (SELECT count(*) FROM public.notifications WHERE read = false),
    'total_saved_posts',        (SELECT count(*) FROM public.saved_posts),
    'total_regions',            (SELECT count(DISTINCT location) FROM public.profiles WHERE location IS NOT NULL),
    -- New modules
    'total_groups',             (SELECT count(*) FROM public.groups),
    'active_groups',            (SELECT count(*) FROM public.groups WHERE created_at > now() - interval '30 days'),
    'total_challenges',         (SELECT count(*) FROM public.challenges),
    'active_challenges',        (SELECT count(*) FROM public.challenges WHERE status = 'active' AND end_date > now()),
    'total_timebank_hours',     COALESCE((SELECT sum(hours) FROM public.timebank_entries WHERE status = 'confirmed'), 0),
    'total_timebank_entries',   (SELECT count(*) FROM public.timebank_entries)
  ) INTO result;

  RETURN result;
END;
$$;

-- ── 9. admin_change_user_role: allow admins to change user roles ─────────────
CREATE OR REPLACE FUNCTION public.admin_change_user_role(p_user_id UUID, p_new_role TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: only admins can change user roles';
  END IF;

  IF p_new_role NOT IN ('user', 'moderator', 'admin') THEN
    RAISE EXCEPTION 'Invalid role: %', p_new_role;
  END IF;

  UPDATE public.profiles SET role = p_new_role WHERE id = p_user_id;

  INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, details)
  VALUES (auth.uid(), 'change_role', 'user', p_user_id, jsonb_build_object('new_role', p_new_role));
END;
$$;

-- ── 10. Remove old (broken) timebank_own_read policy so admin one takes over ──
-- First drop old exclusive policy if it still exists
DROP POLICY IF EXISTS "timebank_own_read" ON public.timebank_entries;

COMMIT;
