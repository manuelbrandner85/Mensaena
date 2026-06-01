-- R2: Krisen-Team — Aufgaben-Koordination innerhalb einer Krise.
create table if not exists public.crisis_tasks (
  id uuid primary key default gen_random_uuid(),
  crisis_id uuid not null references public.crises(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  assigned_to uuid references public.profiles(id) on delete set null,
  title text not null,
  description text,
  status text not null default 'open', -- open | claimed | done
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_crisis_tasks_crisis
  on public.crisis_tasks(crisis_id, status);

alter table public.crisis_tasks enable row level security;

-- Lesen: jede:r angemeldete Nutzer:in (Krisen sind öffentlich sichtbar).
drop policy if exists ct_select on public.crisis_tasks;
create policy ct_select on public.crisis_tasks
  for select to authenticated using (true);

-- Anlegen: angemeldete Nutzer:in als sich selbst.
drop policy if exists ct_insert on public.crisis_tasks;
create policy ct_insert on public.crisis_tasks
  for insert to authenticated with check (created_by = auth.uid());

-- Aktualisieren: Ersteller:in der Aufgabe, Krisen-Ersteller:in,
-- die zugewiesene Person ODER (Übernehmen) eine noch nicht vergebene Aufgabe.
drop policy if exists ct_update on public.crisis_tasks;
create policy ct_update on public.crisis_tasks
  for update to authenticated using (
    created_by = auth.uid()
    or assigned_to = auth.uid()
    or assigned_to is null
    or exists (
      select 1 from public.crises c
      where c.id = crisis_tasks.crisis_id and c.creator_id = auth.uid()
    )
  );

-- Löschen: Ersteller:in der Aufgabe ODER Krisen-Ersteller:in.
drop policy if exists ct_delete on public.crisis_tasks;
create policy ct_delete on public.crisis_tasks
  for delete to authenticated using (
    created_by = auth.uid()
    or exists (
      select 1 from public.crises c
      where c.id = crisis_tasks.crisis_id and c.creator_id = auth.uid()
    )
  );
