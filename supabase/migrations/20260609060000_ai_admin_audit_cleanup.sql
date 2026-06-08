-- ════════════════════════════════════════════════════════════════════════
-- KI-Aktivität Auto-Cleanup — Admin kann manuell löschen, pg_cron räumt
-- automatisch nach 24 Stunden auf.
--
-- Neue Objekte (idempotent):
--   • delete_ai_audit_entry(uuid)  — löscht einzelnen Eintrag (admin-only)
--   • clear_ai_audit()             — löscht ALLE Einträge (admin-only)
--   • pg_cron-Job "ai_audit_24h_cleanup" — läuft täglich 00:30 UTC
-- ════════════════════════════════════════════════════════════════════════

-- ── Einzelnen Audit-Eintrag löschen (admin-only SECURITY DEFINER) ─────────
CREATE OR REPLACE FUNCTION public.delete_ai_audit_entry(p_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role text;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  IF caller_role <> 'admin' THEN
    RAISE EXCEPTION 'delete_ai_audit_entry: admin only'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  DELETE FROM public.ai_admin_audit WHERE id = p_id;
  RETURN FOUND;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_ai_audit_entry(uuid) TO authenticated;

-- ── Alle Audit-Einträge löschen (admin-only SECURITY DEFINER) ────────────
CREATE OR REPLACE FUNCTION public.clear_ai_audit()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role text;
  deleted_count int;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  IF caller_role <> 'admin' THEN
    RAISE EXCEPTION 'clear_ai_audit: admin only'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  DELETE FROM public.ai_admin_audit;
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.clear_ai_audit() TO authenticated;

-- ── pg_cron: täglich 00:30 UTC — Einträge älter als 24 Stunden löschen ──
-- cron.schedule() kennt KEIN "ON CONFLICT". Idempotenz daher über vorheriges
-- unschedule (Fehler ignoriert, falls der Job noch nicht existiert).
DO $$
BEGIN
  PERFORM cron.unschedule('ai_audit_24h_cleanup');
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

SELECT cron.schedule(
  'ai_audit_24h_cleanup',
  '30 0 * * *',
  'DELETE FROM public.ai_admin_audit WHERE created_at < now() - interval ''24 hours'''
);
