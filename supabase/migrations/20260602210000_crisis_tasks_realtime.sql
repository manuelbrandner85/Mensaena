-- crisis_tasks war NICHT in der Realtime-Publication, obwohl der Client einen
-- StreamProvider (watchTasks via .stream) nutzt → Übernehmen/Erledigen/
-- Anlegen von Krisen-Team-Aufgaben aktualisierten die UI erst nach
-- Neu-Navigation. crisis_helpers + crisis_updates sind bereits drin und
-- funktionieren live. Jetzt zieht crisis_tasks nach.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'crisis_tasks'
  ) then
    alter publication supabase_realtime add table public.crisis_tasks;
  end if;
end $$;
