-- ============================================================================
-- Migration: challenge_progress – kompletter Umbau zum täglichen Check-in
--
-- Vorher: 1 Zeile pro User + Challenge (Enrollment-Tracking)
--         Felder: status, progress_pct, completed_at, joined_at, streak…
--
-- Nachher: 1 Zeile pro User + Challenge + Datum (tägliches Check-in)
--          Felder: checked_in, proof_image_url, verified_by_admin
--
-- Hinweis: Supersedes 20260414_challenge_checkins.sql (challenge_checkins
--          wird hier ebenfalls aufgeräumt, falls noch vorhanden)
-- ============================================================================

BEGIN;

-- ── 1. Alte Hilfstabelle aus 20260414_challenge_checkins.sql entfernen ────────
DROP TABLE IF EXISTS challenge_checkins CASCADE;

-- ── 2. Alte challenge_progress löschen (Enrollment-Schema) ───────────────────
DROP TABLE IF EXISTS challenge_progress CASCADE;

-- ── 3. Neue challenge_progress anlegen (tägliches Check-in-Schema) ───────────
CREATE TABLE challenge_progress (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id      UUID        NOT NULL REFERENCES challenges(id)  ON DELETE CASCADE,
  user_id           UUID        NOT NULL REFERENCES auth.users(id)  ON DELETE CASCADE,
  date              DATE        NOT NULL DEFAULT CURRENT_DATE,
  checked_in        BOOLEAN     NOT NULL DEFAULT FALSE,
  proof_image_url   TEXT,
  verified_by_admin BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Ein User kann pro Challenge und Tag genau einen Eintrag haben
  CONSTRAINT uq_challenge_progress_user_date UNIQUE (challenge_id, user_id, date)
);

-- ── 4. Indizes ────────────────────────────────────────────────────────────────
CREATE INDEX idx_cp_challenge_user  ON challenge_progress (challenge_id, user_id);
CREATE INDEX idx_cp_user_date       ON challenge_progress (user_id, date);
CREATE INDEX idx_cp_challenge_date  ON challenge_progress (challenge_id, date);
CREATE INDEX idx_cp_verified        ON challenge_progress (verified_by_admin) WHERE verified_by_admin = TRUE;

-- ── 5. Row Level Security ─────────────────────────────────────────────────────
ALTER TABLE challenge_progress ENABLE ROW LEVEL SECURITY;

-- Jeder kann Fortschritte lesen (für Leaderboards, Challenge-Detail etc.)
CREATE POLICY cp_select_all ON challenge_progress
  FOR SELECT USING (TRUE);

-- Eingeloggter User darf nur eigene Zeilen anlegen
CREATE POLICY cp_insert_own ON challenge_progress
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- User darf eigene Zeilen updaten (z.B. proof_image_url nachträglich setzen)
CREATE POLICY cp_update_own ON challenge_progress
  FOR UPDATE
  USING  (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Admin darf alle Zeilen updaten (verified_by_admin setzen)
CREATE POLICY cp_update_admin ON challenge_progress
  FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Admin darf Einträge löschen (invalidieren)
CREATE POLICY cp_delete_admin ON challenge_progress
  FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

COMMIT;

-- ── 6. Storage Bucket (einmalig im Supabase Dashboard anlegen) ───────────────
-- Name: challenge-proofs  |  Public: true
-- Storage RLS (Dashboard → Storage → Policies):
--   INSERT: bucket_id = 'challenge-proofs' AND auth.role() = 'authenticated'
--   SELECT: bucket_id = 'challenge-proofs'  (public read)
