-- Bug-Fix: idx_dm_calls_active_conv UNIQUE-Index verhindert neue Calls
-- wenn alter ringing/active call in derselben conversation noch lebt.
-- Loesung: a) sofort orphans cleanen, b) pg_cron-Job alle 1min der
-- ringing > 45s als 'missed' setzt und active > 6h als 'ended'.

UPDATE dm_calls SET status = 'missed', ended_at = NOW()
WHERE status = 'ringing' AND created_at < NOW() - INTERVAL '45 seconds';
UPDATE dm_calls SET status = 'ended', ended_at = NOW()
WHERE status = 'active' AND created_at < NOW() - INTERVAL '6 hours';

CREATE OR REPLACE FUNCTION public.cleanup_stale_dm_calls()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE dm_calls SET status = 'missed', ended_at = NOW()
  WHERE status = 'ringing' AND created_at < NOW() - INTERVAL '45 seconds';
  UPDATE dm_calls SET status = 'ended', ended_at = NOW()
  WHERE status = 'active' AND created_at < NOW() - INTERVAL '6 hours';
END;
$$;

SELECT cron.unschedule('cleanup_stale_dm_calls')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup_stale_dm_calls');

SELECT cron.schedule(
  'cleanup_stale_dm_calls',
  '* * * * *',
  $$SELECT public.cleanup_stale_dm_calls();$$
);
