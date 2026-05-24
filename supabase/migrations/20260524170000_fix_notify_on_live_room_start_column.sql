-- Fix: notify_on_live_room_start referenzierte messages.user_id, aber
-- die Spalte heißt sender_id. Dadurch scheiterte JEDER live_rooms-Insert
-- mit "column user_id does not exist" → Livestream konnte nie starten.

CREATE OR REPLACE FUNCTION public.notify_on_live_room_start() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE _u record; _name text;
BEGIN
  IF NEW.status <> 'live' OR NEW.conversation_id IS NULL THEN RETURN NEW; END IF;
  SELECT COALESCE(name, 'Jemand') INTO _name FROM profiles WHERE id = NEW.host_id;
  FOR _u IN
    SELECT DISTINCT sender_id AS user_id FROM messages
    WHERE conversation_id = NEW.conversation_id AND sender_id <> NEW.host_id
    LIMIT 200
  LOOP
    PERFORM notify_user(_u.user_id, 'live_room',
      'Livestream gestartet',
      _name || ' streamt jetzt im Kanal.',
      '/dashboard/messages/' || NEW.conversation_id, 'social', 'normal',
      NEW.host_id, jsonb_build_object('room_name', NEW.room_name));
  END LOOP;
  RETURN NEW;
END;
$$;
