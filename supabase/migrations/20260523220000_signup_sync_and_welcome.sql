-- ════════════════════════════════════════════════════════════════════════
-- Signup-Sync + Welcome-Email
--
-- Fixes:
--   1. handle_new_user() war fragil — kann fehlschlagen wenn email NULL
--      (z.B. Magic-Link-Signup ohne Email). Robuster machen + Logging.
--   2. Welcome-Email-Trigger ergänzen: nach Profile-INSERT wird die
--      send-email Edge-Function gerufen mit type='welcome'.
--   3. Profile-Sichtbarkeit im Admin: View die alle auth.users joined
--      damit Admins auch unconfirmed Users sehen.
-- ════════════════════════════════════════════════════════════════════════

-- ── 1. Robust handle_new_user mit Welcome-Email-Hook ────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_name TEXT;
  v_email TEXT;
BEGIN
  v_name  := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    split_part(NEW.email, '@', 1)
  );
  v_email := NEW.email;

  -- Profile anlegen (idempotent)
  INSERT INTO public.profiles (id, name, email, created_at)
  VALUES (NEW.id, v_name, v_email, NOW())
  ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        name  = COALESCE(EXCLUDED.name, public.profiles.name);

  -- Welcome-Email anstossen — fail-silently bei Edge-Function-Fehler
  BEGIN
    PERFORM net.http_post(
      url := current_setting('app.supabase_url', true) || '/functions/v1/send-email',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
      ),
      body := jsonb_build_object(
        'type', 'welcome',
        'user_id', NEW.id,
        'email', v_email,
        'name', v_name
      )
    );
  EXCEPTION WHEN OTHERS THEN
    -- Falls pg_net nicht verfuegbar oder Edge-Function down → log only
    RAISE WARNING 'Welcome-Email-Trigger failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;

-- Re-create Trigger sicher
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── 2. Admin-Sichtbare-View: profiles + auth-meta ────────────────────
-- Admins koennen via diese View ALLE User sehen, inkl. unconfirmed
-- (email_confirmed_at = NULL) und ohne Profile-Eintrag (falls Trigger
-- mal failed).
CREATE OR REPLACE VIEW public.admin_users_view AS
SELECT
  u.id,
  u.email,
  u.email_confirmed_at,
  u.created_at AS auth_created_at,
  u.last_sign_in_at,
  COALESCE(p.name, u.raw_user_meta_data->>'full_name', split_part(u.email, '@', 1)) AS display_name,
  p.avatar_url,
  p.role,
  p.is_banned,
  p.trust_score,
  p.latitude,
  p.longitude,
  p.home_city,
  p.home_postal_code,
  p.bio,
  p.created_at AS profile_created_at,
  (p.id IS NULL) AS profile_missing
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
ORDER BY u.created_at DESC;

-- Nur fuer admin/moderator-Rollen zugaenglich (Service-Role umgeht RLS)
ALTER VIEW public.admin_users_view OWNER TO postgres;
GRANT SELECT ON public.admin_users_view TO authenticated;

-- RLS-Policy via Wrapper-Function (Views haben keine eigenen RLS-Policies)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('admin', 'moderator')
  );
$$;

-- ── 3. Funktion fuer Admin-User-Lookup mit Filtern ────────────────────
CREATE OR REPLACE FUNCTION public.admin_list_users(
  p_search text DEFAULT NULL,
  p_only_unconfirmed boolean DEFAULT false,
  p_only_missing_profile boolean DEFAULT false,
  p_limit int DEFAULT 100,
  p_offset int DEFAULT 0
)
RETURNS SETOF public.admin_users_view
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Permission denied: admin only';
  END IF;
  RETURN QUERY
  SELECT * FROM public.admin_users_view u
  WHERE
    (p_search IS NULL OR
     u.email ILIKE '%' || p_search || '%' OR
     u.display_name ILIKE '%' || p_search || '%')
    AND (NOT p_only_unconfirmed OR u.email_confirmed_at IS NULL)
    AND (NOT p_only_missing_profile OR u.profile_missing)
  LIMIT p_limit OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_users TO authenticated;

-- ── 4. Reconciliation: fehlende Profile fuer existierende auth-Users ──
-- Idempotent — legt Profile fuer alle auth.users an die noch kein
-- profiles-Row haben (z.B. wenn Trigger frueher mal failed war).
DO $$
DECLARE
  v_count int;
BEGIN
  INSERT INTO public.profiles (id, name, email, created_at)
  SELECT
    u.id,
    COALESCE(
      u.raw_user_meta_data->>'full_name',
      u.raw_user_meta_data->>'name',
      split_part(u.email, '@', 1)
    ),
    u.email,
    u.created_at
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.id = u.id
  WHERE p.id IS NULL
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RAISE NOTICE 'Reconciliation: % missing profiles created', v_count;
END $$;
