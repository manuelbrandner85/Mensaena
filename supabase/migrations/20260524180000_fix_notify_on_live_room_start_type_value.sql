-- Fix: Trigger notify_on_live_room_start nutzte type='live_room' aber das
-- check constraint notifications_type_check erlaubt nur 'live_room_started'.
-- → Livestream-Start in Channels mit Vor-Membern schlug fehl mit
--   "violates check constraint notifications_type_check" (23514).
-- Krisen-Notfall war zufaellig der einzige Channel ohne Vor-Member-Nachrichten,
-- daher lief der Trigger-Loop dort nicht hinein → schien zu funktionieren.

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
    PERFORM notify_user(_u.user_id, 'live_room_started',
      'Livestream gestartet',
      _name || ' streamt jetzt im Kanal.',
      '/dashboard/messages/' || NEW.conversation_id, 'social', 'normal',
      NEW.host_id, jsonb_build_object('room_name', NEW.room_name));
  END LOOP;
  RETURN NEW;
END;
$$;
