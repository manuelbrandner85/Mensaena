-- ════════════════════════════════════════════════════════════════════════
-- Auto-Close verwaister Live-Räume
--
-- Problem (vom Audit gefunden): Räume bleiben auf status='live' hängen, wenn
-- niemand beigetreten ist (der Client-Auto-Close feuert nur, wenn jemand erst
-- beitritt und dann geht). Ergebnis: Geister-„live"-Räume → falscher Live-
-- Banner. Aktuell 5 solcher Räume (Wochen alt).
--
-- Lösung: Funktion + pg_cron-Job (alle 30 Min) schließt 'live'-Räume, deren
-- Start > 4 h zurückliegt (reale Nachbarschafts-Streams überschreiten das
-- praktisch nie). Plus einmalige Sofort-Bereinigung der bestehenden.
-- ════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.cleanup_stale_live_rooms()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.live_rooms
  SET status = 'ended',
      ended_at = COALESCE(ended_at, now())
  WHERE status = 'live'
    AND started_at < now() - interval '4 hours';
$$;

-- Bestehende Geister-Räume sofort schließen.
SELECT public.cleanup_stale_live_rooms();

-- Alle 30 Minuten planen (idempotent).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup_stale_live_rooms') THEN
    PERFORM cron.unschedule('cleanup_stale_live_rooms');
  END IF;
  PERFORM cron.schedule(
    'cleanup_stale_live_rooms',
    '*/30 * * * *',
    $cron$ SELECT public.cleanup_stale_live_rooms(); $cron$
  );
END $$;
