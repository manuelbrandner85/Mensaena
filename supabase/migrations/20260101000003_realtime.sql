-- ============================================================
-- MENSAENA – Supabase Realtime Konfiguration
-- Realtime nur für sinnvolle Tabellen aktivieren.
-- Idempotent: wirft keinen Fehler bei wiederholter Ausführung.
-- ============================================================

do $$
declare
  t text;
  tables text[] := array['messages', 'notifications', 'posts'];
begin
  foreach t in array tables loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end$$;
