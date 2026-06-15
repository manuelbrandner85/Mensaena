-- ════════════════════════════════════════════════════════════════════════
-- Post-Merge-Gesundheitswächter (SICHERER ALARM, KEIN Auto-Rollback).
-- Beobachtet die crash_logs im Fenster nach jeder gemergten Godmode-Änderung.
-- Steigt nach einem Merge plötzlich derselbe Crash bei mehreren Nutzern an,
-- wird ein Alarm in `godmode_health_alerts` geschrieben und im Dev-Agent-
-- Dashboard als Warnkarte angezeigt. Der Admin entscheidet — es wird NICHTS
-- automatisch zurückgerollt oder gelöscht.
-- ════════════════════════════════════════════════════════════════════════

create table if not exists public.godmode_health_alerts (
  id            uuid primary key default gen_random_uuid(),
  changelog_id  uuid references public.godmode_changelog(id) on delete set null,
  task_id       uuid references public.admin_dev_tasks(id) on delete set null,
  pr_number     int,
  merge_title   text,
  error_type    text,
  error_message text not null,
  app_version   text,
  crash_count   int  not null default 0,
  affected_users int not null default 0,
  status        text not null default 'open',   -- open | acknowledged | resolved
  created_at    timestamptz not null default now(),
  resolved_at   timestamptz
);

alter table public.godmode_health_alerts enable row level security;

-- Admins lesen die Alarme im Dashboard.
drop policy if exists godmode_health_alerts_admin_read on public.godmode_health_alerts;
create policy godmode_health_alerts_admin_read on public.godmode_health_alerts
  for select to authenticated
  using (exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  ));

-- Admins dürfen den Status quittieren/auf erledigt setzen (nur diese Spalten
-- über die App; Inhalt schreibt ausschließlich der Wächter via service_role).
drop policy if exists godmode_health_alerts_admin_update on public.godmode_health_alerts;
create policy godmode_health_alerts_admin_update on public.godmode_health_alerts
  for update to authenticated
  using (exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  ))
  with check (exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  ));

create index if not exists idx_godmode_health_alerts_status
  on public.godmode_health_alerts (status, created_at desc);

-- ── Wächter-Funktion ───────────────────────────────────────────────────────
-- Heuristik: betrachtet den zuletzt gemergten Godmode-Changelog-Eintrag, der
-- höchstens 24h alt ist (= aktives Beobachtungsfenster). Zählt crash_logs, die
-- NACH dem Merge UND in den letzten 2h aufgetreten sind, gruppiert nach
-- error_message. Tritt derselbe Crash bei >= 3 verschiedenen Nutzern auf, wird
-- ein offener Alarm angelegt — pro (changelog, error_message) nur einmal.
create or replace function public.godmode_check_post_merge_health()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_change   record;
  v_spike    record;
begin
  -- Jüngster Merge im 24h-Beobachtungsfenster.
  select c.id, c.task_id, c.pr_number, c.title, c.created_at
    into v_change
    from public.godmode_changelog c
   where c.created_at > now() - interval '24 hours'
   order by c.created_at desc
   limit 1;

  if v_change.id is null then
    return;  -- nichts kürzlich gemergt → nichts zu beobachten
  end if;

  for v_spike in
    select cl.error_message,
           max(cl.error_type)              as error_type,
           max(cl.app_version)             as app_version,
           count(*)                        as crash_count,
           count(distinct cl.user_id)      as affected_users
      from public.crash_logs cl
     where cl.created_at > v_change.created_at
       and cl.created_at > now() - interval '2 hours'
     group by cl.error_message
    having count(distinct cl.user_id) >= 3
  loop
    -- Dedupe: kein zweiter offener Alarm für dieselbe Änderung + Fehler.
    if not exists (
      select 1 from public.godmode_health_alerts a
       where a.changelog_id = v_change.id
         and a.error_message = v_spike.error_message
         and a.status <> 'resolved'
    ) then
      insert into public.godmode_health_alerts (
        changelog_id, task_id, pr_number, merge_title,
        error_type, error_message, app_version,
        crash_count, affected_users
      ) values (
        v_change.id, v_change.task_id, v_change.pr_number, v_change.title,
        v_spike.error_type, v_spike.error_message, v_spike.app_version,
        v_spike.crash_count, v_spike.affected_users
      );
    end if;
  end loop;
end;
$$;

-- Alle 30 Minuten prüfen (idempotent: vorher unschedule).
DO $$ BEGIN PERFORM cron.unschedule('godmode_post_merge_health');
EXCEPTION WHEN OTHERS THEN NULL; END $$;
SELECT cron.schedule(
  'godmode_post_merge_health',
  '*/30 * * * *',
  $sql$SELECT public.godmode_check_post_merge_health()$sql$
);
