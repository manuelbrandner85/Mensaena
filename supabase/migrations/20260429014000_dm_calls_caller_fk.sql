-- Make dm_calls.caller_id reference public.profiles for consistency with
-- callee_id (already on profiles). Idempotent so it can re-run on fresh DBs.

DO $$
DECLARE
  c RECORD;
  needs_change boolean := false;
BEGIN
  -- If a caller-related FK already references profiles, skip.
  FOR c IN
    SELECT con.conname,
           confrelid::regclass::text AS target_table
    FROM pg_constraint con
    WHERE con.conrelid = 'public.dm_calls'::regclass
      AND con.contype = 'f'
      AND con.conname LIKE '%caller%'
  LOOP
    IF c.target_table != 'profiles' THEN
      needs_change := true;
      EXECUTE format('ALTER TABLE public.dm_calls DROP CONSTRAINT %I', c.conname);
    END IF;
  END LOOP;

  -- Only add if missing (i.e. we just dropped, OR there was no caller FK at all)
  IF needs_change OR NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.dm_calls'::regclass
      AND contype = 'f'
      AND conname LIKE '%caller%'
  ) THEN
    ALTER TABLE public.dm_calls
      ADD CONSTRAINT dm_calls_caller_id_fkey
      FOREIGN KEY (caller_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
  END IF;
END $$;
