-- Godmode Live-Fortschritt (#4): der CLI-Fortschritt-Tailer in admin_agent.yml
-- schreibt laufend, welche Datei der Agent gerade liest/bearbeitet, wie viele
-- Datei-Operationen schon liefen und einen Heartbeat — das Dashboard zeigt das
-- in Echtzeit an der laufenden Auftragskarte.

ALTER TABLE public.admin_dev_tasks
  ADD COLUMN IF NOT EXISTS current_file text,
  ADD COLUMN IF NOT EXISTS analyzed_files integer,
  ADD COLUMN IF NOT EXISTS phase text,
  ADD COLUMN IF NOT EXISTS heartbeat_at timestamptz;
