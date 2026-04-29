-- Restrict run_scheduled_cleanup() to service_role only.
-- Previously executable by `authenticated` which is too permissive — any
-- logged-in user could trigger heavy maintenance work.

REVOKE EXECUTE ON FUNCTION public.run_scheduled_cleanup() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.run_scheduled_cleanup() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.run_scheduled_cleanup() FROM anon;
GRANT EXECUTE ON FUNCTION public.run_scheduled_cleanup() TO service_role;
