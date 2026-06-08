-- ════════════════════════════════════════════════════════════════════════
-- Godmode Module Intelligence — Modul-Analyse-Tabellen
-- Verfolgt KI-generierte Erkenntnisse über App-Module (Schwachstellen,
-- neue Modul-Ideen, Inspirationen aus GitHub-Repos).
-- ════════════════════════════════════════════════════════════════════════

-- Einzelne Erkenntnis über ein Modul (Schwachstelle, Idee, Inspiration).
CREATE TABLE IF NOT EXISTS public.admin_module_insights (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  module_name    text        NOT NULL,
  screen_path    text,
  insight_type   text        NOT NULL DEFAULT 'improvement',
  title          text        NOT NULL,
  description    text        NOT NULL,
  instruction    text,
  severity       text        NOT NULL DEFAULT 'medium',
  category       text        NOT NULL DEFAULT 'feature',
  source         text        DEFAULT 'analysis',
  reference_url  text,
  status         text        NOT NULL DEFAULT 'pending',
  scan_run_id    uuid,
  task_id        uuid        REFERENCES public.admin_dev_tasks(id) ON DELETE SET NULL,
  created_at     timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now()
);

ALTER TABLE public.admin_module_insights
  ADD CONSTRAINT admin_module_insights_severity_check
  CHECK (severity IN ('critical', 'high', 'medium', 'low'));

ALTER TABLE public.admin_module_insights
  ADD CONSTRAINT admin_module_insights_status_check
  CHECK (status IN ('pending', 'accepted', 'dismissed', 'implemented'));

ALTER TABLE public.admin_module_insights
  ADD CONSTRAINT admin_module_insights_type_check
  CHECK (insight_type IN ('improvement', 'new_module', 'vulnerability', 'inspiration'));

CREATE INDEX idx_admin_module_insights_status
  ON public.admin_module_insights(status);
CREATE INDEX idx_admin_module_insights_module
  ON public.admin_module_insights(module_name);

-- Scan-Lauf (eine Modul-Intelligenz-Analyse).
CREATE TABLE IF NOT EXISTS public.admin_module_scan_runs (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  status          text        NOT NULL DEFAULT 'queued',
  run_url         text,
  insights_count  int         DEFAULT 0,
  current_module  text,
  started_at      timestamptz DEFAULT now(),
  completed_at    timestamptz,
  error           text,
  updated_at      timestamptz DEFAULT now()
);

ALTER TABLE public.admin_module_scan_runs
  ADD CONSTRAINT admin_module_scan_runs_status_check
  CHECK (status IN ('queued', 'running', 'done', 'failed'));

-- RLS: nur Admins lesen/schreiben (Schreiben nur via service_role).
ALTER TABLE public.admin_module_insights   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_module_scan_runs  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_only" ON public.admin_module_insights
  USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

CREATE POLICY "admin_only" ON public.admin_module_scan_runs
  USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );
