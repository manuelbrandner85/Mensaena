-- Godmode-Zuverlässigkeit: Retry-Zähler + Live-Verifikation für Aufträge.
--
-- Kontext (2026-07-08): Agent-Läufe scheiterten teils SOFORT (API-Fehler nach
-- ~0,5 s, z. B. Abo-Nutzungslimit) und wurden fälschlich als "no_changes"
-- verbucht — ohne Fehlertext, ohne Wiederholung. Neu:
--   * retry_count  — wie oft admin_agent.yml für diesen Auftrag dispatcht
--                    wurde (Watchdog wiederholt bis max. 3 Versuche).
--   * live_at      — Zeitpunkt, zu dem die Auslieferungs-Pipeline (Shorebird-
--                    OTA / Web-Deploy / Supabase-Deploy) nach dem Merge grün
--                    durchlief → Status 'live' (Definition of Done: in der App,
--                    nicht nur gemergt).
--   * live_run_url — Link auf den erfolgreichen Auslieferungs-Run.
--
-- Neue status-Werte (Text-Spalte, kein Enum — kein ALTER TYPE nötig):
--   'error_retry'  — Agent-API-Fehler, Watchdog wiederholt automatisch.
--   'patch_failed' — Merge ok, aber Shorebird-OTA-Patch-Run rot.
--   'live'         — Auslieferung nach Merge bestätigt.

ALTER TABLE public.admin_dev_tasks
  ADD COLUMN IF NOT EXISTS retry_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS live_at timestamptz,
  ADD COLUMN IF NOT EXISTS live_run_url text;
