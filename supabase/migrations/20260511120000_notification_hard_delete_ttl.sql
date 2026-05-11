-- ═══════════════════════════════════════════════════════════════════════
-- Benachrichtigungen: Hard-Delete + 14-Tage TTL Auto-Cleanup
-- ═══════════════════════════════════════════════════════════════════════

-- Replica Identity FULL: notwendig damit Supabase Realtime DELETE-Events
-- korrekt mit row-level filter (user_id=eq.X) ausliefert.
ALTER TABLE notifications REPLICA IDENTITY FULL;

-- ── RPC: Einzelne Benachrichtigung dauerhaft löschen ────────────────
CREATE OR REPLACE FUNCTION delete_notification(p_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM notifications
  WHERE id = p_id AND user_id = p_user_id;
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── RPC: Alle Benachrichtigungen eines Users dauerhaft löschen ───────
CREATE OR REPLACE FUNCTION delete_all_notifications(
  p_user_id UUID,
  p_category TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  affected INTEGER;
BEGIN
  IF p_category IS NULL THEN
    DELETE FROM notifications
    WHERE user_id = p_user_id;
  ELSE
    DELETE FROM notifications
    WHERE user_id = p_user_id AND category = p_category;
  END IF;
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── pg_cron: Benachrichtigungen nach 14 Tagen auto-löschen ──────────
-- Läuft täglich um 03:00 UTC.
-- Conditional: läuft nur wenn pg_cron Extension aktiv ist (nicht auf Preview-Branches).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    PERFORM cron.schedule(
      'cleanup-old-notifications',
      '0 3 * * *',
      'DELETE FROM public.notifications WHERE created_at < NOW() - INTERVAL ''14 days'''
    );
  END IF;
END;
$$;
