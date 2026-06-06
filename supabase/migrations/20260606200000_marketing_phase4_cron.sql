-- ════════════════════════════════════════════════════════════════════════
-- Phase-4 Marketing-Automatik: pg_cron-Jobs (selbstlaufend)
--
-- Richtet die 5 Phase-4 Edge Functions als zeitgesteuerte Cron-Jobs ein.
-- Deployt automatisch via .github/workflows/supabase.yml (supabase db push)
-- gegen die Live-DB gyquj — KEIN manueller SQL-Editor-Schritt mehr nötig.
--
-- Auth: über den öffentlichen anon-Key aus private.push_config. Die Functions
-- sind mit `--no-verify-jwt` deployed (siehe supabase.yml), daher reicht der
-- anon-Key zum Routing; intern nutzen sie SERVICE_ROLE aus ihrer eigenen
-- Secret-Env. Der anon-Key ist absichtlich öffentlich (durch RLS gesichert).
--
-- Schutzregeln: Jede sendende Function erzwingt _shared/notify_guard.ts
-- (Notbremse marketing_paused, Opt-out je Spalte, Frequenz 1/72h & 2/7d,
-- stille Zeiten 22–8 Berlin). Die Cron-Zeiten liegen bewusst tagsüber (UTC).
--
-- DRIFT-TOLERANZ: cron + net existieren nur auf der Live-DB, nicht im frischen
-- Preview-Replay. Das Scheduling läuft daher in einem Guard, der no-op't wenn
-- das cron-Schema fehlt. Der Helper-Body ist spät-gebundenes plpgsql (net.*
-- wird erst zur Laufzeit aufgelöst) und daher unkritisch.
-- ════════════════════════════════════════════════════════════════════════

-- Helper: ruft eine Edge Function per pg_net mit dem anon-Key aus push_config auf.
CREATE OR REPLACE FUNCTION private.invoke_edge_function(fn_name text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, pg_temp
AS $fn$
DECLARE
  _url  text;
  _anon text;
BEGIN
  SELECT value INTO _url  FROM private.push_config WHERE key = 'supabase_url';
  SELECT value INTO _anon FROM private.push_config WHERE key = 'supabase_anon_key';
  IF _url IS NULL OR _url = '' OR _anon IS NULL OR _anon = '' THEN
    RAISE LOG 'invoke_edge_function(%): supabase_url/anon fehlt in push_config', fn_name;
    RETURN;
  END IF;
  BEGIN
    PERFORM net.http_post(
      url     := _url || '/functions/v1/' || fn_name,
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || _anon,
        'apikey',        _anon
      ),
      body    := '{}'::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'invoke_edge_function(%) http_post fehlgeschlagen: %', fn_name, SQLERRM;
  END;
END;
$fn$;

-- Cron-Jobs nur anlegen, wenn pg_cron auf dieser DB vorhanden ist
-- (Live gyquj = ja, frischer Preview-Replay = nein → sauberes no-op).
-- cron.schedule(name, ...) ist idempotent: gleicher Jobname wird aktualisiert.
DO $cron$
BEGIN
  IF to_regnamespace('cron') IS NULL THEN
    RAISE NOTICE 'pg_cron nicht vorhanden — überspringe Marketing-Cron-Setup.';
    RETURN;
  END IF;

  -- auto-social-content: wöchentlich Mo 08:00 UTC
  PERFORM cron.schedule('auto-social-content', '0 8 * * 1',
    $job$select private.invoke_edge_function('auto-social-content')$job$);

  -- auto-health-report: wöchentlich Mo 07:00 UTC
  PERFORM cron.schedule('auto-health-report', '0 7 * * 1',
    $job$select private.invoke_edge_function('auto-health-report')$job$);

  -- auto-smart-timing: wöchentlich So 23:00 UTC (reine Analyse, kein Versand)
  PERFORM cron.schedule('auto-smart-timing', '0 23 * * 0',
    $job$select private.invoke_edge_function('auto-smart-timing')$job$);

  -- feedback-after-help: täglich 16:00 UTC
  PERFORM cron.schedule('feedback-after-help', '0 16 * * *',
    $job$select private.invoke_edge_function('feedback-after-help')$job$);

  -- auto-winback: wöchentlich Mi 15:00 UTC
  PERFORM cron.schedule('auto-winback', '0 15 * * 3',
    $job$select private.invoke_edge_function('auto-winback')$job$);

  RAISE NOTICE 'Marketing-Phase-4 Cron-Jobs eingerichtet (5 Jobs).';
END
$cron$;
