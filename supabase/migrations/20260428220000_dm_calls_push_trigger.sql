-- ═══════════════════════════════════════════════════════════════════════════
-- DM-Calls Push-Trigger (klingelt bei der Gegenseite wie WhatsApp)
--
-- Wenn jemand einen Anruf startet (INSERT in dm_calls mit status='ringing'),
-- erzeugt dieser Trigger eine Notification für den/die Gesprächspartner →
-- existierende Push-Pipeline (trigger_push_on_notification → send-push) sendet
-- High-Priority FCM + Web Push → Klingelton + Vollbild-Screen.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.notify_on_dm_call()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_name text;
  v_caller_avatar text;
  v_call_label text;
BEGIN
  -- Nur beim Klingeln, nicht bei status-Updates
  IF NEW.status <> 'ringing' THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(name, 'Mensaena'), avatar_url
    INTO v_caller_name, v_caller_avatar
    FROM public.profiles
    WHERE id = NEW.caller_id;

  v_call_label := CASE WHEN NEW.call_type = 'video' THEN 'Videoanruf' ELSE 'Sprachanruf' END;

  -- Notification für alle Gesprächspartner außer dem Anrufer
  INSERT INTO public.notifications
    (user_id, type, category, title, content, link, actor_id, metadata)
  SELECT
    cm.user_id,
    'incoming_call',
    'message',
    v_caller_name,
    'Eingehender ' || v_call_label || '…',
    '/dashboard/chat?conv=' || NEW.conversation_id || '&call=' || NEW.id,
    NEW.caller_id,
    jsonb_build_object(
      'conversation_id', NEW.conversation_id,
      'call_id',         NEW.id,
      'call_type',       NEW.call_type,
      'room_name',       NEW.room_name,
      'caller_id',       NEW.caller_id,
      'caller_name',     v_caller_name,
      'caller_avatar',   v_caller_avatar,
      'priority',        'high'
    )
  FROM public.conversation_members cm
  WHERE cm.conversation_id = NEW.conversation_id
    AND cm.user_id <> NEW.caller_id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_on_dm_call failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_dm_call ON public.dm_calls;
CREATE TRIGGER trg_notify_on_dm_call
  AFTER INSERT ON public.dm_calls
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_dm_call();
