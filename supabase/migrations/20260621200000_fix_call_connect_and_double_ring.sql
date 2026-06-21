-- ════════════════════════════════════════════════════════════════════════
-- Behebt zwei Anruf-Bugs (sichtbar geworden, nachdem Realtime/Push wieder geht)
--
-- BUG 1 „klingelt, verbindet aber nicht": dm_calls_close_previous_active setzte
--   bei JEDEM neuen 'ringing'-Insert ALLE ringing/active-Rows der Konversation
--   auf 'ended' — auch die gerade angenommene Gegen-Verbindung und (bei
--   Gruppen-Calls) die Rows desselben Raums. Ein paralleler Rück-/Recall oder
--   eine Einladung beendete so die laufende Verbindung → Caller sieht 'ended'.
--
-- BUG 2 „Doppel-Klingeln beim Angerufenen": zwei Trigger feuerten pro Insert —
--   notify_call_on_dm_calls_insert (→ notify-call, CallKit-Push, kanonisch)
--   UND trg_notify_on_dm_call (→ notifications-Row → send-push, ZWEITER
--   'incoming_call'-FCM). Der Angerufene bekam zwei Call-Pushes.
-- ════════════════════════════════════════════════════════════════════════

-- ── BUG 1: nur EIGENE Vor-Anrufe & NIE den gleichen Raum schließen ───
CREATE OR REPLACE FUNCTION public.dm_calls_close_previous_active()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.status = 'ringing' THEN
    UPDATE public.dm_calls
       SET status       = 'ended',
           ended_at     = COALESCE(ended_at, NOW()),
           ended_reason = COALESCE(ended_reason, 'completed')
     WHERE conversation_id = NEW.conversation_id
       AND status IN ('ringing', 'active')
       AND id <> NEW.id
       -- nur eigene frühere Calls aufräumen, nie die der Gegenseite beenden
       AND caller_id = NEW.caller_id
       -- niemals Rows im selben LiveKit-Raum schließen (Gruppen-Call/Invite,
       -- gerade angenommener Call teilen sich den room_name)
       AND room_name IS DISTINCT FROM NEW.room_name;
  END IF;
  RETURN NEW;
END;
$function$;

-- ── BUG 2: doppelten Call-Push-Trigger entfernen ─────────────────────
-- notify-call (notify_call_on_dm_calls_insert) bleibt der einzige Call-Push.
DROP TRIGGER IF EXISTS trg_notify_on_dm_call ON public.dm_calls;
