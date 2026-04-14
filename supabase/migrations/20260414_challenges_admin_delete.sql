-- ============================================================================
-- Migration: challenges – Admin kann Challenges löschen (RLS Override)
-- Ausfuehren: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new
-- ============================================================================

-- Bestehende Delete-Policy ersetzen: Ersteller ODER Admin darf löschen
DROP POLICY IF EXISTS challenges_delete ON challenges;

CREATE POLICY challenges_delete ON challenges
  FOR DELETE USING (
    auth.uid() = creator_id
    OR EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Auch Update: Ersteller ODER Admin darf updaten (z.B. Status setzen)
DROP POLICY IF EXISTS challenges_update ON challenges;

CREATE POLICY challenges_update ON challenges
  FOR UPDATE
  USING (
    auth.uid() = creator_id
    OR EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    auth.uid() = creator_id
    OR EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Hinweis: challenge_progress hat bereits ON DELETE CASCADE gesetzt,
-- d.h. alle Fortschritte werden beim Löschen einer Challenge automatisch
-- mit entfernt. Kein manuelles Cleanup nötig.
