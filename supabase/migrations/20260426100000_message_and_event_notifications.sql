-- ═══════════════════════════════════════════════════════════════════════════
-- N1: Chat-Nachrichten → Notification-Zeile (persistent, mit Debounce)
-- N2: Event-Erinnerungen 24h vorher (pg_cron)
-- ═══════════════════════════════════════════════════════════════════════════

-- ── N1: Trigger für neue Chat-Nachrichten ────────────────────────────────────
-- Erzeugt eine persistente Notification-Zeile wenn eine neue Nachricht
-- eingeht. Rate-Limit: max. eine Notification pro Sender pro Gespräch alle 5min,
-- damit aktive Chats nicht Dutzende Einträge erzeugen.

CREATE OR REPLACE FUNCTION public.notify_on_new_message()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_sender_name TEXT;
  v_preview     TEXT;
  rec           RECORD;
BEGIN
  -- Sender-Name holen
  SELECT COALESCE(name, 'Jemand') INTO v_sender_name
  FROM public.profiles WHERE id = NEW.sender_id;

  -- Nachrichtenvorschau (max. 100 Zeichen)
  v_preview := substring(trim(NEW.content) FROM 1 FOR 100);
  IF length(NEW.content) > 100 THEN v_preview := v_preview || '…'; END IF;

  -- Alle Gesprächsteilnehmer (außer Sender) benachrichtigen
  FOR rec IN
    SELECT user_id
    FROM public.conversation_members
    WHERE conversation_id = NEW.conversation_id
      AND user_id != NEW.sender_id
  LOOP
    -- Rate-Limit: existiert bereits eine ungelesene Nachricht-Notification
    -- vom selben Sender in diesem Gespräch innerhalb der letzten 5 Minuten?
    IF EXISTS (
      SELECT 1 FROM public.notifications
      WHERE user_id      = rec.user_id
        AND type         = 'new_message'
        AND read         = false
        AND metadata->>'conversation_id' = NEW.conversation_id::text
        AND metadata->>'actor_id'        = NEW.sender_id::text
        AND created_at   > NOW() - INTERVAL '5 minutes'
    ) THEN
      -- Vorhandene Notification aktualisieren (Vorschau + Zeitstempel)
      UPDATE public.notifications
      SET content    = v_preview,
          created_at = NOW()
      WHERE user_id      = rec.user_id
        AND type         = 'new_message'
        AND read         = false
        AND metadata->>'conversation_id' = NEW.conversation_id::text
        AND metadata->>'actor_id'        = NEW.sender_id::text
        AND created_at   > NOW() - INTERVAL '5 minutes';
    ELSE
      INSERT INTO public.notifications (
        user_id, type, category, title, content, link, actor_id, metadata
      ) VALUES (
        rec.user_id,
        'new_message',
        'message',
        v_sender_name || ' schreibt dir',
        v_preview,
        '/dashboard/messages',
        NEW.sender_id,
        jsonb_build_object(
          'conversation_id', NEW.conversation_id,
          'message_id',      NEW.id,
          'actor_id',        NEW.sender_id
        )
      );
    END IF;
  END LOOP;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_on_new_message: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_notify_new_message ON public.messages;
CREATE TRIGGER trigger_notify_new_message
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_message();

-- ── N2: Event-Erinnerungen ────────────────────────────────────────────────────
-- Funktion: sendet Erinnerungen an alle Teilnehmer (going + interested)
-- für Events die in 22–25h starten. Wird stündlich via pg_cron aufgerufen.

CREATE OR REPLACE FUNCTION public.send_event_reminders()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  rec           RECORD;
  v_sent        integer := 0;
  v_time_text   TEXT;
BEGIN
  FOR rec IN
    SELECT
      e.id          AS event_id,
      e.title,
      e.start_date,
      e.location_name,
      ea.user_id    AS attendee_id,
      ea.status     AS attend_status
    FROM public.events         e
    JOIN public.event_attendees ea ON ea.event_id = e.id
    WHERE e.status      = 'upcoming'
      AND ea.status     IN ('going', 'interested')
      AND e.start_date  BETWEEN NOW() + INTERVAL '22 hours'
                            AND NOW() + INTERVAL '25 hours'
  LOOP
    -- Doppel-Versand verhindern
    IF EXISTS (
      SELECT 1 FROM public.notifications
      WHERE user_id              = rec.attendee_id
        AND type                 = 'event_reminder'
        AND metadata->>'event_id' = rec.event_id::text
    ) THEN
      CONTINUE;
    END IF;

    -- Zeittext (morgen um HH:MM)
    v_time_text := 'morgen um ' || to_char(rec.start_date AT TIME ZONE 'Europe/Berlin', 'HH24:MI') || ' Uhr';
    IF rec.location_name IS NOT NULL THEN
      v_time_text := v_time_text || ' · ' || rec.location_name;
    END IF;

    INSERT INTO public.notifications (
      user_id, type, category, title, content, link, metadata
    ) VALUES (
      rec.attendee_id,
      'event_reminder',
      'reminder',
      '📅 ' || rec.title,
      v_time_text,
      '/dashboard/events/' || rec.event_id::text,
      jsonb_build_object(
        'event_id',    rec.event_id,
        'start_date',  rec.start_date,
        'attend_status', rec.attend_status
      )
    );

    v_sent := v_sent + 1;
  END LOOP;

  RETURN v_sent;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'send_event_reminders: %', SQLERRM;
  RETURN v_sent;
END;
$$;

-- pg_cron: stündlich prüfen (Supabase unterstützt pg_cron nativ)
-- Falls pg_cron nicht verfügbar: kann auch via Supabase Edge Function Cron ausgelöst werden
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Job falls schon vorhanden aktualisieren
    PERFORM cron.unschedule('mensaena-event-reminders');
    PERFORM cron.schedule(
      'mensaena-event-reminders',
      '15 * * * *',   -- jede Stunde um :15
      'SELECT public.send_event_reminders()'
    );
  END IF;
END $$;
