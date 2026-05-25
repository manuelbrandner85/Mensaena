-- Admin-Audit-Log: zeichnet jede Admin-Aktion (Ban/Delete/Role-Change/etc)
-- mit Actor, Target, Action und JSONB-Details auf. Read-Only fuer Audit.

CREATE TABLE IF NOT EXISTS public.admin_audit_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  actor_id    uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  target_id   uuid REFERENCES profiles(id) ON DELETE SET NULL,
  action      text NOT NULL,           -- 'ban', 'unban', 'delete', 'role_change', 'cleanup', ...
  table_name  text,                    -- z.B. 'profiles', 'posts'
  details     jsonb DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS admin_audit_log_actor_idx
  ON public.admin_audit_log (actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS admin_audit_log_target_idx
  ON public.admin_audit_log (target_id, created_at DESC);

-- RLS: nur Admins lesen, niemand updated/deleted.
ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_audit_log_select ON public.admin_audit_log;
CREATE POLICY admin_audit_log_select ON public.admin_audit_log
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
              AND profiles.role IN ('admin', 'moderator'))
  );

-- INSERT geht NUR via SECURITY DEFINER RPC, niemand direkt.
-- (kein INSERT-Policy → blockt alle direct-Inserts auf authenticated)

CREATE OR REPLACE FUNCTION public.log_admin_action(
  p_action text,
  p_target_id uuid DEFAULT NULL,
  p_table_name text DEFAULT NULL,
  p_details jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role text;
  log_id uuid;
BEGIN
  SELECT role INTO caller_role FROM profiles WHERE id = auth.uid();
  IF caller_role NOT IN ('admin', 'moderator') THEN
    RAISE EXCEPTION 'log_admin_action only callable by admin/moderator'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  INSERT INTO admin_audit_log (actor_id, target_id, action, table_name, details)
  VALUES (auth.uid(), p_target_id, p_action, p_table_name, COALESCE(p_details, '{}'::jsonb))
  RETURNING id INTO log_id;

  RETURN log_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_admin_action(text, uuid, text, jsonb) TO authenticated;
