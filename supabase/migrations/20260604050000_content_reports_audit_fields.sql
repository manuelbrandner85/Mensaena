-- ═══════════════════════════════════════════════════════════════════════════
-- reports: resolution-Vokabular + Auto-Stempel-Trigger
--
-- Korrektur 2026-06-04: Die erste Version dieser Migration zielte auf
-- public.content_reports — diese Tabelle existiert auf der Remote-DB nicht
-- (Legacy-Definition aus 20260411/20260426 wurde nie applied). Die
-- aktive Reports-Tabelle heisst `public.reports`. Da der erste Versuch
-- NIE erfolgreich durchlief (ERROR 42P01: relation does not exist),
-- ist das Ueberschreiben dieser Migrations-Datei sicher — auf der
-- Remote-DB wurde nichts in schema_migrations eingetragen.
--
-- Die aktive `reports`-Tabelle hat bereits:
--   • resolved_by uuid → auth.users(id)
--   • resolved_at timestamptz
--   • status text (pending|reviewing|resolved|dismissed, später auch
--                  reviewed via 20260602160000)
--   • RLS fuer admin/moderator
--
-- Was fehlt fuer saubere Moderations-Nachvollziehbarkeit ist ein
-- kontrolliertes WAS-wurde-getan-Vokabular (status sagt nur, OB
-- entschieden wurde, nicht WIE). Das ergaenzen wir:
--   • resolution text — content_removed | content_kept | user_warned
--                       | user_banned | no_action | duplicate | spam
--                       | other  (NULL solange status='pending').
--
-- Ein BEFORE-UPDATE-Trigger stempelt resolved_at/resolved_by automatisch,
-- sobald status von 'pending' weglaeuft — so kann der Client den
-- Audit-Zeitstempel nicht "vergessen", und nachtraegliche UPDATEs
-- ueberschreiben einen bereits gesetzten Stempel NICHT mehr.
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS resolution text;

ALTER TABLE public.reports
  DROP CONSTRAINT IF EXISTS reports_resolution_check;
ALTER TABLE public.reports
  ADD CONSTRAINT reports_resolution_check
  CHECK (
    resolution IS NULL
    OR resolution IN (
      'content_removed',
      'content_kept',
      'user_warned',
      'user_banned',
      'no_action',
      'duplicate',
      'spam',
      'other'
    )
  );

CREATE INDEX IF NOT EXISTS idx_reports_queue
  ON public.reports (status, created_at DESC);

-- Trigger: stempelt resolved_at/resolved_by beim Statuswechsel weg von
-- 'pending'. Setzt NUR, falls noch nicht gesetzt — so kann ein expliziter
-- Wert vom Client (z.B. fuer Backfill) erhalten bleiben, aber niemand kann
-- einen bereits vorhandenen Stempel ueberschreiben.
CREATE OR REPLACE FUNCTION public.reports_stamp_resolution()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status
     AND OLD.status = 'pending'
     AND NEW.status <> 'pending' THEN
    IF NEW.resolved_at IS NULL THEN
      NEW.resolved_at := now();
    END IF;
    IF NEW.resolved_by IS NULL THEN
      NEW.resolved_by := auth.uid();
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reports_stamp_resolution ON public.reports;
CREATE TRIGGER trg_reports_stamp_resolution
  BEFORE UPDATE ON public.reports
  FOR EACH ROW
  EXECUTE FUNCTION public.reports_stamp_resolution();
