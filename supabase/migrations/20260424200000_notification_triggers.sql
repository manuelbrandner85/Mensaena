-- ═══════════════════════════════════════════════════════════════════════════
-- NOTIFICATION-TRIGGER-ERWEITERUNG
--
-- Schließt die kritischen Lücken im Push-System. Bisher fehlten:
--   1. Neue Direktnachricht (messages-Tabelle)
--   2. Neue Bewertung erhalten (trust_ratings-Tabelle)
--   3. Hinzufügung zu einer Gruppe (group_members-Tabelle)
--   4. Ablaufender Match-Vorschlag (matches-Tabelle, via pg_cron)
--
-- Alle diese Events resultieren jetzt in einem INSERT in `notifications` →
-- bestehender Trigger `trigger_push_on_notification` → Edge Function `send-push`
-- → Web Push + FCM → Handy-Push auch bei geschlossener App.
-- ═══════════════════════════════════════════════════════════════════════════


-- ── 1. MESSAGES ─────────────────────────────────────────────────────────
-- Trigger: Neue Nachricht → Notification für Empfänger

CREATE OR REPLACE FUNCTION public.notify_on_new_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_name text;
  v_preview     text;
BEGIN
  IF NEW.content IS NULL OR length(trim(NEW.content)) = 0 THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(name, 'Mensaena')
    INTO v_sender_name
    FROM public.profiles
    WHERE id = NEW.sender_id;

  v_preview := substring(trim(NEW.content) FROM 1 FOR 140);
  IF length(NEW.content) > 140 THEN
    v_preview := v_preview || '…';
  END IF;

  -- Direkt-1:1 mit explicit gesetztem receiver_id
  IF NEW.receiver_id IS NOT NULL AND NEW.receiver_id <> NEW.sender_id THEN
    INSERT INTO public.notifications
      (user_id, type, category, title, content, link, actor_id, metadata)
    VALUES (
      NEW.receiver_id, 'message', 'message', v_sender_name, v_preview,
      '/dashboard/messages', NEW.sender_id,
      jsonb_build_object('conversation_id', NEW.conversation_id, 'message_id', NEW.id)
    );
    RETURN NEW;
  END IF;

  -- Gruppen-/Konversations-Fall: alle conversation_members außer Sender benachrichtigen
  INSERT INTO public.notifications
    (user_id, type, category, title, content, link, actor_id, metadata)
  SELECT
    cm.user_id, 'message', 'message', v_sender_name, v_preview,
    '/dashboard/messages', NEW.sender_id,
    jsonb_build_object('conversation_id', NEW.conversation_id, 'message_id', NEW.id)
  FROM public.conversation_members cm
  WHERE cm.conversation_id = NEW.conversation_id
    AND cm.user_id <> NEW.sender_id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Nie die message-Erstellung durch Notification-Fehler blockieren
  RAISE WARNING 'notify_on_new_message failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_new_message ON public.messages;
CREATE TRIGGER trg_notify_on_new_message
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_new_message();


-- ── 2. TRUST RATINGS ────────────────────────────────────────────────────
-- Trigger: Neue Bewertung → Notification für Bewerteten

CREATE OR REPLACE FUNCTION public.notify_on_new_trust_rating()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rater_name text;
  v_stars      text;
