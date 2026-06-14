-- Auto-Changelog: hält jede gemergte Godmode-Änderung fest (vom
-- agent_automerge.yml beim Merge per service_role eingetragen) und zeigt sie
-- im Dev-Agent-Dashboard als "Änderungsverlauf".
create table if not exists public.godmode_changelog (
  id         uuid primary key default gen_random_uuid(),
  task_id    uuid references public.admin_dev_tasks(id) on delete set null,
  title      text not null,
  pr_number  int,
  created_at timestamptz not null default now()
);

alter table public.godmode_changelog enable row level security;

drop policy if exists godmode_changelog_admin_read on public.godmode_changelog;
create policy godmode_changelog_admin_read on public.godmode_changelog
  for select to authenticated
  using (exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  ));
-- Schreiben ausschließlich serverseitig (service_role aus dem Workflow).

create index if not exists idx_godmode_changelog_created
  on public.godmode_changelog (created_at desc);
