-- ════════════════════════════════════════════════════════════════════════
-- Modul-Health-Matrix: pro App-Modul (Marktplatz, Events, Skills, Krise …) eine
-- Bewertung aus dem KI-Tiefenscan (Vollständigkeit, Qualität, Tests, Gesamt-
-- Score 0-100). Geschrieben vom admin_scan.yml (service_role), gelesen im
-- Dev-Agent-Dashboard als Überblick, wo Godmode als Nächstes ansetzen sollte.
-- ════════════════════════════════════════════════════════════════════════

create table if not exists public.godmode_module_health (
  module        text primary key,        -- Schlüssel, z. B. 'marketplace'
  label         text not null,           -- lesbarer Name, z. B. 'Marktplatz'
  score         int  not null default 0, -- Gesamt 0-100
  completeness  int  not null default 0, -- 0-100
  quality       int  not null default 0, -- 0-100
  tests         int  not null default 0, -- 0-100
  notes         text,                    -- kurze Begründung / Schwerpunkte
  updated_at    timestamptz not null default now()
);

alter table public.godmode_module_health enable row level security;

drop policy if exists godmode_module_health_admin_read on public.godmode_module_health;
create policy godmode_module_health_admin_read on public.godmode_module_health
  for select to authenticated
  using (exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  ));
-- Schreiben ausschließlich serverseitig (Scan-Workflow via service_role).
