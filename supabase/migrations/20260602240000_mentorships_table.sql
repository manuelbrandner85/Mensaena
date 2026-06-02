-- Das Mentorship-Feature war komplett funktionslos: der Client schrieb in
-- eine 'mentorships'-Tabelle, die NIE angelegt wurde → jede Anfrage scheiterte
-- still (catch _ → false). Tabelle + RLS + Status-Workflow nachgezogen.
create table if not exists public.mentorships (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null references public.profiles(id) on delete cascade,
  mentee_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending', -- pending | active | declined | ended
  message text,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  unique (mentor_id, mentee_id),
  check (mentor_id <> mentee_id),
  check (status in ('pending','active','declined','ended'))
);

create index if not exists idx_mentorships_mentor on public.mentorships(mentor_id, status);
create index if not exists idx_mentorships_mentee on public.mentorships(mentee_id, status);

alter table public.mentorships enable row level security;

-- Lesen: beide Beteiligten.
drop policy if exists mship_select on public.mentorships;
create policy mship_select on public.mentorships
  for select to authenticated
  using (mentor_id = auth.uid() or mentee_id = auth.uid());

-- Anlegen: nur als Mentee (Anfragender), Status muss pending sein.
drop policy if exists mship_insert on public.mentorships;
create policy mship_insert on public.mentorships
  for insert to authenticated
  with check (mentee_id = auth.uid() and status = 'pending');

-- Aktualisieren: Mentor:in (annehmen/ablehnen) ODER beide (beenden).
drop policy if exists mship_update on public.mentorships;
create policy mship_update on public.mentorships
  for update to authenticated
  using (mentor_id = auth.uid() or mentee_id = auth.uid());

-- Löschen: beide Seiten.
drop policy if exists mship_delete on public.mentorships;
create policy mship_delete on public.mentorships
  for delete to authenticated
  using (mentor_id = auth.uid() or mentee_id = auth.uid());
