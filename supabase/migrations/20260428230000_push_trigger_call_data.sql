-- ═══════════════════════════════════════════════════════════════════════════
-- Push Trigger Update: pass notification type + metadata to send-push
--
-- The send-push edge function needs to know if a notification is an
-- 'incoming_call' so it can send high-priority FCM with the calls channel.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.notify_push_on_new_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  _url    TEXT;
  _anon   TEXT;
  _secret TEXT;
BEGIN
  IF NEW.read = true OR NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  _url    := current_setting('app.settings.supabase_url',       true);
  _anon   := current_setting('app.settings.supabase_anon_key',  true);
  _secret := current_setting('app.settings.push_webhook_secret', true);

  IF _url IS NULL OR _url = '' OR _anon IS NULL OR _anon = '' THEN
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
    RAISE LOG 'push notification trigger failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;
