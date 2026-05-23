-- ════════════════════════════════════════════════════════════════════════
-- Notification-Title-Normalization
--
-- Problem: Push-Notifications zeigten nur "Mensaena" als Titel weil manche
-- Trigger-Functions notifications.title NULL liessen. Statt 6 alte Trigger-
-- Files zu touchen, normalisiert ein BEFORE-INSERT-Trigger den Title nach
-- Notification-Type — nur aktiv wenn title leer ist, ueberschreibt nichts.
-- ════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.normalize_notification_title()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_name text;
BEGIN
  IF NEW.actor_id IS NOT NULL THEN
    SELECT COALESCE(name, display_name, 'Jemand')
      INTO v_actor_name
      FROM public.profiles
      WHERE id = NEW.actor_id;
  END IF;

  NEW.title := CASE NEW.type
    WHEN 'message'             THEN COALESCE(v_actor_name, 'Neue Nachricht')
    WHEN 'incoming_call'       THEN COALESCE(v_actor_name || ' ruft an', 'Eingehender Anruf')
    WHEN 'dm_call_incoming'    THEN COALESCE(v_actor_name || ' ruft an', 'Eingehender Anruf')
    WHEN 'call_missed'         THEN COALESCE('Verpasster Anruf von ' || v_actor_name, 'Verpasster Anruf')
    WHEN 'new_event'           THEN 'Neues Event in deiner Nähe'
    WHEN 'event_invite'        THEN 'Event-Einladung'
    WHEN 'event_reminder'      THEN 'Event-Erinnerung'
    WHEN 'new_match'           THEN 'Neuer Match'
    WHEN 'match_accepted'      THEN 'Match angenommen'
    WHEN 'match_expired'       THEN 'Match läuft ab'
    WHEN 'new_post'            THEN 'Neuer Beitrag in deiner Gruppe'
    WHEN 'post_comment'        THEN 'Neuer Kommentar'
    WHEN 'post_reaction'       THEN 'Neue Reaktion'
    WHEN 'trust_rating'        THEN 'Neue Bewertung'
    WHEN 'live_room_started'   THEN COALESCE(v_actor_name || ' ist live', 'Live-Stream gestartet')
    WHEN 'group_invite'        THEN 'Gruppen-Einladung'
    WHEN 'crisis_alert'        THEN 'Krisen-Warnung'
    WHEN 'interaction_created' THEN 'Neue Interaktion'
    WHEN 'interaction_status'  THEN 'Interaktion aktualisiert'
    WHEN 'welcome'             THEN 'Willkommen bei Mensaena'
    WHEN 'thanks'              THEN COALESCE('Danke von ' || v_actor_name, 'Du hast Danke bekommen')
    WHEN 'follow'              THEN COALESCE(v_actor_name || ' folgt dir', 'Neuer Follower')
    ELSE 'Mensaena'
  END;
  RETURN NEW;
END;
$$;

-- aaa_ Prefix sichert alphabetisch erste Trigger-Ausfuehrung
DROP TRIGGER IF EXISTS aaa_normalize_notification_title ON public.notifications;
CREATE TRIGGER aaa_normalize_notification_title
  BEFORE INSERT ON public.notifications
  FOR EACH ROW
  WHEN (NEW.title IS NULL OR length(trim(NEW.title)) = 0)
  EXECUTE FUNCTION public.normalize_notification_title();

GRANT EXECUTE ON FUNCTION public.normalize_notification_title() TO authenticated, service_role;
