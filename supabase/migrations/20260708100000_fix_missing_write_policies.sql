-- DB-Audit 2026-07-08: 5 fehlende Schreib-Policies = still kaputte Features.
--
-- Der App-Code führt auf diesen Tabellen INSERT/UPDATE aus, aber es existierte
-- keine passende Policy → RLS blockierte still, der Nutzer sah nur "geht
-- nicht". Verifizierte Aufrufer:
--   * organization_members INSERT — extra_repositories.dart (Organisation
--     beitreten schlug für ALLE fehl!)
--   * post_poll_votes UPDATE      — polls_repository.dart (Stimme ändern)
--   * group_post_reactions UPDATE — extra_repositories.dart (Emoji ändern)
--   * user_blocks UPDATE          — user_blocks_repository.dart (Upsert-
--     Konfliktpfad beim erneuten Blockieren)
--   * safety_report_upvotes UPDATE — safety_repository.dart (Upsert-Konflikt
--     beim erneuten Upvoten)
--
-- Alle Policies sind strikt owner-gebunden (auth.uid() = eigene Zeile) und
-- rein ADDITIV — bestehende Policies bleiben unangetastet. Idempotent via
-- DROP IF EXISTS + CREATE (Projekt-Konvention).

-- 1) Organisation beitreten: User darf NUR sich selbst als Mitglied eintragen.
DROP POLICY IF EXISTS org_members_insert_self ON public.organization_members;
CREATE POLICY org_members_insert_self ON public.organization_members
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- 2) Umfrage-Stimme ändern: nur die eigene Stimme.
DROP POLICY IF EXISTS post_poll_votes_update_own ON public.post_poll_votes;
CREATE POLICY post_poll_votes_update_own ON public.post_poll_votes
  FOR UPDATE USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 3) Gruppen-Reaktion (Emoji) ändern: nur die eigene Reaktion.
DROP POLICY IF EXISTS group_post_reactions_update_own
  ON public.group_post_reactions;
CREATE POLICY group_post_reactions_update_own ON public.group_post_reactions
  FOR UPDATE USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 4) Block erneuern (Upsert-Konfliktpfad): nur eigene Block-Einträge.
DROP POLICY IF EXISTS user_blocks_update_own ON public.user_blocks;
CREATE POLICY user_blocks_update_own ON public.user_blocks
  FOR UPDATE USING (blocker_id = auth.uid())
  WITH CHECK (blocker_id = auth.uid());

-- 5) Upvote erneuern (Upsert-Konfliktpfad): nur eigene Upvotes.
DROP POLICY IF EXISTS safety_report_upvotes_update_own
  ON public.safety_report_upvotes;
CREATE POLICY safety_report_upvotes_update_own
  ON public.safety_report_upvotes
  FOR UPDATE USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ── Backfill: marketing_regions_overview() fehlte in der Migrationshistorie ──
-- Wie is_conversation_member (Fix 2026-07-01): die Funktion wurde nur manuell
-- im Dashboard-SQL-Editor angelegt und nie als Migration getrackt. Auf Prod
-- ist CREATE OR REPLACE ein No-Op (Definition 1:1 identisch übernommen);
-- frische Aufsetzungen (Preview-Branch/Disaster-Recovery) erhalten die
-- Funktion jetzt automatisch. Aufrufer: marketing_repository.dart,
-- auto-health-report + region-ignite-alert Edge Functions.
CREATE OR REPLACE FUNCTION public.marketing_regions_overview()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  WITH region_users AS (
    SELECT coalesce(p.region, '(unbekannt)') AS name, count(*) AS users,
           count(*) FILTER (WHERE p.created_at >= now() - interval '7 days') AS new_users_7d
    FROM public.profiles p WHERE p.region IS NOT NULL AND p.region <> ''
    GROUP BY p.region
  ),
  region_activity AS (
    SELECT p.region AS name, count(*) AS active_7d
    FROM public.profiles p
    JOIN public.user_status us ON us.user_id = p.id
    WHERE us.updated_at >= now() - interval '7 days' AND p.region IS NOT NULL AND p.region <> ''
    GROUP BY p.region
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'name', ru.name, 'users', ru.users, 'new_users_7d', ru.new_users_7d,
    'active_7d', coalesce(ra.active_7d, 0),
    'signal', CASE
      WHEN ru.users >= 20 AND coalesce(ra.active_7d, 0) >= 10 THEN 'lebt'
      WHEN ru.users >= 20 AND coalesce(ra.active_7d, 0) <  3 THEN 'braucht_hilfe'
      WHEN ru.users <  20 THEN 'klein'
      ELSE 'normal' END
  ) ORDER BY ru.users DESC), '[]'::jsonb)
  FROM region_users ru LEFT JOIN region_activity ra ON ra.name = ru.name;
$function$;

GRANT EXECUTE ON FUNCTION public.marketing_regions_overview() TO authenticated;
