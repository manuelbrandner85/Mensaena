-- ═══════════════════════════════════════════════════════════════════════════
-- Self-Healing für private.push_config — die kritischen Keys garantieren
--
-- Hintergrund: Wenn supabase_url / supabase_anon_key in private.push_config
-- fehlen oder leer sind, bricht der notify_call_on_dm_calls_insert Trigger
-- still ab (RETURN NEW ohne http_post). Folge: FCM-Push wird nie gesendet,
-- der Empfänger hört bei geschlossener App NICHTS.
--
-- Diese Migration ist IDEMPOTENT und läuft bei jedem CI-Deploy. Sie schreibt
-- die Werte nur, wenn sie NULL/leer sind — bestehende Prod-Werte werden NICHT
-- überschrieben. Damit ist 'never silently misconfigured' garantiert.
-- ═══════════════════════════════════════════════════════════════════════════

INSERT INTO private.push_config (key, value) VALUES
  ('supabase_url',      'https://huaqldjkgyosefzfhjnf.supabase.co'),
  ('supabase_anon_key', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5ODcxMTgsImV4cCI6MjA5MDU2MzExOH0.Q5ciM8f--f1xAsKyr9-hv1mz7GGbJ6vbxPe4Cj5mgYE')
ON CONFLICT (key) DO UPDATE
  SET value = EXCLUDED.value
  -- Bestehende, nicht-leere Werte unangetastet lassen.
  WHERE private.push_config.value IS NULL OR private.push_config.value = '';

-- Cleanup: dm_calls die im 'ringing'-Status hängen geblieben sind länger als
-- 60 Sekunden → als 'missed' markieren. Sonst ploppen sie beim nächsten
-- App-Öffnen via Realtime-Initial-Snapshot auf (User-Bug-Report: "Anruf kommt
-- erst wenn ich die App öffne obwohl schon längst kein Anruf ist").
UPDATE public.dm_calls
   SET status = 'missed',
       ended_at = COALESCE(ended_at, NOW()),
       ended_reason = COALESCE(ended_reason, 'missed')
 WHERE status = 'ringing'
   AND created_at < NOW() - INTERVAL '60 seconds';

-- Diagnose-View: erlaubt Schnell-Check ob notify-call wirklich feuert.
-- SELECT * FROM private.last_call_attempts_v ORDER BY created_at DESC LIMIT 20;
CREATE OR REPLACE VIEW private.last_call_attempts_v AS
  SELECT id, caller_id, callee_id, status, created_at, answered_at, ended_at,
         ended_reason, EXTRACT(EPOCH FROM (NOW() - created_at)) AS age_seconds
    FROM public.dm_calls
   ORDER BY created_at DESC
   LIMIT 100;
