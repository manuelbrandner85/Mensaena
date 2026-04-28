-- ═══════════════════════════════════════════════════════════════════════════
-- Fix: notifications.body / .content Dual-Column-Inkonsistenz
--
-- Historie:
-- - 001_schema.sql definierte notifications.body (NOT NULL)
-- - 20260407020000_notification_center.sql fügte content hinzu
-- - Seither schreiben manche Inserter body, manche content, manche beides.
--   Inserter die NUR content setzen → scheitern mit 23502, oft unsichtbar
--   (z.B. in PL/pgSQL mit EXCEPTION WHEN OTHERS → Warning).
--
-- Fix: BEFORE-INSERT/UPDATE-Trigger der body und content spiegelt, wenn eines
-- fehlt. Backwards-kompatibel für alle existierenden Inserter.
-- ═══════════════════════════════════════════════════════════════════════════

-- Stelle sicher, dass die content-Spalte existiert (body ist in 001_schema definiert, content fehlte)
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS content TEXT;

CREATE OR REPLACE FUNCTION public.notifications_sync_body_content()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Wenn nur eins gesetzt ist → das andere übernehmen
  IF NEW.body IS NULL AND NEW.content IS NOT NULL THEN
    NEW.body := NEW.content;
  ELSIF NEW.content IS NULL AND NEW.body IS NOT NULL THEN
    NEW.content := NEW.body;
  END IF;

  -- Beide NULL → Titel als Fallback (damit NOT-NULL nicht feuert)
  IF NEW.body IS NULL THEN
    NEW.body := COALESCE(NEW.title, '');
  END IF;
  IF NEW.content IS NULL THEN
    NEW.content := COALESCE(NEW.title, '');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notifications_sync_body_content ON public.notifications;
CREATE TRIGGER trg_notifications_sync_body_content
  BEFORE INSERT OR UPDATE OF body, content ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.notifications_sync_body_content();

-- Verifikation: sollte row zurückgeben
SELECT
  EXISTS(SELECT 1 FROM pg_trigger
         WHERE tgname = 'trg_notifications_sync_body_content'
         AND NOT tgisinternal) AS sync_trigger_installed;
