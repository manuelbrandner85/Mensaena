-- Fix: admin_dev_tasks_status_check kannte die neuen Status-Werte nicht.
--
-- In #825 (error_retry, patch_failed, live) und #832 (already_done) wurden neue
-- Status-Werte eingeführt, aber der CHECK-Constraint nie erweitert. Folge: jedes
-- PATCH auf diese Werte scheiterte still mit SQLSTATE 23514 (curl -sS schluckt
-- HTTP 400) → Aufträge blieben z. B. auf 'running' hängen, kein Auftrag wurde je
-- 'live' (→ Regressions-Wächter lief ins Leere), 'already_done' erschien nie.
-- Aufgedeckt durch die Live-Verifikation des CLI-Umbaus (#835).
--
-- Rein erweiternd (nur zusätzliche erlaubte Werte) → kein Datenverlust.

ALTER TABLE public.admin_dev_tasks
  DROP CONSTRAINT IF EXISTS admin_dev_tasks_status_check;

ALTER TABLE public.admin_dev_tasks
  ADD CONSTRAINT admin_dev_tasks_status_check CHECK (
    status = ANY (ARRAY[
      'queued', 'running', 'pr_open', 'awaiting_review', 'merged',
      'failed', 'no_changes', 'cancelled', 'phased',
      -- #825 / #832 / #4:
      'error_retry', 'patch_failed', 'live', 'already_done'
    ])
  );
