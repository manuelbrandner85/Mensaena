-- ============================================================================
-- Migration 032: B7 New Modules – Groups, Marketplace, Challenges, Badges
-- Ausfuehren: Supabase SQL Editor
-- https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new
-- ============================================================================

-- ── 1) groups ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS groups (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  category text NOT NULL DEFAULT 'sonstiges',
  is_private boolean DEFAULT false,
  image_url text,
  member_count integer DEFAULT 0,
  post_count integer DEFAULT 0,
  creator_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_groups_slug ON groups(slug);
CREATE INDEX IF NOT EXISTS idx_groups_creator ON groups(creator_id);
CREATE INDEX IF NOT EXISTS idx_groups_category ON groups(category);

ALTER TABLE groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY groups_select ON groups FOR SELECT USING (true);
CREATE POLICY groups_insert ON groups FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY groups_update ON groups FOR UPDATE USING (auth.uid() = creator_id) WITH CHECK (auth.uid() = creator_id);
CREATE POLICY groups_delete ON groups FOR DELETE USING (auth.uid() = creator_id);


-- ── 2) group_members ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS group_members (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member',
  joined_at timestamptz DEFAULT now(),
  CONSTRAINT uq_group_members UNIQUE (group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_members_group ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(user_id);

ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY group_members_select ON group_members FOR SELECT USING (true);
CREATE POLICY group_members_insert ON group_members FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY group_members_delete ON group_members FOR DELETE USING (auth.uid() = user_id);


-- ── 3) group_posts ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS group_posts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content text NOT NULL,
  image_url text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_group_posts_group ON group_posts(group_id, created_at);
CREATE INDEX IF NOT EXISTS idx_group_posts_user ON group_posts(user_id);

ALTER TABLE group_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY group_posts_select ON group_posts FOR SELECT USING (true);
CREATE POLICY group_posts_insert ON group_posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY group_posts_delete ON group_posts FOR DELETE USING (auth.uid() = user_id);


-- ── 4) marketplace_listings ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_listings (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title text NOT NULL,
  description text,
  price numeric(10,2),
  price_type text NOT NULL DEFAULT 'negotiable',
  category text NOT NULL DEFAULT 'sonstiges',
  condition_state text DEFAULT 'gut',
  image_urls text[] DEFAULT '{}',
  location_text text,
  lat double precision,
  lng double precision,
  seller_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_seller ON marketplace_listings(seller_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_cat ON marketplace_listings(category);
CREATE INDEX IF NOT EXISTS idx_marketplace_status ON marketplace_listings(status);

ALTER TABLE marketplace_listings ENABLE ROW LEVEL SECURITY;

CREATE POLICY marketplace_select ON marketplace_listings FOR SELECT USING (true);
CREATE POLICY marketplace_insert ON marketplace_listings FOR INSERT WITH CHECK (auth.uid() = seller_id);
CREATE POLICY marketplace_update ON marketplace_listings FOR UPDATE USING (auth.uid() = seller_id) WITH CHECK (auth.uid() = seller_id);
CREATE POLICY marketplace_delete ON marketplace_listings FOR DELETE USING (auth.uid() = seller_id);


-- ── 5) challenges ───────────────────────────────────────────────────────────
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
  end_date timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'active',
  creator_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_challenges_status ON challenges(status);
CREATE INDEX IF NOT EXISTS idx_challenges_creator ON challenges(creator_id);
CREATE INDEX IF NOT EXISTS idx_challenges_end ON challenges(end_date);

ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY challenges_select ON challenges FOR SELECT USING (true);
CREATE POLICY challenges_insert ON challenges FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY challenges_update ON challenges FOR UPDATE USING (auth.uid() = creator_id) WITH CHECK (auth.uid() = creator_id);
CREATE POLICY challenges_delete ON challenges FOR DELETE USING (auth.uid() = creator_id);


-- ── 6) challenge_progress ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS challenge_progress (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  challenge_id uuid NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active',
  progress_pct integer DEFAULT 0,
  completed_at timestamptz,
  joined_at timestamptz DEFAULT now(),
  CONSTRAINT uq_challenge_progress UNIQUE (challenge_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_challenge_progress_chal ON challenge_progress(challenge_id);
CREATE INDEX IF NOT EXISTS idx_challenge_progress_user ON challenge_progress(user_id);

ALTER TABLE challenge_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY challenge_progress_select ON challenge_progress FOR SELECT USING (true);
CREATE POLICY challenge_progress_insert ON challenge_progress FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY challenge_progress_update ON challenge_progress FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);


-- ── 7) badges ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS badges (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  description text NOT NULL,
  icon text NOT NULL DEFAULT 'award',
  category text NOT NULL DEFAULT 'engagement',
  requirement_type text NOT NULL,
  requirement_value integer NOT NULL DEFAULT 1,
  points integer NOT NULL DEFAULT 10,
  rarity text NOT NULL DEFAULT 'common',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY badges_select ON badges FOR SELECT USING (true);


-- ── 8) user_badges ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_badges (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  badge_id uuid NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
  earned_at timestamptz DEFAULT now(),
  CONSTRAINT uq_user_badges UNIQUE (user_id, badge_id)
);

