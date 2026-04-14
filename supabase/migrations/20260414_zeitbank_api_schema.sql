-- ============================================================
-- Zeitbank API Schema-Erweiterungen
-- 2026-04-14
-- ============================================================

-- 1. updated_at Spalte zu timebank_entries
ALTER TABLE public.timebank_entries
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Auto-Update Trigger
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS timebank_entries_updated_at ON public.timebank_entries;
CREATE TRIGGER timebank_entries_updated_at
  BEFORE UPDATE ON public.timebank_entries
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 2. 'rejected' Status hinzufügen (CHECK-Constraint ersetzen)
ALTER TABLE public.timebank_entries
  DROP CONSTRAINT IF EXISTS timebank_entries_status_check;

ALTER TABLE public.timebank_entries
  ADD CONSTRAINT timebank_entries_status_check
  CHECK (status IN ('pending', 'confirmed', 'cancelled', 'rejected'));

-- ============================================================
-- 3. zeitbank_notifications Tabelle
-- ============================================================
CREATE TABLE IF NOT EXISTS public.zeitbank_notifications (
  id         UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  entry_id   UUID        NOT NULL REFERENCES public.timebank_entries(id) ON DELETE CASCADE,
  type       TEXT        NOT NULL DEFAULT 'confirmation_request'
                         CHECK (type IN ('confirmation_request', 'confirmed', 'rejected')),
  message    TEXT        NOT NULL,
  seen       BOOLEAN     NOT NULL DEFAULT false,
  clicked    BOOLEAN     NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_zeitbank_notif_user
  ON public.zeitbank_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_zeitbank_notif_entry
  ON public.zeitbank_notifications(entry_id);
CREATE INDEX IF NOT EXISTS idx_zeitbank_notif_unseen
  ON public.zeitbank_notifications(user_id, seen)
  WHERE seen = false;

ALTER TABLE public.zeitbank_notifications ENABLE ROW LEVEL SECURITY;

-- RLS: Nutzer sieht und verwaltet nur eigene Notifications
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'zeitbank_notifications'
      AND policyname = 'zeitbank_notif_own'
  ) THEN
    CREATE POLICY "zeitbank_notif_own"
      ON public.zeitbank_notifications
      FOR ALL
      USING (auth.uid() = user_id);
  END IF;
END $$;
