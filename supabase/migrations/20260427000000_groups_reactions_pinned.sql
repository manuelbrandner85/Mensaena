-- Add is_pinned to group_posts
ALTER TABLE group_posts ADD COLUMN IF NOT EXISTS is_pinned boolean NOT NULL DEFAULT false;

-- Update policy: own posts can be edited by author; admins can pin/unpin
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename='group_posts' AND policyname='Authors and admins can update posts'
  ) THEN
    CREATE POLICY "Authors and admins can update posts"
      ON group_posts FOR UPDATE
      USING (
        auth.uid() = user_id
        OR EXISTS (
          SELECT 1 FROM group_members gm
          WHERE gm.group_id = group_posts.group_id
            AND gm.user_id = auth.uid()
            AND gm.role = 'admin'
        )
      );
  END IF;
END $$;

-- group_post_reactions table
CREATE TABLE IF NOT EXISTS group_post_reactions (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id     uuid NOT NULL REFERENCES group_posts(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emoji       text NOT NULL,
  created_at  timestamptz DEFAULT now() NOT NULL,
  CONSTRAINT group_post_reactions_emoji_check CHECK (emoji IN ('👍','❤️','😂','👏')),
  UNIQUE(post_id, user_id, emoji)
);

ALTER TABLE group_post_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read group post reactions"
  ON group_post_reactions FOR SELECT USING (true);

CREATE POLICY "Authenticated users can react"
  ON group_post_reactions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove own reactions"
  ON group_post_reactions FOR DELETE
  USING (auth.uid() = user_id);

-- Allow admins to update member roles
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename='group_members' AND policyname='Admins can update member roles'
  ) THEN
    CREATE POLICY "Admins can update member roles"
      ON group_members FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM group_members gm2
          WHERE gm2.group_id = group_members.group_id
            AND gm2.user_id = auth.uid()
            AND gm2.role = 'admin'
        )
      );
  END IF;
END $$;
