-- ================================================================
-- KOMPLETT-FIX: Alle B7-Probleme auf einmal loesen
-- Ausfuehren: Supabase SQL Editor (ein Block!)
-- ================================================================

-- 1) group_members: RLS komplett zuruecksetzen
ALTER TABLE group_members DISABLE ROW LEVEL SECURITY;
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'group_members'
  LOOP
    EXECUTE format('DROP POLICY %I ON group_members', r.policyname);
  END LOOP;
END $$;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY gm_sel ON group_members FOR SELECT USING (true);
CREATE POLICY gm_ins ON group_members FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY gm_del ON group_members FOR DELETE USING (auth.uid() = user_id);

-- 2) group_posts: RLS komplett zuruecksetzen
ALTER TABLE group_posts DISABLE ROW LEVEL SECURITY;
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'group_posts'
  LOOP
    EXECUTE format('DROP POLICY %I ON group_posts', r.policyname);
  END LOOP;
END $$;
ALTER TABLE group_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY gp_sel ON group_posts FOR SELECT USING (true);
CREATE POLICY gp_ins ON group_posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY gp_del ON group_posts FOR DELETE USING (auth.uid() = user_id);

-- 3) challenges (fehlt komplett)
CREATE TABLE IF NOT EXISTS challenges (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title text NOT NULL,
  description text,
  category text NOT NULL DEFAULT 'umwelt',
  difficulty text NOT NULL DEFAULT 'mittel',
  points integer NOT NULL DEFAULT 50,
  max_participants integer,
  participant_count integer DEFAULT 0,
  start_date timestamptz NOT NULL DEFAULT now(),
  end_date timestamptz NOT NULL DEFAULT now() + interval '30 days',
  status text NOT NULL DEFAULT 'active',
  creator_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_challenges_status ON challenges(status);
CREATE INDEX IF NOT EXISTS idx_challenges_creator ON challenges(creator_id);
CREATE INDEX IF NOT EXISTS idx_challenges_end ON challenges(end_date);
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;
CREATE POLICY ch_sel ON challenges FOR SELECT USING (true);
CREATE POLICY ch_ins ON challenges FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY ch_upd ON challenges FOR UPDATE USING (auth.uid() = creator_id) WITH CHECK (auth.uid() = creator_id);
CREATE POLICY ch_del ON challenges FOR DELETE USING (auth.uid() = creator_id);

-- 4) challenge_progress (fehlt komplett)
CREATE TABLE IF NOT EXISTS challenge_progress (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  challenge_id uuid NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active',
  progress_pct integer DEFAULT 0,
  completed_at timestamptz,
  joined_at timestamptz DEFAULT now()
);
ALTER TABLE challenge_progress ADD CONSTRAINT uq_cp UNIQUE (challenge_id, user_id);
CREATE INDEX IF NOT EXISTS idx_cp_chal ON challenge_progress(challenge_id);
CREATE INDEX IF NOT EXISTS idx_cp_user ON challenge_progress(user_id);
ALTER TABLE challenge_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY cp_sel ON challenge_progress FOR SELECT USING (true);
CREATE POLICY cp_ins ON challenge_progress FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY cp_upd ON challenge_progress FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 5) user_badges (fehlt komplett)
CREATE TABLE IF NOT EXISTS user_badges (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  badge_id uuid NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
  earned_at timestamptz DEFAULT now()
);
ALTER TABLE user_badges ADD CONSTRAINT uq_ub UNIQUE (user_id, badge_id);
CREATE INDEX IF NOT EXISTS idx_ub_user ON user_badges(user_id);
CREATE INDEX IF NOT EXISTS idx_ub_badge ON user_badges(badge_id);
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;
CREATE POLICY ub_sel ON user_badges FOR SELECT USING (true);
CREATE POLICY ub_ins ON user_badges FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 6) bot_scheduled_messages (fehlt komplett)
CREATE TABLE IF NOT EXISTS bot_scheduled_messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  message_type text NOT NULL DEFAULT 'tip',
  title text NOT NULL,
  content text NOT NULL,
  target_audience text DEFAULT 'all',
  scheduled_for timestamptz NOT NULL DEFAULT now() + interval '1 day',
  sent_at timestamptz,
  status text NOT NULL DEFAULT 'pending',
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_bm_status ON bot_scheduled_messages(status);
CREATE INDEX IF NOT EXISTS idx_bm_sched ON bot_scheduled_messages(scheduled_for);
ALTER TABLE bot_scheduled_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY bm_sel ON bot_scheduled_messages FOR SELECT USING (true);
CREATE POLICY bm_ins ON bot_scheduled_messages FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY bm_upd ON bot_scheduled_messages FOR UPDATE USING (auth.uid() = created_by) WITH CHECK (auth.uid() = created_by);
CREATE POLICY bm_del ON bot_scheduled_messages FOR DELETE USING (auth.uid() = created_by);

-- 7) Badge Seeds
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
