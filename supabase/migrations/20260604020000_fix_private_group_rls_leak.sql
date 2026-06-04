-- ═══════════════════════════════════════════════════════════════════════════
-- SECURITY-FIX H1: Private-Gruppen-Daten-Leak schließen
--
-- BUG: group_members_select + group_posts_select waren USING(true) →
-- JEDER eingeloggte User konnte Mitgliederlisten UND Posts ALLER Gruppen
-- lesen, auch privater (groups.is_private = true). Damit war "privat"
-- faktisch wirkungslos.
--
-- FIX: Mitglieder + Posts sind sichtbar wenn
--   (a) die Gruppe öffentlich ist (is_private = false), ODER
--   (b) der anfragende User selbst Mitglied der Gruppe ist.
-- Die Gruppen-Metadaten selbst (groups) bleiben listbar (Discovery), nur
-- der Inhalt privater Gruppen ist geschützt.
-- ═══════════════════════════════════════════════════════════════════════════

-- Index für die RLS-Subquery-Performance (Mitgliedschafts-Lookup).
CREATE INDEX IF NOT EXISTS idx_group_members_user_group
  ON public.group_members(user_id, group_id);

-- ── group_members ──────────────────────────────────────────────────────
DROP POLICY IF EXISTS group_members_select ON public.group_members;
CREATE POLICY group_members_select ON public.group_members
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.groups g
       WHERE g.id = group_members.group_id
         AND g.is_private = false
    )
    OR EXISTS (
      SELECT 1 FROM public.group_members gm
       WHERE gm.group_id = group_members.group_id
         AND gm.user_id = auth.uid()
    )
  );

-- ── group_posts ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS group_posts_select ON public.group_posts;
CREATE POLICY group_posts_select ON public.group_posts
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.groups g
       WHERE g.id = group_posts.group_id
         AND g.is_private = false
    )
    OR EXISTS (
      SELECT 1 FROM public.group_members gm
       WHERE gm.group_id = group_posts.group_id
         AND gm.user_id = auth.uid()
    )
  );
