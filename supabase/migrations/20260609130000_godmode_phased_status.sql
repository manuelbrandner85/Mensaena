-- ════════════════════════════════════════════════════════════════════════
-- Godmode Auto-Phasen — Hotfix: Status 'phased' erlauben.
--
-- Bug: Die Edge Function legt für aufgeteilte Aufträge einen Parent-Task mit
-- status='phased' an. Die status-CHECK-Constraint kannte 'phased' aber nicht
-- → INSERT scheiterte → Edge Function 500 → „Auftrag konnte nicht gestartet
-- werden". (origin='phase' war in 20260609100000 ergänzt, der Status wurde
-- vergessen.)
--
-- Additiv + idempotent.
-- ════════════════════════════════════════════════════════════════════════

ALTER TABLE public.admin_dev_tasks
  DROP CONSTRAINT IF EXISTS admin_dev_tasks_status_check;

ALTER TABLE public.admin_dev_tasks
  ADD CONSTRAINT admin_dev_tasks_status_check
  CHECK (status IN (
    'queued','running','pr_open','awaiting_review',
    'merged','failed','no_changes','cancelled','phased'
  ));