CREATE INDEX IF NOT EXISTS idx_user_badges_user ON user_badges(user_id);
CREATE INDEX IF NOT EXISTS idx_user_badges_badge ON user_badges(badge_id);

ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_badges_select ON user_badges FOR SELECT USING (true);
CREATE POLICY user_badges_insert ON user_badges FOR INSERT WITH CHECK (auth.uid() = user_id);


-- ── 9) Seed: Default Badges ────────────────────────────────────────────────
INSERT INTO badges (name, description, icon, category, requirement_type, requirement_value, points, rarity) VALUES
  ('Willkommen!',            'Registrierung abgeschlossen',       'star',     'engagement', 'register',             1,   10,  'common'),
  ('Erster Beitrag',         'Deinen ersten Beitrag erstellt',    'zap',      'engagement', 'posts_created',        1,   20,  'common'),
  ('Aktiv dabei',            '10 Beitraege erstellt',             'flame',    'engagement', 'posts_created',        10,  50,  'uncommon'),
  ('Vielschreiber',          '50 Beitraege erstellt',             'book',     'engagement', 'posts_created',        50,  100, 'rare'),
  ('Ersthelfer',             'Erste Hilfe angeboten',             'heart',    'helper',     'help_offered',         1,   25,  'common'),
  ('Held der Nachbarschaft', '25 Hilfsangebote',                  'shield',   'helper',     'help_offered',         25,  150, 'epic'),
  ('Vertrauenswuerdig',      'Trust-Score ueber 4.0',             'trophy',   'social',     'trust_score',          4,   100, 'rare'),
  ('Netzwerker',             'In 5 Gruppen beigetreten',          'users',    'social',     'groups_joined',        5,   50,  'uncommon'),
  ('Wissenstraeger',         '5 Wiki-Artikel geschrieben',        'book',     'knowledge',  'articles_written',     5,   75,  'rare'),
  ('Challenge-Meister',      '10 Challenges abgeschlossen',       'target',   'special',    'challenges_completed', 10,  200, 'epic'),
  ('Gemeinschaftslegende',   '100 Hilfsangebote + Trust 4.5+',    'crown',    'special',    'legendary_helper',     100, 500, 'legendary'),
  ('Eventplaner',            '5 Veranstaltungen erstellt',        'calendar', 'social',     'events_created',       5,   75,  'uncommon')
ON CONFLICT DO NOTHING;


-- ── 10) bot_scheduled_messages ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bot_scheduled_messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  message_type text NOT NULL DEFAULT 'tip',
  title text NOT NULL,
  content text NOT NULL,
  target_audience text DEFAULT 'all',
  scheduled_for timestamptz NOT NULL,
  sent_at timestamptz,
  status text NOT NULL DEFAULT 'pending',
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bot_msgs_status ON bot_scheduled_messages(status);
CREATE INDEX IF NOT EXISTS idx_bot_msgs_scheduled ON bot_scheduled_messages(scheduled_for);

ALTER TABLE bot_scheduled_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY bot_msgs_select ON bot_scheduled_messages FOR SELECT USING (true);
CREATE POLICY bot_msgs_insert ON bot_scheduled_messages FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY bot_msgs_update ON bot_scheduled_messages FOR UPDATE USING (auth.uid() = created_by) WITH CHECK (auth.uid() = created_by);
CREATE POLICY bot_msgs_delete ON bot_scheduled_messages FOR DELETE USING (auth.uid() = created_by);
