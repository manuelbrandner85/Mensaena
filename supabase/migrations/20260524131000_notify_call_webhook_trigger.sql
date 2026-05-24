-- ════════════════════════════════════════════════════════════════════════
-- Database Webhook → Edge Function notify-call
-- Triggert bei jedem INSERT in dm_calls mit status='ringing'.
-- Identische Pattern wie notify_push_on_new_notification.
-- ════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.notify_call_on_dm_calls_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, pg_temp
AS $$
DECLARE
  _url  text;
  _anon text;
BEGIN
  IF NEW.status <> 'ringing' THEN
    RETURN NEW;
  END IF;

  SELECT value INTO _url  FROM private.push_config WHERE key = 'supabase_url';
  SELECT value INTO _anon FROM private.push_config WHERE key = 'supabase_anon_key';

  IF _url IS NULL OR _anon IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    PERFORM net.http_post(
      url     := _url || '/functions/v1/notify-call',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || _anon,
        'apikey',        _anon
      ),
      body    := jsonb_build_object(
        'type',   'INSERT',
        'table',  'dm_calls',
        'schema', 'public',
        'record', row_to_json(NEW)
      )
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_call_on_dm_calls_insert ON public.dm_calls;
CREATE TRIGGER notify_call_on_dm_calls_insert
  AFTER INSERT ON public.dm_calls
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_call_on_dm_calls_insert();
