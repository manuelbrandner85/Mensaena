-- Fix: Admin kann Nutzer nicht sperren/löschen (Flutter-App).
--
-- Diagnose aus error_logs:
--   * "Sperren": profiles.banUser schrieb die Spalte `banned_until`, die es auf
--     profiles NICHT gab (nur banned_at/banned_by/ban_reason) → das UPDATE warf
--     → der App-Code verschluckte den Fehler still (catch → false).
--   * "Löschen": admin_delete_user löschte manuell aus ~18 Tabellen und
--     referenzierte dabei interactions.requester_id — diese Spalte existiert
--     nicht (interactions hat helper_id/helped_id/completed_by) → die RPC warf
--     bei JEDER Löschung. Zudem war die Tabellenliste unvollständig.

-- 1) Fehlende Spalte für temporäre Sperren (banUser setzt banned_until = now+30d).
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS banned_until timestamptz;

-- 2) admin_delete_user robust + korrekt machen. Alle Child-FKs auf profiles
--    sind ON DELETE CASCADE bzw. SET NULL (geprüft: kein RESTRICT/NO ACTION,
--    und keine SET-NULL-Spalte ist NOT NULL) → ein einziges DELETE FROM
--    profiles räumt sämtliche Kind-Daten sauber ab und bleibt zukunftssicher,
--    wenn neue Tabellen hinzukommen.
CREATE OR REPLACE FUNCTION public.admin_delete_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: only admins can delete users';
  END IF;

  -- Selbstschutz: Admin darf sich nicht selbst löschen.
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Admins cannot delete their own account';
  END IF;

  DELETE FROM public.profiles WHERE id = p_user_id;

  INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, details)
  VALUES (auth.uid(), 'delete_user', 'user', p_user_id,
          jsonb_build_object('deleted_at', now()));
END;
$function$;
