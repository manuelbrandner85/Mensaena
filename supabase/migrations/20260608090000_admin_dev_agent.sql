-- ════════════════════════════════════════════════════════════════════════
-- Admin-Entwicklungs-Agent — Code/Features/Bugfixes aus dem Admin-Dashboard.
--
-- Ein Admin formuliert eine Aufgabe ("Baue ein Umfrage-Modul", "Fix: Karte
-- lädt nicht", "Ändere die Button-Farbe"). Die Edge Function `admin-dev-agent`
-- legt hier eine Zeile an und triggert die GitHub Action `admin_agent.yml`,
-- die den Code via Claude Code CLI ändert, einen PR erstellt und – NUR bei
-- grünem Flutter-CI – automatisch mergt. Anschließend liefert Shorebird den
-- Dart-Patch lautlos als OTA an alle Installationen.
--
-- Sicherheit:
--   • NUR role='admin' darf Tasks anlegen (Edge Function prüft + RLS).
--   • Tabelle ist read-only für Admins; Schreibzugriff ausschließlich via
--     service_role (Edge Function + GitHub-Workflow-Statusupdates).
-- Additiv + idempotent — sicher mehrfach ausführbar.
-- ════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.admin_dev_tasks (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  created_by   uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  instruction  text        NOT NULL,
  status       text        NOT NULL DEFAULT 'queued'
                 CHECK (status IN ('queued','running','pr_open','merged','failed','no_changes')),
  branch       text,
  pr_url       text,
  pr_number    int,
  run_url      text,
  error        text,
  summary      text
);

CREATE INDEX IF NOT EXISTS idx_admin_dev_tasks_created
  ON public.admin_dev_tasks (created_at DESC);

-- ════════════════════════════════════════════════════════════════════════
-- RLS — NUR Admins lesen; service_role (Edge Function + Workflow) bypassed RLS.
-- Kein INSERT/UPDATE-Policy für authenticated → Schreiben nur serverseitig.
-- ════════════════════════════════════════════════════════════════════════
ALTER TABLE public.admin_dev_tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin dev tasks read" ON public.admin_dev_tasks;
CREATE POLICY "admin dev tasks read" ON public.admin_dev_tasks
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = auth.uid() AND role = 'admin'));
