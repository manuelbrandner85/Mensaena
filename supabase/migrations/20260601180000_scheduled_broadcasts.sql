-- A5: Geplante Broadcasts — Admin plant Ankündigungen, pg_cron verschickt sie.
create table if not exists public.scheduled_broadcasts (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  link text,
  priority text not null default 'normal', -- low | normal | high
  scheduled_at timestamptz not null,
  status text not null default 'pending', -- pending | sent | cancelled
  sent_at timestamptz,
  recipients_count integer,
  created_at timestamptz not null default now()
);

create index if not exists idx_sched_broadcasts_due
  on public.scheduled_broadcasts(status, scheduled_at);

alter table public.scheduled_broadcasts enable row level security;

-- Nur Admins dürfen geplante Broadcasts sehen/verwalten.
drop policy if exists sb_admin_all on public.scheduled_broadcasts;
create policy sb_admin_all on public.scheduled_broadcasts
  for all to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Admin-RPC: Broadcast planen.
create or replace function public.admin_schedule_broadcast(
  p_title text,
  p_body text,
  p_scheduled_at timestamptz,
  p_link text default null,
  p_priority text default 'normal'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Unauthorized';
  end if;
  if coalesce(btrim(p_title), '') = '' or coalesce(btrim(p_body), '') = '' then
    raise exception 'Title and body required';
  end if;
  insert into public.scheduled_broadcasts
    (created_by, title, body, link, priority, scheduled_at)
  values (
    auth.uid(), btrim(p_title), btrim(p_body),
    nullif(btrim(coalesce(p_link, '')), ''),
    case when p_priority in ('low','normal','high') then p_priority else 'normal' end,
    p_scheduled_at
  )
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.admin_schedule_broadcast(text, text, timestamptz, text, text) from public;
grant execute on function public.admin_schedule_broadcast(text, text, timestamptz, text, text) to authenticated;

-- Admin-RPC: einen geplanten (noch nicht versendeten) Broadcast abbrechen.
create or replace function public.admin_cancel_scheduled_broadcast(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Unauthorized';
  end if;
  update public.scheduled_broadcasts
    set status = 'cancelled'
    where id = p_id and status = 'pending';
  return found;
end;
$$;

revoke all on function public.admin_cancel_scheduled_broadcast(uuid) from public;
grant execute on function public.admin_cancel_scheduled_broadcast(uuid) to authenticated;

-- Verarbeitungs-Funktion: wird von pg_cron jede Minute aufgerufen. Versendet
-- alle fälligen pending-Broadcasts an alle Profile und markiert sie als sent.
create or replace function public.process_scheduled_broadcasts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_count integer;
  v_total integer := 0;
begin
  for r in
    select * from public.scheduled_broadcasts
    where status = 'pending' and scheduled_at <= now()
    order by scheduled_at
    limit 20
  loop
    insert into public.notifications
      (user_id, type, title, body, link, category, priority, actor_id)
    select pr.id, 'announcement', r.title, r.body, r.link, 'system',
           r.priority, r.created_by
    from public.profiles pr;

    get diagnostics v_count = row_count;

    update public.scheduled_broadcasts
      set status = 'sent', sent_at = now(), recipients_count = v_count
      where id = r.id;

    v_total := v_total + 1;
  end loop;
  return v_total;
end;
$$;

revoke all on function public.process_scheduled_broadcasts() from public;

-- pg_cron: jede Minute fällige Broadcasts verarbeiten.
select cron.schedule(
  'process-scheduled-broadcasts',
  '* * * * *',
  $$select public.process_scheduled_broadcasts();$$
);
