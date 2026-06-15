-- Detaillierter Changelog: speichert zusätzlich die geänderten Dateien und
-- eine Kurz-Zusammenfassung pro gemergter Godmode-Änderung. Geschrieben vom
-- agent_automerge.yml beim Merge (service_role), gelesen im Dev-Agent-Dashboard.
alter table public.godmode_changelog
  add column if not exists files text[];
alter table public.godmode_changelog
  add column if not exists summary text;
