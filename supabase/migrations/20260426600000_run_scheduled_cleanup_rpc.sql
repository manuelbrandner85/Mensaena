-- ═══════════════════════════════════════════════════════════════════════════
-- run_scheduled_cleanup() RPC
--
-- Wird vom Admin-Dashboard (SystemTab) aufgerufen.
-- Bereinigt abgelaufene Daten und gibt eine Zusammenfassung zurück.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.run_scheduled_cleanup()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expired_posts        integer := 0;
  v_old_notifications    integer := 0;
  v_old_read_notifs      integer := 0;
  v_expired_board_posts  integer := 0;
  v_expired_events       integer := 0;
BEGIN
  -- 1. Abgelaufene Beiträge archivieren (älter als 90 Tage, inaktiv)
  UPDATE public.posts
  SET status = 'archived'
  WHERE status = 'active'
    AND created_at < NOW() - INTERVAL '90 days';
  GET DIAGNOSTICS v_expired_posts = ROW_COUNT;

  -- 2. Alte gelesene Notifications löschen (älter als 30 Tage)
  DELETE FROM public.notifications
  WHERE read = true
    AND created_at < NOW() - INTERVAL '30 days';
  GET DIAGNOSTICS v_old_read_notifs = ROW_COUNT;

  -- 3. Ungelesene Notifications nach 90 Tagen löschen
  DELETE FROM public.notifications
  WHERE read = false
    AND created_at < NOW() - INTERVAL '90 days';
  GET DIAGNOSTICS v_old_notifications = ROW_COUNT;

  -- 4. Abgelaufene Brett-Beiträge archivieren (älter als 180 Tage)
  UPDATE public.board_posts
  SET status = 'archived'
  WHERE status = 'active'
    AND created_at < NOW() - INTERVAL '180 days';
  GET DIAGNOSTICS v_expired_board_posts = ROW_COUNT;

  -- 5. Vergangene Events als abgeschlossen markieren
  UPDATE public.events
  SET status = 'past'
  WHERE status = 'upcoming'
    AND start_date < NOW() - INTERVAL '1 day';
  GET DIAGNOSTICS v_expired_events = ROW_COUNT;

  RETURN jsonb_build_object(
    'expired_posts',       v_expired_posts,
    'old_notifications',   v_old_read_notifs + v_old_notifications,
    'expired_board_posts', v_expired_board_posts,
    'expired_events',      v_expired_events,
    'ran_at',              NOW()
  );
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'run_scheduled_cleanup failed: %', SQLERRM;
  RETURN jsonb_build_object('error', SQLERRM);
END;
$$;

-- Nur service_role und admins dürfen diese Funktion aufrufen
REVOKE ALL ON FUNCTION public.run_scheduled_cleanup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.run_scheduled_cleanup() TO authenticated, service_role;
