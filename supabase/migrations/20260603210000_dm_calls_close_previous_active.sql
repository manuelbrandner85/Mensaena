-- ═══════════════════════════════════════════════════════════════════════════
-- Fix: 23505 "duplicate key value violates unique constraint
--      idx_dm_calls_active_conv" beim direkten Folge-Anruf in derselben
--      Konversation (User-Report 2026-06-03).
--
-- Ursache: Ein partieller UNIQUE-Index erlaubt nur einen Call pro Konversation
-- im Status ringing|active. Wenn das clientseitige Hangup-Update den alten
-- Call aus irgendeinem Grund nicht sauber auf 'ended' gesetzt hat (Netz weg,
-- App backgrounded, fire-and-forget verloren), kollidiert der neue INSERT.
--
-- Fix: BEFORE-INSERT-Trigger schließt vorausgehende lebende Calls derselben
-- Konversation automatisch — server-seitig, idempotent, client-unabhängig.
-- Greift nur wenn NEW.status='ringing' (sonst kein Konflikt zu erwarten).
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.dm_calls_close_previous_active()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.status = 'ringing' THEN
    UPDATE public.dm_calls
       SET status       = 'ended',
           ended_at     = COALESCE(ended_at, NOW()),
           ended_reason = COALESCE(ended_reason, 'completed')
     WHERE conversation_id = NEW.conversation_id
       AND status IN ('ringing','active')
       AND id <> NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS dm_calls_close_previous_active ON public.dm_calls;
CREATE TRIGGER dm_calls_close_previous_active
  BEFORE INSERT ON public.dm_calls
  FOR EACH ROW
  EXECUTE FUNCTION public.dm_calls_close_previous_active();

-- One-shot Cleanup für bereits vorhandene Geister-Calls, damit der nächste
-- echte Anruf nicht weiter am Unique-Index hängenbleibt.
UPDATE public.dm_calls
   SET status       = 'ended',
       ended_at     = COALESCE(ended_at, NOW()),
       ended_reason = COALESCE(ended_reason, 'completed')
 WHERE status IN ('ringing','active')
   AND created_at < NOW() - INTERVAL '30 seconds';
