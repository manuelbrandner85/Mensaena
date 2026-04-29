-- Make dm_calls.caller_id reference public.profiles for consistency with
-- callee_id (which already points at profiles). This keeps both ends of a
-- call consistent and lets PostgREST joins work symmetrically.
--
-- The old constraint pointed at auth.users; we drop whichever one is present
-- (name may vary across environments) before re-adding.

DO $$
DECLARE
  c RECORD;
BEGIN
  FOR c IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.dm_calls'::regclass
      AND contype = 'f'
      AND conname LIKE '%caller%'
  LOOP
    EXECUTE format('ALTER TABLE public.dm_calls DROP CONSTRAINT %I', c.conname);
  END LOOP;
END $$;

ALTER TABLE public.dm_calls
  ADD CONSTRAINT dm_calls_caller_id_fkey
  FOREIGN KEY (caller_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
