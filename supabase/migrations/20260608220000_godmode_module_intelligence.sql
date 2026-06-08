-- ════════════════════════════════════════════════════════════════════════
-- Godmode Module Intelligence — Modul-Analyse-Tabellen
-- Verfolgt KI-generierte Erkenntnisse über App-Module (Schwachstellen,
-- neue Modul-Ideen, Inspirationen aus GitHub-Repos).
--
-- Idempotent: Constraints sind inline in CREATE TABLE IF NOT EXISTS definiert,
-- damit eine bereits existierende DB die Tabelle komplett überspringt und ein
-- erneuter `supabase db push` nicht an doppelten Constraints scheitert.
-- ════════════════════════════════════════════════════════════════════════

-- Einzelne Erkenntnis über ein Modul (Schwachstelle, Idee, Inspiration).
CREATE TABLE IF NOT EXISTS public.admin_module_insights (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  module_name    text        NOT NULL,
  screen_path    text,
  insight_type   text        NOT NULL DEFAULT 'improvement'
                 CONSTRAINT admin_module_insights_type_check
                 CHECK (insight_type IN ('improvement', 'new_module', 'vulnerability', 'inspiration')),
  title          text        NOT NULL,
  description    text        NOT NULL,
  instruction    text,
  severity       text        NOT NULL DEFAULT 'medium'
                 CONSTRAINT admin_module_insights_severity_check
                 CHECK (severity IN ('critical', 'high', 'medium', 'low')),
  category       text        NOT NULL DEFAULT 'feature',
  source         text        DEFAULT 'analysis',
  reference_url  text,
  status         text        NOT NULL DEFAULT 'pending'
                 CONSTRAINT admin_module_insights_status_check
                 CHECK (status IN ('pending', 'accepted', 'dismissed', 'implemented')),
  scan_run_id    uuid,
  task_id        uuid        REFERENCES public.admin_dev_tasks(id) ON DELETE SET NULL,
  created_at     timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_module_insights_status
  ON public.admin_module_insights(status);
CREATE INDEX IF NOT EXISTS idx_admin_module_insights_module
  ON public.admin_module_insights(module_name);

-- Scan-Lauf (eine Modul-Intelligenz-Analyse).
CREATE TABLE IF NOT EXISTS public.admin_module_scan_runs (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  status          text        NOT NULL DEFAULT 'queued'
                  CONSTRAINT admin_module_scan_runs_status_check
                  CHECK (status IN ('queued', 'running', 'done', 'failed')),
  run_url         text,
  insights_count  int         DEFAULT 0,
  current_module  text,
  started_at      timestamptz DEFAULT now(),
  completed_at    timestamptz,
  error           text,
  updated_at      timestamptz DEFAULT now()
);

-- RLS: nur Admins lesen/schreiben (Schreiben nur via service_role).
ALTER TABLE public.admin_module_insights   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_module_scan_runs  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_only" ON public.admin_module_insights;
CREATE POLICY "admin_only" ON public.admin_module_insights
  USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

DROP POLICY IF EXISTS "admin_only" ON public.admin_module_scan_runs;
CREATE POLICY "admin_only" ON public.admin_module_scan_runs
  USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );
