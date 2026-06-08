-- ════════════════════════════════════════════════════════════════════════
-- Godmode v3 — Bild-Upload (Vision), Review-Gate, Abbruch & Auto-Cleanup.
--
--   • image_urls    — optionale Screenshots zum Auftrag (Vision). Der Agent
--                     lädt sie im Workflow herunter und „sieht" sie sich an.
--   • await_review  — wenn true, wird NICHT automatisch gemergt; der Admin
--                     prüft erst den Diff und gibt manuell frei.
--   • Status erweitert: 'awaiting_review' (wartet auf Freigabe) + 'cancelled'.
--   • Auto-Cleanup: ein pg_cron-Job löscht abgeschlossene Auftrags-Einträge
--     nach 24 h (nur die Auftragszeile — der gemergte Code bleibt erhalten).
--
-- Additiv + idempotent — sicher mehrfach ausführbar.
-- ════════════════════════════════════════════════════════════════════════

ALTER TABLE public.admin_dev_tasks
  ADD COLUMN IF NOT EXISTS image_urls   text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS await_review boolean NOT NULL DEFAULT false;

-- Status-CHECK um 'awaiting_review' + 'cancelled' erweitern.
ALTER TABLE public.admin_dev_tasks
  DROP CONSTRAINT IF EXISTS admin_dev_tasks_status_check;
ALTER TABLE public.admin_dev_tasks
  ADD CONSTRAINT admin_dev_tasks_status_check
  CHECK (status IN ('queued','running','pr_open','awaiting_review',
                    'merged','failed','no_changes','cancelled'));

-- ── Auto-Cleanup: abgeschlossene Auftrags-Einträge nach 24 h entfernen ──────
-- Läuft alle 30 Minuten. Löscht NUR Auftragszeilen in einem Endzustand, deren
-- letzte Aktualisierung > 24 h zurückliegt. Der entwickelte Code ist längst
-- auf main gemergt und bleibt selbstverständlich erhalten.
CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'godmode-task-cleanup') THEN
    PERFORM cron.unschedule('godmode-task-cleanup');
  END IF;
  PERFORM cron.schedule(
    'godmode-task-cleanup',
    '*/30 * * * *',
    $cleanup$
      DELETE FROM public.admin_dev_tasks
      WHERE status IN ('merged','failed','no_changes','cancelled')
        AND updated_at < now() - interval '24 hours';
    $cleanup$
  );
END $$;
