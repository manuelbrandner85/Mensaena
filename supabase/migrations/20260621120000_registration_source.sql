-- ════════════════════════════════════════════════════════════════════════
-- Registrierungsquelle (Web vs. App) + "nachträglich in App"
--
-- Ziel (Admin-Wunsch): Im Admin-Dashboard sehen, wer sich über Web bzw. über
-- die App registriert hat — und wer (Web-Registrierung) später auch die App
-- nutzt.
--
-- 1. profiles.signup_platform : 'web' | 'app' (Quelle bei Registrierung)
-- 2. profiles.app_first_seen_at : erster App-Start (NULL = nie in App)
-- 3. handle_new_user() schreibt signup_platform aus auth-Metadaten
-- 4. mark_app_seen() : von der App beim Start aufgerufen (idempotent)
-- 5. admin_users_view + 2 Spalten (admin_list_users erbt sie automatisch)
-- 6. admin_registration_source_stats() : Zähl-Übersicht fürs Dashboard
-- ════════════════════════════════════════════════════════════════════════

-- ── 1. Spalten ───────────────────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS signup_platform   TEXT,
  ADD COLUMN IF NOT EXISTS app_first_seen_at TIMESTAMPTZ;

COMMENT ON COLUMN public.profiles.signup_platform IS
  'Plattform bei Registrierung: web | app';
COMMENT ON COLUMN public.profiles.app_first_seen_at IS
  'Erster Start der nativen App (NULL = nie in der App gewesen)';

-- ── 2. handle_new_user(): signup_platform aus Metadaten übernehmen ─────
-- (identisch zur bisherigen Version, plus signup_platform/app_first_seen_at)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_name     TEXT;
  v_email    TEXT;
  v_platform TEXT;
BEGIN
  v_name  := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    split_part(NEW.email, '@', 1)
  );
  v_email := NEW.email;
  -- Web schickt 'web', die App 'app'; Default 'web' wenn nicht gesetzt.
  v_platform := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'signup_platform', ''), 'web');

  INSERT INTO public.profiles
    (id, name, email, created_at, signup_platform, app_first_seen_at)
  VALUES
    (NEW.id, v_name, v_email, NOW(), v_platform,
     CASE WHEN v_platform = 'app' THEN NOW() ELSE NULL END)
  ON CONFLICT (id) DO UPDATE
    SET email           = EXCLUDED.email,
        name            = COALESCE(EXCLUDED.name, public.profiles.name),
        signup_platform = COALESCE(public.profiles.signup_platform,
                                   EXCLUDED.signup_platform);

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
    RAISE WARNING 'Welcome-Email-Trigger failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;

-- ── 3. mark_app_seen(): App ruft dies beim Start auf ─────────────────
-- Setzt app_first_seen_at beim ersten Mal; danach idempotent (no-op).
CREATE OR REPLACE FUNCTION public.mark_app_seen()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.profiles
  SET app_first_seen_at = COALESCE(app_first_seen_at, NOW())
  WHERE id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.mark_app_seen() TO authenticated;

-- ── 4. admin_users_view um 2 Spalten erweitern (am Ende anhängen) ─────
-- admin_list_users (RETURNS SETOF admin_users_view) erbt die Spalten 1:1.
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
  (p.id IS NULL) AS profile_missing,
  -- NEU:
  COALESCE(p.signup_platform, 'web') AS signup_platform,
  p.app_first_seen_at
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
ORDER BY u.created_at DESC;

ALTER VIEW public.admin_users_view OWNER TO postgres;
GRANT SELECT ON public.admin_users_view TO authenticated;

-- ── 5. Übersichts-Statistik fürs Admin-Dashboard ─────────────────────
-- web_signups        : über Web registriert
-- app_signups        : über App registriert
-- web_also_in_app    : Web-Registrierung, aber inzwischen auch in der App
-- app_total          : jemals in der App gewesen (Registrierung egal)
CREATE OR REPLACE FUNCTION public.admin_registration_source_stats()
RETURNS TABLE (
  web_signups     bigint,
  app_signups     bigint,
  web_also_in_app bigint,
  app_total       bigint,
  total           bigint
)
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
  SELECT
    COUNT(*) FILTER (WHERE COALESCE(signup_platform, 'web') = 'web'),
    COUNT(*) FILTER (WHERE signup_platform = 'app'),
    COUNT(*) FILTER (WHERE COALESCE(signup_platform, 'web') = 'web'
                       AND app_first_seen_at IS NOT NULL),
    COUNT(*) FILTER (WHERE app_first_seen_at IS NOT NULL),
    COUNT(*)
  FROM public.profiles;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_registration_source_stats TO authenticated;
