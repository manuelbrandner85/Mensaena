-- ════════════════════════════════════════════════════════════════════════
-- Godmode v2 — „Warum"-Begründung, Typ-Marker (Bug/Neuerung/Verbesserung),
-- selbstlernende Kategorien und Auto-Fix-Zähler.
--
-- 1) admin_dev_suggestions:
--    • reason  — verständliche Begründung WARUM der Vorschlag sinnvoll ist.
--    • kind    — Typ-Marker: bug | improvement | new (Neuerung).
--    • category-CHECK entfernt → der KI-Agent darf mit der Zeit NEUE Kategorien
--      vergeben (selbstlernend). Gültige Kategorien stehen in admin_dev_categories.
--
-- 2) admin_dev_tasks.ci_attempts — Zähler der automatischen CI-Reparaturversuche
--    (Auto-Fix). Begrenzt die Auto-Fix-Schleife (max. 3).
--
-- 3) admin_dev_categories — vom Agenten selbst entdeckte/angelegte Kategorien
--    (oder manuell). Nur Admins lesen; Schreiben via service_role.
--
-- Additiv + idempotent — sicher mehrfach ausführbar.
-- ════════════════════════════════════════════════════════════════════════

ALTER TABLE public.admin_dev_suggestions
  ADD COLUMN IF NOT EXISTS reason text,
  ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'improvement';

ALTER TABLE public.admin_dev_suggestions
  DROP CONSTRAINT IF EXISTS admin_dev_suggestions_category_check;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='admin_dev_suggestions_kind_chk') THEN
    ALTER TABLE public.admin_dev_suggestions
      ADD CONSTRAINT admin_dev_suggestions_kind_chk CHECK (kind IN ('bug','improvement','new'));
  END IF;
END $$;

ALTER TABLE public.admin_dev_tasks
  ADD COLUMN IF NOT EXISTS ci_attempts int NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.admin_dev_categories (
  key         text        PRIMARY KEY,
  label       text        NOT NULL,
  description text,
  source      text        NOT NULL DEFAULT 'ai',
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_dev_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin dev categories read" ON public.admin_dev_categories;
CREATE POLICY "admin dev categories read" ON public.admin_dev_categories
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='admin'));
