-- Add module_key to posts so each post is bound to exactly one module.
-- Existing posts have NULL → ModulePage falls back to the legacy type+category filter.
ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS module_key TEXT;

CREATE INDEX IF NOT EXISTS idx_posts_module_key ON posts(module_key) WHERE module_key IS NOT NULL;

COMMENT ON COLUMN posts.module_key IS
  'Originating module (animals, housing, harvest, knowledge, sharing, rescuer, mobility, skills, mental-support, community). NULL for legacy posts.';
