-- ════════════════════════════════════════════════════════════════════════
-- Intelligentes Auto-Aufräumen abgelaufener Inhalte via pg_cron.
-- Löscht, was wirklich „abgelaufen" ist — mit Schonfrist, wo Historie zählt.
--   • board_posts:           sofort nach Ablaufdatum (vom User gesetzt)
--   • events:                90 Tage nach Ende (Historie bleibt eine Weile)
--   • admin_dev_suggestions: unbearbeitete (pending) nach 30 Tagen
-- cron.schedule kennt kein ON CONFLICT → idempotent via vorheriges unschedule.
-- ════════════════════════════════════════════════════════════════════════

-- ── Abgelaufene Pinnwand-Beiträge löschen (täglich 01:00 UTC) ──────────────
DO $$ BEGIN PERFORM cron.unschedule('cleanup_expired_board_posts');
EXCEPTION WHEN OTHERS THEN NULL; END $$;
SELECT cron.schedule(
  'cleanup_expired_board_posts',
  '0 1 * * *',
  $sql$DELETE FROM public.board_posts
       WHERE expires_at IS NOT NULL AND expires_at < now()$sql$
);

-- ── Lange vergangene Events löschen (täglich 01:10 UTC, 90 Tage Schonfrist) ─
DO $$ BEGIN PERFORM cron.unschedule('cleanup_old_events');
EXCEPTION WHEN OTHERS THEN NULL; END $$;
SELECT cron.schedule(
  'cleanup_old_events',
  '10 1 * * *',
  $sql$DELETE FROM public.events
       WHERE COALESCE(end_date, start_date + interval '3 hours')
             < now() - interval '90 days'$sql$
);

-- ── Alte, unbearbeitete Godmode-Vorschläge löschen (täglich 01:20 UTC) ──────
-- Nur status='pending' (angenommene/abgelehnte bleiben als Historie).
DO $$ BEGIN PERFORM cron.unschedule('cleanup_stale_dev_suggestions');
EXCEPTION WHEN OTHERS THEN NULL; END $$;
SELECT cron.schedule(
  'cleanup_stale_dev_suggestions',
  '20 1 * * *',
  $sql$DELETE FROM public.admin_dev_suggestions
       WHERE status = 'pending' AND created_at < now() - interval '30 days'$sql$
);
