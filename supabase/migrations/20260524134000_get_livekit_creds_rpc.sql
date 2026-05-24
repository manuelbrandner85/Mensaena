-- get_livekit_creds() RPC — von der livekit-token Edge Function via
-- service_role aufgerufen. Liest die 3 LiveKit-Keys aus private.push_config
-- (REST API exposed nur 'public' Schema → direkter Zugriff aus Edge
-- Function ist nicht möglich). SECURITY DEFINER + nur service_role-Grant
-- verhindert Leakage an User-Clients.

CREATE OR REPLACE FUNCTION public.get_livekit_creds()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, pg_temp
AS $$
DECLARE
  _url text;
  _key text;
  _secret text;
BEGIN
  SELECT value INTO _url    FROM private.push_config WHERE key = 'livekit_self_url';
  SELECT value INTO _key    FROM private.push_config WHERE key = 'livekit_self_key';
  SELECT value INTO _secret FROM private.push_config WHERE key = 'livekit_self_secret';
  RETURN jsonb_build_object('url', _url, 'key', _key, 'secret', _secret);
END $$;

REVOKE ALL ON FUNCTION public.get_livekit_creds() FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_livekit_creds() TO service_role;
