-- ═══════════════════════════════════════════════════════════════════════════
-- KRITISCHER FIX: Eingehende Anrufe kamen bei GESCHLOSSENER App nie an.
--
-- Ursache: Der notify-call-Trigger (20260524131000) liest supabase_url +
-- supabase_anon_key NUR aus private.push_config und bricht still ab, wenn
-- einer NULL ist (RETURN NEW ohne http_post). Diese beiden Keys wurden aber
-- NIE in push_config eingetragen — weder per Migration noch per CI. Anders
-- als der reguläre Push-Trigger (20260428240000) hatte notify-call KEINEN
-- current_setting()-Fallback → der FCM-Call-Push wurde nie versendet →
-- der Empfänger bekam bei geschlossener/gesperrter App keinen Anruf-Screen.
--
-- Fix in zwei Teilen:
--   1. supabase_url + supabase_anon_key idempotent in push_config seeden
--      (anon key ist absichtlich öffentlich, durch RLS gesichert).
--   2. notify-call-Trigger mit demselben robusten Config-Resolving wie der
--      Notification-Trigger ausstatten (push_config → current_setting-Fallback).
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Config-Keys seeden (self-healing: ON CONFLICT DO UPDATE) ────────────
INSERT INTO private.push_config (key, value) VALUES
  ('supabase_url',      'https://gyqujitkvymlmgroovch.supabase.co'),
  ('supabase_anon_key', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5cXVqaXRrdnltbG1ncm9vdmNoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2NzgwNzMsImV4cCI6MjA5NjI1NDA3M30.hz7uZJJPffFb5DEXKHVtmVaW5d4YzXFE2WtSROwjFxg')
ON CONFLICT (key) DO UPDATE
  SET value = EXCLUDED.value
  -- Bestehende, nicht-leere Werte NICHT überschreiben (Prod könnte abweichen).
  WHERE private.push_config.value IS NULL OR private.push_config.value = '';

-- ── 2. notify-call-Trigger mit robustem Config-Resolving + Fallback ────────
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

  -- Fallback auf current_setting() falls Config-Table leer (Dev-DB).
  IF _url IS NULL OR _url = '' THEN
    _url := current_setting('app.settings.supabase_url', true);
  END IF;
  IF _anon IS NULL OR _anon = '' THEN
    _anon := current_setting('app.settings.supabase_anon_key', true);
  END IF;

  IF _url IS NULL OR _url = '' OR _anon IS NULL OR _anon = '' THEN
    RAISE LOG 'notify_call_on_dm_calls_insert: missing config (url=%, anon set=%)',
              _url, (_anon IS NOT NULL AND _anon <> '');
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
    RAISE LOG 'notify_call_on_dm_calls_insert http_post failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_call_on_dm_calls_insert ON public.dm_calls;
CREATE TRIGGER notify_call_on_dm_calls_insert
  AFTER INSERT ON public.dm_calls
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_call_on_dm_calls_insert();
