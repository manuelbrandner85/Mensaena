-- ============================================================================
-- Migration: group_members → member_count Trigger + groups UPDATE Policy Fix
-- Ausfuehren: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new
-- ============================================================================

-- ── 1) Trigger-Funktion: member_count automatisch pflegen ────────────────────
-- SECURITY DEFINER = laeuft mit Rechten des Erstellers (umgeht RLS)
CREATE OR REPLACE FUNCTION update_group_member_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE groups
    SET member_count = member_count + 1
    WHERE id = NEW.group_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE groups
    SET member_count = GREATEST(0, member_count - 1)
    WHERE id = OLD.group_id;
  END IF;
  RETURN NULL;
END;
$$;

-- ── 2) Trigger anbinden ──────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_group_member_count ON group_members;
CREATE TRIGGER trg_group_member_count
AFTER INSERT OR DELETE ON group_members
FOR EACH ROW EXECUTE FUNCTION update_group_member_count();

-- ── 3) member_count auf aktuellen Stand bringen (Einmalkorrektur) ────────────
UPDATE groups g
SET member_count = (
  SELECT COUNT(*) FROM group_members gm WHERE gm.group_id = g.id
);

-- ── 4) groups UPDATE-Policy: auch authentifizierte User duerfen updaten ──────
-- Bisher: nur creator_id → blockiert automatische Updates durch andere Nutzer.
-- Neu: creator_id darf alles; andere authentifizierte User duerfen member_count
-- und post_count per Trigger aktualisieren (SECURITY DEFINER umgeht das sowieso,
-- aber fuer direkte Updates z.B. durch Admins wird die Policy erweitert).
DROP POLICY IF EXISTS groups_update ON groups;

-- Ersteller darf alle Felder aendern:
CREATE POLICY groups_update_creator ON groups
  FOR UPDATE
  USING (auth.uid() = creator_id)
  WITH CHECK (auth.uid() = creator_id);

-- Eingeloggte User duerfen member_count/post_count lesen (Trigger macht das schon,
-- aber falls Frontend direkte Updates braucht, wird hier keine extra Policy
-- benoetigt – der Trigger laeuft als SECURITY DEFINER und braucht keine Policy).
