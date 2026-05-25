-- Security: schuetzt role / is_banned / ban_reason vor User-Self-Tampering.
-- RLS erlaubt UPDATE auf eigene profile-Row → ohne Trigger koennte ein User
-- per crafted DB-Call sein eigenes is_banned auf false oder role auf admin
-- setzen. Dieser Trigger blockt das wenn der Caller nicht admin/moderator ist.

CREATE OR REPLACE FUNCTION public.protect_profile_privileged_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role text;
BEGIN
  SELECT role INTO caller_role
  FROM profiles
  WHERE id = auth.uid();

  IF caller_role IN ('admin', 'moderator') THEN
    RETURN NEW;
  END IF;

  -- Service-Role (kein auth.uid) darf alles — z.B. Edge-Functions, RPC mit
  -- SECURITY DEFINER, oder direkter Admin-Zugriff via Service-Key.
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  IF OLD.role IS DISTINCT FROM NEW.role THEN
    RAISE EXCEPTION 'role can only be changed by admin/moderator'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF OLD.is_banned IS DISTINCT FROM NEW.is_banned THEN
    RAISE EXCEPTION 'is_banned can only be changed by admin/moderator'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF OLD.ban_reason IS DISTINCT FROM NEW.ban_reason THEN
    RAISE EXCEPTION 'ban_reason can only be changed by admin/moderator'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_profile_privileged_fields_trg ON public.profiles;
CREATE TRIGGER protect_profile_privileged_fields_trg
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.protect_profile_privileged_fields();
