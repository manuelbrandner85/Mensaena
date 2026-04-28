-- ═══════════════════════════════════════════════════════════════════════════
-- KRITISCHER FIX: Push-Trigger liest direkt aus private.push_config
--
-- Vorher: current_setting('app.settings.supabase_url', true) → benötigt
--   ALTER DATABASE postgres SET app.settings.supabase_url = ...
--   Diese Settings waren in der Production-DB NULL → Trigger brach silently ab
--   → KEIN FCM-Push wurde je versendet → eingehende Anrufe lösten keinen
--   Anruf-Screen aus, weil der Empfänger keinen Push bekam.
--
-- Nachher: SELECT direkt aus private.push_config – kein DB-Setting nötig.
-- Diese Werte werden bereits durch 20260425200000_push_config_and_fixes.sql
-- gepflegt und sind in Production gesetzt.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.notify_push_on_new_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, extensions
AS $$
DECLARE
  _url    TEXT;
  _anon   TEXT;
  _secret TEXT;
BEGIN
  IF NEW.read = true OR NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Werte direkt aus private.push_config lesen (überlebt DB-Resets)
  SELECT value INTO _url    FROM private.push_config WHERE key = 'supabase_url';
  SELECT value INTO _anon   FROM private.push_config WHERE key = 'supabase_anon_key';
  SELECT value INTO _secret FROM private.push_config WHERE key = 'push_webhook_secret';

  -- Fallback auf alte current_setting() falls Config-Table leer (Dev-DB)
  IF _url IS NULL OR _url = '' THEN
    _url := current_setting('app.settings.supabase_url', true);
  END IF;
  IF _anon IS NULL OR _anon = '' THEN
    _anon := current_setting('app.settings.supabase_anon_key', true);
  END IF;
  IF _secret IS NULL OR _secret = '' THEN
    _secret := current_setting('app.settings.push_webhook_secret', true);
  END IF;

  IF _url IS NULL OR _url = '' OR _anon IS NULL OR _anon = '' THEN
    RAISE LOG 'notify_push_on_new_notification: missing config (url=%, anon set=%)',
              _url, (_anon IS NOT NULL AND _anon <> '');
    RETURN NEW;
  END IF;

  BEGIN
    PERFORM net.http_post(
      url     := _url || '/functions/v1/send-push',
      headers := jsonb_build_object(
        'Content-Type',      'application/json',
        'Authorization',     'Bearer ' || _anon,
        'apikey',            _anon,
        'X-Webhook-Secret',  COALESCE(_secret, '')
      ),
      body    := jsonb_build_object(
        'user_id',  NEW.user_id,
        'title',    COALESCE(NEW.title, 'Mensaena'),
        'body',     COALESCE(NEW.content, ''),
        'url',      COALESCE(NEW.link, '/dashboard/notifications'),
        'tag',      'notification-' || NEW.id::text,
        'type',     NEW.type,
        'metadata', NEW.metadata
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'notify_push_on_new_notification http_post failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;

-- Trigger nochmal recreate für sicheren Sitz
DROP TRIGGER IF EXISTS trigger_push_on_notification ON public.notifications;
CREATE TRIGGER trigger_push_on_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_push_on_new_notification();
