-- ════════════════════════════════════════════════════════════════════════
-- Godmode Notizen / Backlog — der Admin sammelt Ideen (Prompts) für spätere
-- Aufträge. Eine Notiz kann jederzeit (mit Bestätigung) als Auftrag an den
-- Dev-Agenten gesendet werden. Reine Text-Einträge, admin-only.
--
-- Schreibzugriff ausschließlich serverseitig via Edge Function (service_role).
-- Additiv + idempotent.
-- ════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.admin_dev_notes (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  created_by  uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  content     text        NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_admin_dev_notes_updated
  ON public.admin_dev_notes (updated_at DESC);

ALTER TABLE public.admin_dev_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin dev notes read" ON public.admin_dev_notes;
CREATE POLICY "admin dev notes read" ON public.admin_dev_notes
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = auth.uid() AND role = 'admin'));
