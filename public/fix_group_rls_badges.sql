-- =============================================================
-- FIX 1: Drop ALL existing policies on group_members
-- =============================================================
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies WHERE tablename = 'group_members'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON group_members', pol.policyname);
  END LOOP;
END $$;

-- Recreate simple, non-recursive policies
CREATE POLICY group_members_select ON group_members FOR SELECT USING (true);
CREATE POLICY group_members_insert ON group_members FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY group_members_delete ON group_members FOR DELETE USING (auth.uid() = user_id);

-- =============================================================
-- FIX 2: Drop ALL existing policies on group_posts
-- =============================================================
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies WHERE tablename = 'group_posts'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON group_posts', pol.policyname);
  END LOOP;
END $$;

-- Recreate simple, non-recursive policies
CREATE POLICY group_posts_select ON group_posts FOR SELECT USING (true);
CREATE POLICY group_posts_insert ON group_posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY group_posts_delete ON group_posts FOR DELETE USING (auth.uid() = user_id);

-- =============================================================
-- FIX 3: Insert badge seed data (skip if already exists)
-- =============================================================
INSERT INTO badges (name, description, icon, category, requirement_type, requirement_value, points, rarity) VALUES
  ('Willkommen!', 'Registrierung abgeschlossen', 'star', 'engagement', 'register', 1, 10, 'common'),
  ('Erster Beitrag', 'Deinen ersten Beitrag erstellt', 'zap', 'engagement', 'posts_created', 1, 20, 'common'),
  ('Aktiv dabei', '10 Beitraege erstellt', 'flame', 'engagement', 'posts_created', 10, 50, 'uncommon'),
  ('Vielschreiber', '50 Beitraege erstellt', 'book', 'engagement', 'posts_created', 50, 100, 'rare'),
  ('Ersthelfer', 'Erste Hilfe angeboten', 'heart', 'helper', 'help_offered', 1, 25, 'common'),
  ('Held der Nachbarschaft', '25 Hilfsangebote', 'shield', 'helper', 'help_offered', 25, 150, 'epic'),
  ('Vertrauenswuerdig', 'Trust-Score ueber 4.0', 'trophy', 'social', 'trust_score', 4, 100, 'rare'),
  ('Netzwerker', 'In 5 Gruppen beigetreten', 'users', 'social', 'groups_joined', 5, 50, 'uncommon'),
  ('Wissenstraeger', '5 Wiki-Artikel geschrieben', 'book', 'knowledge', 'articles_written', 5, 75, 'rare'),
  ('Challenge-Meister', '10 Challenges abgeschlossen', 'target', 'special', 'challenges_completed', 10, 200, 'epic'),
  ('Gemeinschaftslegende', '100 Hilfsangebote + Trust 4.5+', 'crown', 'special', 'legendary_helper', 100, 500, 'legendary'),
  ('Eventplaner', '5 Veranstaltungen erstellt', 'calendar', 'social', 'events_created', 5, 75, 'uncommon');
