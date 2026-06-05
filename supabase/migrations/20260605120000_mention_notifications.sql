-- ═══════════════════════════════════════════════════════════════════════════
-- @-Mention-Benachrichtigungen
--
-- Bisher benachrichtigte notify_on_new_message() jedes Konversations-Mitglied
-- über jede Nachricht (mit 5-Min-Rate-Limit). Wer aber in einem aktiven
-- Gespräch / großen Channel @-erwähnt wurde, ging im Rate-Limit unter oder
-- bekam dieselbe generische 'message'-Notification wie bei jeder anderen
-- Nachricht — kein Signal "DU bist gemeint".
--
-- NEU: Wird ein Mitglied per "@<Anzeigename>" erwähnt, bekommt es eine
-- eigene 'mention'-Notification (eigener Client-Style existiert bereits:
-- notification_service.dart 'mention'). Diese:
--   • umgeht das Message-Rate-Limit (Mention ist wichtiger),
--   • ersetzt für das erwähnte Mitglied die generische message-Notif
--     (kein Doppel),
--   • läuft über dieselbe notifications→FCM-Pipeline → funktioniert auch
--     bei geschlossener App (robuster als ein reiner Client-Realtime-Ansatz).
--
-- Mention-Matching: '@' + Anzeigename, gefolgt von Wortende/Nicht-Wort.
-- Verhindert "@Al" matcht "@Albert" (False-Positive). Sonderzeichen im
-- Namen werden für die Regex escaped. Leichtes 2-Min-Dedupe gegen @-Spam.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. 'mention' als gültigen notifications.type erlauben.
--
-- WICHTIG: Der Constraint wird DYNAMISCH gebaut — aus allen bereits in der
-- Tabelle vorhandenen type-Werten PLUS der bekannten Liste PLUS 'mention'.
-- Eine hartkodierte Liste schlug fehl (SQLSTATE 23514: bestehende Zeilen
-- enthielten type-Werte, die nicht in der Liste standen — z.B. aus späteren
-- Migrationen oder Altdaten). So kann KEINE existierende Zeile den neuen
-- Constraint verletzen, und 'mention' ist garantiert erlaubt.
DO $mention_constraint$
DECLARE
  v_types text;
BEGIN
  SELECT string_agg(DISTINCT quote_literal(t), ', ')
  INTO v_types
  FROM (
    SELECT type AS t FROM public.notifications WHERE type IS NOT NULL
    UNION
    SELECT unnest(ARRAY[
      'message','interaction','post_update','system','help_found',
      'crisis_alert','new_match','match_both_accepted','match_partner_accepted',
      'interaction_created','post_nearby','comment','rating','incoming_call',
      'live_room_started','mention'
    ])
  ) s;

  EXECUTE 'ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check';
  EXECUTE 'ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check '
       || 'CHECK (type = ANY (ARRAY[' || v_types || ']::text[]))';
END
$mention_constraint$;

-- 2. Hilfsfunktionen ZUERST definieren (vor dem Trigger, der sie aufruft).

-- Enthält [content] eine @-Erwähnung des [target_user]?
-- '@' + Anzeigename + Wortende. Name wird für die POSIX-Regex escaped.
CREATE OR REPLACE FUNCTION public._message_mentions(
  p_content text,
  p_target_user uuid
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name    text;
  v_escaped text;
BEGIN
  SELECT name INTO v_name FROM public.profiles WHERE id = p_target_user;
  IF v_name IS NULL OR length(trim(v_name)) = 0 THEN
    RETURN false;
  END IF;
  -- Regex-Sonderzeichen im Namen neutralisieren.
  v_escaped := regexp_replace(v_name, '([.^$|?*+()\[\]{}\\])', '\\\1', 'g');
  -- '@Name' gefolgt von Stringende ODER einem Nicht-Wort-Zeichen.
  -- Verhindert dass "@Al" in "@Albert" matcht.
  RETURN p_content ~* ('@' || v_escaped || '($|[^[:alnum:]_])');
END;
$$;

-- mention-Notification einfügen (mit 2-Min-Dedupe gegen @-Spam).
CREATE OR REPLACE FUNCTION public._insert_mention_notif(
  p_user uuid,
  p_sender_name text,
  p_preview text,
  p_conversation uuid,
  p_message uuid,
  p_actor uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.notifications
    WHERE user_id  = p_user
      AND type     = 'mention'
      AND read     = false
      AND metadata->>'conversation_id' = p_conversation::text
      AND actor_id = p_actor
      AND created_at > NOW() - INTERVAL '2 minutes'
  ) THEN
    UPDATE public.notifications
    SET content = p_preview, created_at = NOW(),
        metadata = jsonb_build_object('conversation_id', p_conversation, 'message_id', p_message)
    WHERE user_id  = p_user
      AND type     = 'mention'
      AND read     = false
      AND metadata->>'conversation_id' = p_conversation::text
      AND actor_id = p_actor
      AND created_at > NOW() - INTERVAL '2 minutes';
  ELSE
    INSERT INTO public.notifications
      (user_id, type, category, title, content, link, actor_id, metadata)
    VALUES (
      p_user, 'mention', 'mention', p_sender_name, p_preview,
      '/dashboard/messages', p_actor,
      jsonb_build_object('conversation_id', p_conversation, 'message_id', p_message)
    );
  END IF;
END;
$$;

-- 3. notify_on_new_message() um Mention-Erkennung erweitern.
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

  -- ── Direkt-1:1 mit explizit gesetztem receiver_id ──────────────────────
  IF NEW.receiver_id IS NOT NULL AND NEW.receiver_id <> NEW.sender_id THEN
    -- Erwähnung des Empfängers? (im 1:1 selten, aber möglich)
    IF public._message_mentions(NEW.content, NEW.receiver_id) THEN
      PERFORM public._insert_mention_notif(
        NEW.receiver_id, v_sender_name, v_preview,
        NEW.conversation_id, NEW.id, NEW.sender_id);
      RETURN NEW;
    END IF;

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

  -- ── Gruppen-/Konversations-Fall ────────────────────────────────────────
  FOR rec IN
    SELECT cm.user_id
    FROM public.conversation_members cm
    WHERE cm.conversation_id = NEW.conversation_id
      AND cm.user_id <> NEW.sender_id
  LOOP
    -- Erwähntes Mitglied → eigene mention-Notif (statt message), bypass
    -- Rate-Limit, eigenes 2-Min-Dedupe.
    IF public._message_mentions(NEW.content, rec.user_id) THEN
      PERFORM public._insert_mention_notif(
        rec.user_id, v_sender_name, v_preview,
        NEW.conversation_id, NEW.id, NEW.sender_id);
      CONTINUE;
    END IF;

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
