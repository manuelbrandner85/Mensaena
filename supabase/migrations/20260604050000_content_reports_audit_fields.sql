-- ═══════════════════════════════════════════════════════════════════════════
-- content_reports: Audit-/Nachvollziehbarkeitsfelder
--
-- Bisher hatte content_reports nur status (pending|reviewed|dismissed) —
-- nicht aber WER eine Meldung bearbeitet hat, WANN, und mit WELCHER
-- Auflösung. Damit ist Moderation rechtlich/operativ nicht nachvollziehbar:
-- "Wer hat den Beitrag entfernt?" "Warum wurde nichts unternommen?" lässt
-- sich nachträglich nicht beantworten.
--
-- FIX:
--   • reviewed_by  → profiles.id (Moderator, ON DELETE SET NULL damit der
--                    Audit-Eintrag erhalten bleibt, wenn der Mod-Account
--                    später gelöscht wird).
--   • reviewed_at  → Zeitpunkt der Entscheidung.
--   • resolution   → Kurz-Tag der Aktion (z.B. content_removed,
--                    user_warned, user_banned, no_action, duplicate).
--
-- Trigger füllt reviewed_at automatisch, sobald status von pending wegläuft
-- — so kann der Client nicht "vergessen", den Zeitstempel zu setzen, und
-- ein nachträgliches Manipulieren über UPDATE wird sichtbar.
--
-- Index auf (status, created_at DESC) für die Moderator-Queue.
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.content_reports
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS resolution  text;

-- Resolutions sind ein kontrolliertes Vokabular — keine freien Strings.
-- NULL solange status='pending'.
ALTER TABLE public.content_reports
  DROP CONSTRAINT IF EXISTS content_reports_resolution_check;
ALTER TABLE public.content_reports
  ADD CONSTRAINT content_reports_resolution_check
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

CREATE INDEX IF NOT EXISTS idx_content_reports_queue
  ON public.content_reports (status, created_at DESC);

-- Trigger: setzt reviewed_at automatisch beim Statuswechsel weg von 'pending'.
-- reviewed_by wird vom Trigger NUR gesetzt, falls der Client es nicht selbst
-- mitgeschickt hat (defensive Default).
CREATE OR REPLACE FUNCTION public.content_reports_stamp_review()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status <> 'pending' AND (OLD.status = 'pending' OR OLD.status IS NULL) THEN
    IF NEW.reviewed_at IS NULL THEN
      NEW.reviewed_at := now();
    END IF;
    IF NEW.reviewed_by IS NULL THEN
      NEW.reviewed_by := auth.uid();
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_content_reports_stamp_review ON public.content_reports;
CREATE TRIGGER trg_content_reports_stamp_review
  BEFORE UPDATE ON public.content_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.content_reports_stamp_review();
