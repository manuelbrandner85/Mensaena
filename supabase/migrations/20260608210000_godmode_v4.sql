-- ════════════════════════════════════════════════════════════════════════
-- Godmode v4 — High-End-Erweiterungen:
--   • Multi-Step-Pläne      → admin_dev_tasks.plan (jsonb)
--   • Ein-Tap-Rollback      → admin_dev_tasks.merge_commit_sha, origin, parent_task_id
--   • Wiederkehrende Aufträge → Tabelle admin_dev_schedules + pg_cron
--   • Health-Dashboard      → liest bestehende Spalten (keine neuen nötig)
--   • Selbstlernend         → nutzt admin_dev_suggestions.status='rejected'
--
-- Additiv + idempotent. Schreibzugriff nur serverseitig (service_role).
-- ════════════════════════════════════════════════════════════════════════

-- ── admin_dev_tasks: neue Spalten ─────────────────────────────────────────
ALTER TABLE public.admin_dev_tasks
  ADD COLUMN IF NOT EXISTS plan             jsonb,
  ADD COLUMN IF NOT EXISTS merge_commit_sha text,
  ADD COLUMN IF NOT EXISTS origin           text NOT NULL DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS parent_task_id   uuid REFERENCES public.admin_dev_tasks(id) ON DELETE SET NULL;

-- origin: 'manual' | 'suggestion' | 'schedule' | 'rollback'
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'admin_dev_tasks_origin_check'
  ) THEN
    ALTER TABLE public.admin_dev_tasks
      ADD CONSTRAINT admin_dev_tasks_origin_check
      CHECK (origin IN ('manual','suggestion','schedule','rollback'));
  END IF;
END $$;

-- ── Wiederkehrende Aufträge ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_dev_schedules (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  created_by  uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  title       text        NOT NULL,
  instruction text        NOT NULL,
  -- Wie oft: 'daily' | 'weekly' | 'monthly'
  cadence     text        NOT NULL DEFAULT 'weekly',
  -- Wochentag (0=So..6=Sa) für weekly; Tag (1..28) für monthly; Stunde (0..23).
  day_of_week int         NOT NULL DEFAULT 1,
  day_of_month int        NOT NULL DEFAULT 1,
  hour_utc    int         NOT NULL DEFAULT 6,
  await_review boolean    NOT NULL DEFAULT false,
  enabled     boolean     NOT NULL DEFAULT true,
  last_run_at timestamptz,
  next_run_at timestamptz,
  CONSTRAINT admin_dev_schedules_cadence_check
    CHECK (cadence IN ('daily','weekly','monthly'))
);

CREATE INDEX IF NOT EXISTS idx_admin_dev_schedules_enabled
  ON public.admin_dev_schedules (enabled, next_run_at);

ALTER TABLE public.admin_dev_schedules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin dev schedules read" ON public.admin_dev_schedules;
CREATE POLICY "admin dev schedules read" ON public.admin_dev_schedules
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = auth.uid() AND role = 'admin'));

-- ── pg_cron: fällige Schedules dispatchen ─────────────────────────────────
-- Läuft stündlich, prüft welche Schedules fällig sind (next_run_at <= now),
-- ruft die Edge Function admin-dev-cron auf (per private.invoke_edge_function),
-- die den Auftrag anlegt + Workflow triggert, und setzt next_run_at neu.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('godmode-schedule-dispatch')
      WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'godmode-schedule-dispatch');

    PERFORM cron.schedule(
      'godmode-schedule-dispatch',
      '7 * * * *', -- jede Stunde um :07
      $cron$ SELECT public.invoke_edge_function('admin-dev-cron'); $cron$
    );
  END IF;
END $$;
