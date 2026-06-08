-- ════════════════════════════════════════════════════════════════════════
-- Admin-Dev-Suggestions — KI-Tiefenanalyse der GESAMTEN App.
--
-- Eine GitHub Action (`admin_scan.yml`) lässt die Claude Code CLI die komplette
-- App lesen (jeden Screen, jedes Detail) und meldet konkrete Vorschläge:
-- logische Fehler, Bugs, UI/UX-Verbesserungen, Performance, i18n-Lücken,
-- Sicherheits- und Datenbankprobleme. Jeder Vorschlag landet hier und kann
-- vom Admin angenommen (→ erzeugt einen admin_dev_tasks-Auftrag → OTA) oder
-- abgelehnt werden.
--
-- Sicherheit:
--   • NUR role='admin' liest (RLS). Schreiben ausschließlich via service_role
--     (Edge Function `admin-dev-suggestions` + GitHub-Workflow).
-- Additiv + idempotent — sicher mehrfach ausführbar.
-- ════════════════════════════════════════════════════════════════════════

-- ── Scan-Läufe (Status der Tiefenanalyse) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_scan_runs (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  created_by  uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  status      text        NOT NULL DEFAULT 'queued'
                CHECK (status IN ('queued','running','done','failed')),
  found       int         NOT NULL DEFAULT 0,
  run_url     text,
  error       text
);

CREATE INDEX IF NOT EXISTS idx_admin_scan_runs_created
  ON public.admin_scan_runs (created_at DESC);

-- ── Einzelne Vorschläge ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_dev_suggestions (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  scan_id      uuid        REFERENCES public.admin_scan_runs(id) ON DELETE SET NULL,
  category     text        NOT NULL DEFAULT 'feature'
                 CHECK (category IN ('ui','feature','bug','performance','i18n','database','security','config')),
  severity     text        NOT NULL DEFAULT 'medium'
                 CHECK (severity IN ('low','medium','high','critical')),
  title        text        NOT NULL,
  description  text,
  instruction  text        NOT NULL,
  file_hint    text,
  status       text        NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','accepted','rejected','implemented')),
  task_id      uuid        REFERENCES public.admin_dev_tasks(id) ON DELETE SET NULL,
  reviewed_by  uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at  timestamptz
);

CREATE INDEX IF NOT EXISTS idx_admin_dev_suggestions_status
  ON public.admin_dev_suggestions (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_dev_suggestions_category
  ON public.admin_dev_suggestions (category);

-- ════════════════════════════════════════════════════════════════════════
-- RLS — NUR Admins lesen; service_role bypassed RLS (Edge Function + Workflow).
-- ════════════════════════════════════════════════════════════════════════
ALTER TABLE public.admin_scan_runs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_dev_suggestions  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin scan runs read" ON public.admin_scan_runs;
CREATE POLICY "admin scan runs read" ON public.admin_scan_runs
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "admin dev suggestions read" ON public.admin_dev_suggestions;
CREATE POLICY "admin dev suggestions read" ON public.admin_dev_suggestions
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = auth.uid() AND role = 'admin'));
