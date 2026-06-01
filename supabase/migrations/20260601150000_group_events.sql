-- G1: Gruppen-Events — Termine, die NUR für Gruppenmitglieder sichtbar sind.
create table if not exists public.group_events (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  location text,
  start_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_group_events_group
  on public.group_events(group_id, start_at);

alter table public.group_events enable row level security;

-- Lesen: nur Mitglieder der Gruppe.
drop policy if exists ge_select on public.group_events;
create policy ge_select on public.group_events
  for select to authenticated using (
    exists (
      select 1 from public.group_members m
      where m.group_id = group_events.group_id
        and m.user_id = auth.uid()
    )
  );

-- Anlegen: nur Mitglieder, und nur als sich selbst (created_by = auth.uid()).
drop policy if exists ge_insert on public.group_events;
create policy ge_insert on public.group_events
  for insert to authenticated with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.group_members m
      where m.group_id = group_events.group_id
        and m.user_id = auth.uid()
    )
  );

-- Löschen: Ersteller ODER Owner/Admin der Gruppe.
drop policy if exists ge_delete on public.group_events;
create policy ge_delete on public.group_events
  for delete to authenticated using (
    created_by = auth.uid()
    or exists (
      select 1 from public.group_members m
      where m.group_id = group_events.group_id
        and m.user_id = auth.uid()
        and m.role in ('owner','admin')
    )
  );
