-- ============================================================================
-- Migration 031: post_comments, post_votes, post_shares, push_subscriptions
-- Tabellen fuer Kommentar-System, Voting, Share-Tracking und Push-Benachrichtigungen
-- Ausfuehren: Supabase SQL Editor → https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new
-- ============================================================================

-- ── 1) post_comments ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS post_comments (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id     uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  parent_id   uuid REFERENCES post_comments(id) ON DELETE CASCADE,  -- Antworten
  content     text NOT NULL CHECK (char_length(content) BETWEEN 1 AND 2000),
  is_edited   boolean DEFAULT false,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

-- Indizes
CREATE INDEX IF NOT EXISTS idx_post_comments_post    ON post_comments(post_id, created_at);
CREATE INDEX IF NOT EXISTS idx_post_comments_user    ON post_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_parent  ON post_comments(parent_id);

-- RLS
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;

-- Jeder kann Kommentare lesen
CREATE POLICY "post_comments_select" ON post_comments
  FOR SELECT USING (true);

-- Eingeloggte User koennen kommentieren
CREATE POLICY "post_comments_insert" ON post_comments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Eigene Kommentare bearbeiten
CREATE POLICY "post_comments_update" ON post_comments
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Eigene Kommentare loeschen (oder Post-Besitzer)
CREATE POLICY "post_comments_delete" ON post_comments
  FOR DELETE USING (
    auth.uid() = user_id
    OR auth.uid() = (SELECT p.user_id FROM posts p WHERE p.id = post_id)
  );

-- Updated_at Trigger
CREATE OR REPLACE FUNCTION update_post_comments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_post_comments_updated_at
  BEFORE UPDATE ON post_comments
  FOR EACH ROW EXECUTE FUNCTION update_post_comments_updated_at();


-- ── 2) post_votes ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS post_votes (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id     uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  vote        smallint NOT NULL CHECK (vote = -1 OR vote = 1),  -- -1 = downvote, 1 = upvote
  created_at  timestamptz DEFAULT now(),
  UNIQUE(post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_votes_post ON post_votes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_votes_user ON post_votes(user_id);

-- RLS
ALTER TABLE post_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "post_votes_select" ON post_votes
  FOR SELECT USING (true);

CREATE POLICY "post_votes_insert" ON post_votes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "post_votes_update" ON post_votes
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "post_votes_delete" ON post_votes
  FOR DELETE USING (auth.uid() = user_id);


-- ── 3) Kommentar-Zaehler View (optional, fuer Performance) ──────────────────
CREATE OR REPLACE VIEW v_post_comment_counts AS
SELECT
  post_id,
  count(*) AS comment_count
FROM post_comments
GROUP BY post_id;

-- ── 4) Vote-Score View ──────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_post_vote_scores AS
SELECT
  post_id,
  coalesce(sum(vote), 0) AS score,
  count(*) FILTER (WHERE vote = 1) AS upvotes,
  count(*) FILTER (WHERE vote = -1) AS downvotes
FROM post_votes
GROUP BY post_id;


-- ── 5) post_shares – Sharing Tracking ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS post_shares (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id     uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id     uuid REFERENCES profiles(id) ON DELETE SET NULL,  -- nullable fuer anonyme Shares
  platform    text NOT NULL DEFAULT 'link',  -- 'link', 'whatsapp', 'email', 'native', 'copy'
  created_at  timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_post_shares_post ON post_shares(post_id);

ALTER TABLE post_shares ENABLE ROW LEVEL SECURITY;

CREATE POLICY "post_shares_select" ON post_shares
  FOR SELECT USING (true);

CREATE POLICY "post_shares_insert" ON post_shares
  FOR INSERT WITH CHECK (true);  -- Auch anonyme User duerfen sharen

-- Share-Count View
CREATE OR REPLACE VIEW v_post_share_counts AS
SELECT
  post_id,
  count(*) AS share_count
FROM post_shares
GROUP BY post_id;


-- ── 6) push_subscriptions ──────────────────────────────────────────────────
-- Speichert Web-Push-Subscriptions pro User/Browser
CREATE TABLE IF NOT EXISTS push_subscriptions (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  endpoint    text NOT NULL UNIQUE,
  p256dh      text NOT NULL,
  auth        text NOT NULL,
  user_agent  text,
  created_at  timestamptz DEFAULT now(),
  last_used   timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_push_sub_user ON push_subscriptions(user_id);

ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "push_sub_select" ON push_subscriptions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "push_sub_insert" ON push_subscriptions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "push_sub_delete" ON push_subscriptions
  FOR DELETE USING (auth.uid() = user_id);
