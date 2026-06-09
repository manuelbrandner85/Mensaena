-- ════════════════════════════════════════════════════════════════════════
-- Godmode Auto-Phasen — zu große Aufträge automatisch in mehrere Phasen.
--
-- Idee: Ein zu großer Auftrag wird vom Planner (Edge Function) in N Phasen
-- zerlegt. Jede Phase = eigenständiger Child-Task = eigener Branch/PR/CI/
-- Auto-Merge/OTA-Patch. Nach dem Merge einer Phase dispatcht agent_automerge
-- die nächste. So bleibt jeder Agent-Lauf klein genug fürs Turn-Budget und
-- jede Phase ist für sich auslieferbar.
--
-- Nutzt vorhandene Spalten:
--   • admin_dev_tasks.plan           (jsonb) — Parent: {phases:[…], total:N};
--                                              Child:  {phase_index:k, phase_total:N}
--   • admin_dev_tasks.parent_task_id (uuid)  — Child → Parent-Container
--
-- Diese Migration erweitert nur den origin-Check um 'phase'. Additiv + idempotent.
-- ════════════════════════════════════════════════════════════════════════

ALTER TABLE public.admin_dev_tasks
  DROP CONSTRAINT IF EXISTS admin_dev_tasks_origin_check;

ALTER TABLE public.admin_dev_tasks
  ADD CONSTRAINT admin_dev_tasks_origin_check
  CHECK (origin IN ('manual','suggestion','schedule','rollback','phase'));
