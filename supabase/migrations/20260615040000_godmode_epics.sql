-- ════════════════════════════════════════════════════════════════════════
-- Godmode-Roadmap / Epics: bündelt Vorschläge & Aufträge zu thematischen
-- Initiativen mit Fortschrittsanzeige. Ein Epic ist eine übergeordnete
-- Initiative (z. B. „Marktplatz-Ausbau"), der einzelne Aufträge zugeordnet
-- werden. Der Fortschritt ergibt sich aus gemergten vs. gesamten Aufträgen.
-- ════════════════════════════════════════════════════════════════════════

create table if not exists public.godmode_epics (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  description text,
  color       text not null default 'teal',   -- teal | amber | herzrot | leben | trust
  status      text not null default 'active',  -- active | done | archived
  sort_order  int  not null default 0,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);

alter table public.godmode_epics enable row level security;

-- Admins lesen die Roadmap.
drop policy if exists godmode_epics_admin_read on public.godmode_epics;
create policy godmode_epics_admin_read on public.godmode_epics
  for select to authenticated
  using (exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  ));
-- Schreiben ausschließlich serverseitig über die Edge Function (service_role).

create index if not exists idx_godmode_epics_status
  on public.godmode_epics (status, sort_order);

-- Zuordnung: Aufträge & Vorschläge gehören optional zu einem Epic.
alter table public.admin_dev_tasks
  add column if not exists epic_id uuid
  references public.godmode_epics(id) on delete set null;

alter table public.admin_dev_suggestions
  add column if not exists epic_id uuid
  references public.godmode_epics(id) on delete set null;

create index if not exists idx_admin_dev_tasks_epic
  on public.admin_dev_tasks (epic_id);
create index if not exists idx_admin_dev_suggestions_epic
  on public.admin_dev_suggestions (epic_id);

-- Übersicht mit Fortschritt. security_invoker=on → erbt die RLS des Abfragers,
-- d. h. nur Admins sehen Zeilen (godmode_epics + admin_dev_* sind admin-read).
create or replace view public.godmode_epic_overview
  with (security_invoker = on) as
select
  e.id,
  e.title,
  e.description,
  e.color,
  e.status,
  e.sort_order,
  e.created_at,
  (select count(*) from public.admin_dev_tasks t
     where t.epic_id = e.id)                                  as total_tasks,
  (select count(*) from public.admin_dev_tasks t
     where t.epic_id = e.id and t.status = 'merged')          as done_tasks,
  (select count(*) from public.admin_dev_tasks t
     where t.epic_id = e.id
       and t.status in ('queued','running','phased','success')) as active_tasks,
  (select count(*) from public.admin_dev_suggestions s
     where s.epic_id = e.id and s.status = 'pending')         as pending_suggestions
from public.godmode_epics e
order by
  case e.status when 'active' then 0 when 'done' then 1 else 2 end,
  e.sort_order asc,
  e.created_at desc;
