-- ════════════════════════════════════════════════════════════════════════
-- Security-Härtung (Supabase-Advisor): function_search_path_mutable
--
-- Funktionen ohne festen search_path sind anfällig für search_path-Hijacking
-- (besonders SECURITY DEFINER). Empfohlener Fix: search_path pinnen. Wir setzen
-- für ALLE normalen public-Funktionen, die noch keinen search_path haben,
-- `search_path = public, extensions, pg_temp` (deckt public + PostGIS/pg_trgm
-- in extensions ab). Aggregate/Window werden übersprungen (prokind='f').
--
-- BEWUSST NICHT enthalten: pauschales REVOKE EXECUTE für anon/authenticated auf
-- SECURITY-DEFINER-Funktionen — das würde legitime App-RPCs brechen und braucht
-- eine Einzelfall-Prüfung pro Funktion.
-- ════════════════════════════════════════════════════════════════════════

do $$
declare
  r record;
begin
  for r in
    select p.oid,
           p.proname,
           pg_get_function_identity_arguments(p.oid) as args
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prokind = 'f'
       and not exists (
         select 1 from unnest(coalesce(p.proconfig, '{}'::text[])) c
          where c like 'search_path=%'
       )
  loop
    begin
      execute format(
        'alter function public.%I(%s) set search_path = public, extensions, pg_temp',
        r.proname, r.args
      );
    exception when others then
      -- Einzelne Funktion nicht alterbar? Überspringen, Migration nicht brechen.
      raise notice 'search_path skip: %(%) — %', r.proname, r.args, sqlerrm;
    end;
  end loop;
end $$;
