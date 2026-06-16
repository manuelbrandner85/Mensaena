-- ════════════════════════════════════════════════════════════════════════
-- Überwachter Autopilot: Godmode setzt selbstständig (max. 1× täglich) den
-- Top-Quick-Win-Vorschlag um — aber mit Review-Gate (await_review=true), d. h.
-- der Admin behält das Veto (CI baut, Merge erst nach Freigabe).
-- Standard: AUS. Opt-in über den Dashboard-Toggle.
-- ════════════════════════════════════════════════════════════════════════

create table if not exists public.godmode_settings (
  id                   int  primary key default 1,
  autopilot_enabled    boolean not null default false,
  autopilot_max_open   int  not null default 1,    -- gleichzeitig offene Autopilot-Aufträge
  autopilot_last_run_at timestamptz,
  updated_at           timestamptz not null default now(),
  constraint godmode_settings_singleton check (id = 1)
);

-- Singleton-Zeile sicherstellen.
insert into public.godmode_settings (id) values (1)
  on conflict (id) do nothing;

alter table public.godmode_settings enable row level security;

drop policy if exists godmode_settings_admin_read on public.godmode_settings;
create policy godmode_settings_admin_read on public.godmode_settings
  for select to authenticated
  using (exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  ));

drop policy if exists godmode_settings_admin_update on public.godmode_settings;
create policy godmode_settings_admin_update on public.godmode_settings
  for update to authenticated
  using (exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  ))
  with check (exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  ));

-- 'autopilot' als gültige Auftrags-Herkunft erlauben (origin-Check, falls vorhanden).
do $$ begin
  alter table public.admin_dev_tasks drop constraint if exists admin_dev_tasks_origin_check;
exception when others then null; end $$;
