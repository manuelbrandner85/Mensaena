-- App-Release-Manifest für Force-Update + In-App-Changelog.
-- Pflicht-Updates: mandatory=true => Flutter-App blockiert die UI bis APK installiert.
-- Patches (Shorebird OTA) werden als Non-Mandatory-Releases mit `is_patch=true` geführt.

create table if not exists app_releases (
  id uuid primary key default gen_random_uuid(),
  -- Versions-Identifier wie pubspec: "2.0.0+20000"
  version text not null unique,
  -- Build-Number isoliert für Vergleich (numerisch)
  build_number int not null,
  -- True = User darf App nicht weiter nutzen, bis er aktualisiert hat
  mandatory boolean not null default false,
  -- True = Shorebird-Patch (kein APK-Download), False = neue APK nötig
  is_patch boolean not null default false,
  -- Download-URL der APK (nur relevant wenn is_patch=false)
  apk_url text,
  -- Plattform: 'android' / 'ios' / 'all'
  platform text not null default 'android',
  -- Erscheinungsdatum
  released_at timestamptz not null default now(),
  -- User-freundliche Changelog-Einträge:
  --   { entries: [{ type: 'feature'|'improvement'|'fix', title: string, description: string? }] }
  -- type-Mapping in der App: feature=✨ Neu, improvement=🚀 Verbessert, fix=🐛 Behoben
  changelog jsonb not null default '{"entries": []}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists app_releases_platform_build_idx
  on app_releases(platform, build_number desc);

-- RLS: jeder Logged-In User darf lesen, nur Admin schreibt.
alter table app_releases enable row level security;

drop policy if exists app_releases_select on app_releases;
create policy app_releases_select
  on app_releases for select
  to authenticated, anon
  using (true);

drop policy if exists app_releases_admin_insert on app_releases;
create policy app_releases_admin_insert
  on app_releases for insert
  to authenticated
  with check (
    exists (
      select 1 from profiles
      where id = auth.uid()
        and role in ('admin', 'moderator')
    )
  );

drop policy if exists app_releases_admin_update on app_releases;
create policy app_releases_admin_update
  on app_releases for update
  to authenticated
  using (
    exists (
      select 1 from profiles
      where id = auth.uid()
        and role in ('admin', 'moderator')
    )
  );

comment on table app_releases is
  'App-Release-Manifest. Flutter-App fragt vor jeder Session ab und blockiert UI '
  'wenn neuer mandatory-Release da ist. Shorebird-Patches werden als is_patch=true '
  'eingetragen und in Was-ist-Neu-Sheet gezeigt (kein Force-Update).';
