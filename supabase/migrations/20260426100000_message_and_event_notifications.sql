-- ═══════════════════════════════════════════════════════════════════════════
-- N1: notify_on_new_message() verbessern – Rate-Limit gegen Notification-Spam
-- N2: Event-Erinnerungen 24h vorher (pg_cron)
--
-- HINWEIS: notify_on_new_message() und trg_notify_on_new_message existieren
-- bereits in 20260424200000_notification_triggers.sql. Diese Migration
-- ersetzt die Funktion (OR REPLACE) um Rate-Limiting hinzuzufügen und
-- registriert den pg_cron-Job für Event-Erinnerungen.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── N1: notify_on_new_message() mit Rate-Limit ────────────────────────────
-- Verhindert Notification-Spam bei aktiven Chats:
-- Wenn bereits eine ungelesene message-Notification vom selben Sender
-- im selben Gespräch innerhalb der letzten 5 Min existiert → nur updaten.

CREATE OR REPLACE FUNCTION public.notify_on_new_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_name TEXT;
  v_preview     TEXT;
  rec           RECORD;
BEGIN
  IF NEW.content IS NULL OR length(trim(NEW.content)) = 0 THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(name, 'Jemand') INTO v_sender_name
  FROM public.profiles WHERE id = NEW.sender_id;

  v_preview := substring(trim(NEW.content) FROM 1 FOR 140);
  IF length(NEW.content) > 140 THEN v_preview := v_preview || '…'; END IF;

  -- Direkt-1:1 mit explicit gesetztem receiver_id
  IF NEW.receiver_id IS NOT NULL AND NEW.receiver_id <> NEW.sender_id THEN
    -- Rate-Limit prüfen
    IF EXISTS (
      SELECT 1 FROM public.notifications
      WHERE user_id    = NEW.receiver_id
        AND type       = 'message'
        AND read       = false
        AND metadata->>'conversation_id' = NEW.conversation_id::text
        AND actor_id   = NEW.sender_id
        AND created_at > NOW() - INTERVAL '5 minutes'
    ) THEN
      UPDATE public.notifications
      SET content = v_preview, created_at = NOW()
      WHERE user_id    = NEW.receiver_id
        AND type       = 'message'
        AND read       = false
        AND metadata->>'conversation_id' = NEW.conversation_id::text
        AND actor_id   = NEW.sender_id
        AND created_at > NOW() - INTERVAL '5 minutes';
    ELSE
      INSERT INTO public.notifications
        (user_id, type, category, title, content, link, actor_id, metadata)
      VALUES (
        NEW.receiver_id, 'message', 'message', v_sender_name, v_preview,
        '/dashboard/messages', NEW.sender_id,
        jsonb_build_object('conversation_id', NEW.conversation_id, 'message_id', NEW.id)
      );
    END IF;
    RETURN NEW;
  END IF;

  -- Gruppen-/Konversations-Fall
  FOR rec IN
    SELECT cm.user_id
    FROM public.conversation_members cm
    WHERE cm.conversation_id = NEW.conversation_id
      AND cm.user_id <> NEW.sender_id
  LOOP
    IF EXISTS (
      SELECT 1 FROM public.notifications
      WHERE user_id    = rec.user_id
        AND type       = 'message'
        AND read       = false
        AND metadata->>'conversation_id' = NEW.conversation_id::text
        AND actor_id   = NEW.sender_id
        AND created_at > NOW() - INTERVAL '5 minutes'
    ) THEN
      UPDATE public.notifications
      SET content = v_preview, created_at = NOW()
      WHERE user_id    = rec.user_id
        AND type       = 'message'
        AND read       = false
        AND metadata->>'conversation_id' = NEW.conversation_id::text
        AND actor_id   = NEW.sender_id
        AND created_at > NOW() - INTERVAL '5 minutes';
    ELSE
      INSERT INTO public.notifications
        (user_id, type, category, title, content, link, actor_id, metadata)
      VALUES (
        rec.user_id, 'message', 'message', v_sender_name, v_preview,
        '/dashboard/messages', NEW.sender_id,
        jsonb_build_object('conversation_id', NEW.conversation_id, 'message_id', NEW.id)
      );
    END IF;
  END LOOP;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_on_new_message failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Trigger existiert bereits als trg_notify_on_new_message (20260424200000)
-- Kein neuer Trigger nötig – OR REPLACE der Funktion reicht.

-- ── N2: Event-Erinnerungen 24h vorher ────────────────────────────────────

CREATE OR REPLACE FUNCTION public.send_event_reminders()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  rec       RECORD;
  v_sent    integer := 0;
  v_text    TEXT;
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
    WHERE e.status   = 'upcoming'
      AND ea.status  IN ('going', 'interested')
      AND e.start_date BETWEEN NOW() + INTERVAL '22 hours'
                           AND NOW() + INTERVAL '25 hours'
  LOOP
    IF EXISTS (
      SELECT 1 FROM public.notifications
      WHERE user_id               = rec.attendee_id
        AND type                  = 'event_reminder'
        AND metadata->>'event_id' = rec.event_id::text
    ) THEN
      CONTINUE;
    END IF;

    v_text := 'morgen um ' || to_char(rec.start_date AT TIME ZONE 'Europe/Berlin', 'HH24:MI') || ' Uhr';
    IF rec.location_name IS NOT NULL THEN
      v_text := v_text || ' · ' || rec.location_name;
    END IF;

    INSERT INTO public.notifications (
      user_id, type, category, title, content, link, metadata
    ) VALUES (
      rec.attendee_id, 'event_reminder', 'reminder',
      '📅 ' || rec.title, v_text,
      '/dashboard/events/' || rec.event_id::text,
      jsonb_build_object('event_id', rec.event_id, 'start_date', rec.start_date, 'attend_status', rec.attend_status)
    );
    v_sent := v_sent + 1;
  END LOOP;

  RETURN v_sent;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'send_event_reminders: %', SQLERRM;
  RETURN v_sent;
END;
$$;

-- pg_cron Job registrieren (idempotent, mit EXCEPTION-Handler)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('mensaena-event-reminders')
      WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'mensaena-event-reminders');
    PERFORM cron.schedule(
      'mensaena-event-reminders',
      '15 * * * *',
      $cron$SELECT public.send_event_reminders();$cron$
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron nicht verfügbar – Event-Reminder muss manuell gescheduled werden: %', SQLERRM;
END $$;
