-- ════════════════════════════════════════════════════════════════════════
-- Godmode-Erweiterung — Live-Fortschritt beim Scan + CI/PR-Tracking bei Tasks.
--
-- 1) admin_scan_runs: Felder für die Live-Anzeige während der Tiefenanalyse.
--    Die GitHub Action (admin_scan.yml) schreibt laufend, welche Datei gerade
--    analysiert wird (current_file), wie viele Dateien schon gelesen wurden
--    (analyzed_files), wie viele Vorschläge bisher gefunden sind (found_so_far)
--    und einen Heartbeat (heartbeat_at) — damit das Dashboard wirklich zeigt,
--    dass der Agent arbeitet.
--
-- 2) admin_dev_tasks: ci_status + ci_run_url, damit das Dashboard den ganzen
--    Weg eines angenommenen Vorschlags live anzeigt:
--    Agent → PR → CI (grün/rot) → Merge → OTA.
--
-- Additiv + idempotent — sicher mehrfach ausführbar.
-- ════════════════════════════════════════════════════════════════════════

-- ── 1) Live-Fortschritt für Scan-Läufe ────────────────────────────────────
ALTER TABLE public.admin_scan_runs
  ADD COLUMN IF NOT EXISTS phase          text,
  ADD COLUMN IF NOT EXISTS current_file   text,
  ADD COLUMN IF NOT EXISTS analyzed_files int         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS found_so_far   int         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS heartbeat_at   timestamptz;

-- ── 2) CI/PR-Tracking für Tasks ───────────────────────────────────────────
ALTER TABLE public.admin_dev_tasks
  ADD COLUMN IF NOT EXISTS ci_status  text,
  ADD COLUMN IF NOT EXISTS ci_run_url text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'admin_dev_tasks_ci_status_chk'
  ) THEN
    ALTER TABLE public.admin_dev_tasks
      ADD CONSTRAINT admin_dev_tasks_ci_status_chk
      CHECK (ci_status IS NULL OR ci_status IN ('pending','running','success','failure'));
  END IF;
END $$;
