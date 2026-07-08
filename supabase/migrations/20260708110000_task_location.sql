-- Godmode: "Wo finde ich das?" — Fundort neuer Features in der App.
--
-- Bei Neuerungen/neuen Modulen war nach dem Merge unklar, WO in der App das
-- Neue zu finden ist. Der Agent schreibt jetzt eine Pflicht-Zeile
-- "📍 Zu finden: <Navigationspfad>" in jede PR-Beschreibung; die Automerge-
-- Workflows extrahieren sie und speichern sie hier — das Dashboard zeigt den
-- Fundort direkt an der Auftragskarte und im Changelog.

ALTER TABLE public.admin_dev_tasks
  ADD COLUMN IF NOT EXISTS location text;

ALTER TABLE public.godmode_changelog
  ADD COLUMN IF NOT EXISTS location text;
