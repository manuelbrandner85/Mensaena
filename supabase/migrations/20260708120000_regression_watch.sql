-- Godmode Regressions-Wächter (#1): nach einer Auslieferung ('live')
-- korreliert admin-dev-cron neue Fehler in error_logs/crash_logs mit dem
-- auslösenden Auftrag und öffnet bei Verdacht automatisch einen Fix-Auftrag.
--
--   * admin_dev_tasks.regression_checked_at — Zeitpunkt, zu dem der Wächter
--     diesen live-Auftrag auf Folgefehler geprüft hat (NULL = noch offen).
--     Verhindert Mehrfach-Prüfung/-Dispatch desselben Auftrags.
--   * godmode_settings.regression_watch_enabled — Schalter (Default an). Die
--     erzeugten Fix-Aufträge laufen mit await_review=true, mergen also nie
--     ohne Admin-Freigabe → sicher standardmäßig aktiv.

ALTER TABLE public.admin_dev_tasks
  ADD COLUMN IF NOT EXISTS regression_checked_at timestamptz;

ALTER TABLE public.godmode_settings
  ADD COLUMN IF NOT EXISTS regression_watch_enabled boolean NOT NULL DEFAULT true;
