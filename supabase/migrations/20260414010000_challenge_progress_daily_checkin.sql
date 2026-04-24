-- ============================================================================
-- Migration: challenge_progress – Tägliche Check-in Struktur
-- Fügt date, checked_in, verified_by_admin hinzu und ändert UNIQUE-Constraint
-- auf (challenge_id, user_id, date) für tägliche Check-ins.
-- ============================================================================

-- Spalten hinzufügen (IF NOT EXISTS ist sicher bei Re-Run)
ALTER TABLE challenge_progress
  ADD COLUMN IF NOT EXISTS date date NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS checked_in boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS verified_by_admin boolean NOT NULL DEFAULT false;

-- Alten UNIQUE-Constraint entfernen (war: challenge_id, user_id)
ALTER TABLE challenge_progress
  DROP CONSTRAINT IF EXISTS uq_challenge_progress;

-- Neuer UNIQUE-Constraint: pro User, Challenge und Tag genau ein Eintrag
ALTER TABLE challenge_progress
  ADD CONSTRAINT IF NOT EXISTS uq_challenge_progress_daily
  UNIQUE (challenge_id, user_id, date);

-- RLS: Insert-Policy aktualisieren (war schon korrekt, zur Sicherheit neu)
DROP POLICY IF EXISTS challenge_progress_insert ON challenge_progress;
CREATE POLICY challenge_progress_insert ON challenge_progress
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS challenge_progress_update ON challenge_progress;
CREATE POLICY challenge_progress_update ON challenge_progress
  FOR UPDATE USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','moderator')
  ));
