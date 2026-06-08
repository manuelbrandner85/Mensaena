-- ═══════════════════════════════════════════════════════════════════════
-- Auto-Ablauf für Beiträge und Kreisalarme
--
-- Problem: Die posts-Tabelle hat keine automatische Bereinigung.
-- Aktive Beiträge bleiben unbegrenzt in der DB, auch wenn sie längst
-- nicht mehr aktuell sind (derzeit >1000 veraltete Einträge).
-- circle_alerts (SOS/Sicher) laufen ebenfalls nie ab.
--
-- Lösung:
-- 1. posts.expires_at bekommt DEFAULT (now() + 90 Tage)
-- 2. Bestehende aktive Beiträge ohne Ablaufdatum werden rückwirkend
--    auf created_at + 90 Tage gesetzt.
-- 3. Sofort-Bereinigung: aktive Beiträge älter als 90 Tage → archived.
-- 4. pg_cron: täglich abgelaufene aktive Beiträge archivieren.
-- 5. pg_cron: circle_alerts nach 30 Tagen löschen.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. DEFAULT setzen: neue Beiträge laufen automatisch nach 90 Tagen ab.
ALTER TABLE public.posts
  ALTER COLUMN expires_at SET DEFAULT (now() + INTERVAL '90 days');

-- 2. Rückwirkend: aktive/pending Beiträge ohne gesetztes Ablaufdatum.
UPDATE public.posts
SET expires_at = created_at + INTERVAL '90 days'
WHERE expires_at IS NULL
  AND status IN ('active', 'pending');

-- 3. Sofort-Bereinigung der veralteten Beiträge:
--    Alle noch aktiven Einträge, deren berechnetes Ablaufdatum bereits
--    überschritten ist (d.h. älter als 90 Tage), werden archiviert.
UPDATE public.posts
SET status     = 'archived',
    updated_at = now()
WHERE status     = 'active'
  AND expires_at < now();

-- 4. Partieller Index für effizienten pg_cron-Scan.
CREATE INDEX IF NOT EXISTS idx_posts_expires_active
  ON public.posts (expires_at)
  WHERE status = 'active';

-- 5. Index für effizienten circle_alerts-Cleanup.
CREATE INDEX IF NOT EXISTS idx_circle_alerts_created_at
  ON public.circle_alerts (created_at);

-- 6. pg_cron: täglich abgelaufene Beiträge archivieren + Alarme löschen.
DO $cron$
BEGIN
  IF to_regnamespace('cron') IS NULL THEN
    RAISE NOTICE 'pg_cron nicht vorhanden — überspringe Cleanup-Cron-Setup.';
    RETURN;
  END IF;

  -- Abgelaufene aktive Beiträge → archived (täglich 02:15 UTC)
  PERFORM cron.schedule(
    'auto-archive-expired-posts',
    '15 2 * * *',
    $$UPDATE public.posts
      SET status     = 'archived',
          updated_at = now()
      WHERE status     = 'active'
        AND expires_at < now()$$
  );

  -- circle_alerts älter als 30 Tage löschen (täglich 02:20 UTC)
  PERFORM cron.schedule(
    'cleanup-old-circle-alerts',
    '20 2 * * *',
    $$DELETE FROM public.circle_alerts
      WHERE created_at < now() - INTERVAL '30 days'$$
  );

END $cron$;
