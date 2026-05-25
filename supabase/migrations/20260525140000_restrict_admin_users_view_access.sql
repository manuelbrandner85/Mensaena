-- KRITISCH: admin_users_view war SELECT-bar fuer anon + authenticated.
-- Da die View SECURITY DEFINER ist (laeuft als postgres-superuser, kann
-- auth.users lesen), konnte jeder User die emails / last_sign_in_at / etc.
-- ALLER User lesen.
--
-- Fix: REVOKE alle Grants ausser fuer postgres + service_role. Zugriff
-- ausschliesslich via SECURITY DEFINER Funktion admin_list_users() mit
-- is_admin()-Check.

REVOKE ALL ON public.admin_users_view FROM anon;
REVOKE ALL ON public.admin_users_view FROM authenticated;
REVOKE ALL ON public.admin_users_view FROM PUBLIC;

-- marketing_calendar: SECURITY DEFINER View → security_invoker=on
-- damit underlying-Table-RLS (email_campaigns, social_media_posts)
-- honoriert wird.
ALTER VIEW IF EXISTS public.marketing_calendar SET (security_invoker = on);