BEGIN
  IF NEW.rated_id IS NULL OR NEW.rated_id = NEW.rater_id THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(name, 'Jemand')
    INTO v_rater_name
    FROM public.profiles
    WHERE id = NEW.rater_id;

  v_stars := repeat('⭐', GREATEST(1, LEAST(5, NEW.score::int)));

  INSERT INTO public.notifications
    (user_id, type, category, title, content, link, actor_id, metadata)
  VALUES (
    NEW.rated_id,
    'system',
    'trust_rating',
    'Neue Bewertung ' || v_stars,
    v_rater_name || ' hat dich mit '
      || NEW.score::int::text || ' von 5 Sternen bewertet'
      || CASE WHEN NEW.comment IS NOT NULL AND length(trim(NEW.comment)) > 0
              THEN ': "' || substring(trim(NEW.comment) FROM 1 FOR 100) || '"'
              ELSE ''
         END,
    '/dashboard/profile',
    NEW.rater_id,
    jsonb_build_object(
      'rating_id', NEW.id,
      'score', NEW.score
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_on_new_trust_rating failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_new_trust_rating ON public.trust_ratings;
CREATE TRIGGER trg_notify_on_new_trust_rating
  AFTER INSERT ON public.trust_ratings
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_new_trust_rating();


-- ── 3. GROUP MEMBERSHIP ─────────────────────────────────────────────────
-- Trigger: User wird zu Gruppe hinzugefügt → Notification
-- Hinweis: Wir notifien nur wenn die Mitgliedschaft NICHT vom User selbst
-- erstellt wurde (kein "du bist gerade einer Gruppe beigetreten"-Ping).
-- Da group_members kein added_by-Feld hat, nutzen wir einen Fallback-
-- Mechanismus: wir schreiben die Notification immer – sie kommt dem User
-- als "Willkommen bei Gruppe X" vor. Das ist weniger elegant, aber besser
-- als gar keine Benachrichtigung bei Einladungen.

CREATE OR REPLACE FUNCTION public.notify_on_group_membership()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group_name text;
BEGIN
  IF NEW.user_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Gruppentitel holen – wenn Tabelle nicht existiert, graceful skip
  BEGIN
    SELECT COALESCE(name, title, 'eine Gruppe')
      INTO v_group_name
      FROM public.groups
      WHERE id = NEW.group_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN
    v_group_name := 'eine Gruppe';
  END;

  INSERT INTO public.notifications
    (user_id, type, category, title, content, link, metadata)
  VALUES (
    NEW.user_id,
    'system',
    'system',
    'Willkommen in ' || COALESCE(v_group_name, 'einer Gruppe'),
    'Du wurdest zu einer Gruppe hinzugefügt.',
    '/dashboard/groups',
    jsonb_build_object('group_id', NEW.group_id)
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_on_group_membership failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Idempotent: nur anlegen wenn group_members existiert
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'group_members'
  ) THEN
    DROP TRIGGER IF EXISTS trg_notify_on_group_membership ON public.group_members;
    CREATE TRIGGER trg_notify_on_group_membership
      AFTER INSERT ON public.group_members
      FOR EACH ROW
      EXECUTE FUNCTION public.notify_on_group_membership();
  END IF;
END $$;


-- ── 4. MATCH EXPIRY REMINDER (pg_cron) ──────────────────────────────────
-- Stündlicher Job: findet matches die in <24h ablaufen, schickt Erinnerung
-- an beide Beteiligten (einmalig – via metadata->reminder_sent Flag).

CREATE OR REPLACE FUNCTION public.notify_match_expiry_reminders()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  v_count integer := 0;
BEGIN
  FOR r IN
    SELECT m.id, m.offer_user_id, m.request_user_id, m.expires_at,
           p_offer.title AS offer_title
    FROM public.matches m
    LEFT JOIN public.posts p_offer ON p_offer.id = m.offer_post_id
    WHERE m.status IN ('suggested', 'pending')
      AND m.expires_at IS NOT NULL
      AND m.expires_at > now()
      AND m.expires_at < now() + interval '24 hours'
      AND NOT (COALESCE(m.metadata, '{}'::jsonb) ? 'reminder_sent')
  LOOP
    -- Erinnerung an beide Seiten
    INSERT INTO public.notifications
      (user_id, type, category, title, content, link, metadata)
    SELECT
      uid,
      'interaction',
      'interaction',
      'Match läuft bald ab',
      'Dein Match ' ||
        CASE WHEN r.offer_title IS NOT NULL THEN 'für "' || LEFT(r.offer_title, 40) || '" ' ELSE '' END ||
        'läuft in den nächsten 24 Stunden ab.',
      '/dashboard/matching',
      jsonb_build_object('match_id', r.id, 'kind', 'expiry_reminder')
    FROM (VALUES (r.offer_user_id), (r.request_user_id)) AS t(uid)
    WHERE uid IS NOT NULL;

    -- Flag setzen damit nicht doppelt gemahnt wird
    UPDATE public.matches
      SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('reminder_sent', true)
      WHERE id = r.id;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

-- pg_cron-Scheduled-Job registrieren, falls die Extension verfügbar ist.
-- Wenn pg_cron nicht installiert ist (selten in Supabase): manueller Aufruf
-- via `SELECT notify_match_expiry_reminders();` oder per Edge Function-Cron.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Alte Schedule entfernen (idempotent)
    PERFORM cron.unschedule('mensaena_match_expiry_reminders')
      WHERE EXISTS (
        SELECT 1 FROM cron.job
        WHERE jobname = 'mensaena_match_expiry_reminders'
      );
    -- Stündlich: prüft matches die in <24h ablaufen
    PERFORM cron.schedule(
      'mensaena_match_expiry_reminders',
      '0 * * * *',
      $cron$SELECT public.notify_match_expiry_reminders();$cron$
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron nicht verfügbar – Match-Expiry-Reminder muss manuell gescheduled werden';
END $$;


-- ── Verifikation ────────────────────────────────────────────────────────
SELECT
  (SELECT count(*) FROM pg_trigger
    WHERE tgname IN (
      'trg_notify_on_new_message',
      'trg_notify_on_new_trust_rating',
      'trg_notify_on_group_membership'
    ) AND NOT tgisinternal) AS triggers_installed,
  (SELECT count(*) FROM pg_proc WHERE proname IN (
      'notify_on_new_message',
      'notify_on_new_trust_rating',
      'notify_on_group_membership',
      'notify_match_expiry_reminders'
    )) AS functions_installed;
