-- ════════════════════════════════════════════════════════════════════════
-- Freie-API-Key-Verwaltung für den Godmode-Agenten.
-- Der Admin hinterlegt kostenlose API-Keys (Tankerkönig, OpenRouteService,
-- Open Charge Map …) mit optionalem Ablaufdatum. Der Agent kann sie beim
-- Umsetzen via service_role lesen. Clients bekommen NIE den Roh-Key:
--   • RLS aktiv, KEINE Policy → kein direkter Client-Zugriff (nur service_role).
--   • Lesen/Setzen/Löschen ausschließlich über die Edge Function admin-dev-agent
--     (key_set / keys_list / key_delete), die nur Metadaten + Maske zurückgibt.
--   • pg_cron löscht abgelaufene Keys automatisch.
-- ════════════════════════════════════════════════════════════════════════
create table if not exists public.godmode_api_keys (
  id         uuid primary key default gen_random_uuid(),
  service    text not null unique,
  api_key    text not null,
  label      text,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.godmode_api_keys enable row level security;
-- Bewusst KEINE Policy: authenticated-Clients haben keinerlei Zugriff.
-- Zugriff nur über service_role (Edge Function / Agent).

-- ── pg_cron: abgelaufene Keys täglich 01:30 UTC löschen ─────────────────────
do $$ begin perform cron.unschedule('cleanup_expired_api_keys');
exception when others then null; end $$;
select cron.schedule(
  'cleanup_expired_api_keys',
  '30 1 * * *',
  $sql$DELETE FROM public.godmode_api_keys
       WHERE expires_at IS NOT NULL AND expires_at < now()$sql$
);
