-- ── thanks: persönliches Danke-System ────────────────────────────────────────
-- Ein Nutzer kann einem anderen Nutzer ein Danke mit Emoji + optionaler
-- Kurznachricht (≤ 200 Zeichen) senden, optional bezogen auf einen Post.
-- Ein Danke pro (Sender, Empfänger, Post). Immutable – kein Update/Delete.

CREATE TABLE IF NOT EXISTS public.thanks (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  from_user_id  UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  to_user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  post_id       UUID      REFERENCES public.posts(id)        ON DELETE SET NULL,
  emoji         TEXT NOT NULL,
  message       TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT thanks_not_self    CHECK (from_user_id <> to_user_id),
  CONSTRAINT thanks_message_len CHECK (message IS NULL OR char_length(message) <= 200),
  CONSTRAINT thanks_emoji_len   CHECK (char_length(emoji) BETWEEN 1 AND 8)
);

-- UNIQUE: ein Danke pro (Sender, Empfänger, Post)
CREATE UNIQUE INDEX IF NOT EXISTS thanks_unique_per_post
  ON public.thanks(from_user_id, to_user_id, post_id)
  WHERE post_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_thanks_to_user   ON public.thanks(to_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_thanks_from_user ON public.thanks(from_user_id);
CREATE INDEX IF NOT EXISTS idx_thanks_post      ON public.thanks(post_id) WHERE post_id IS NOT NULL;

ALTER TABLE public.thanks ENABLE ROW LEVEL SECURITY;

-- Lesen: Sender und Empfänger
CREATE POLICY "thanks_read_participant"
  ON public.thanks
  FOR SELECT
  USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);

-- Schreiben: nur der Sender selbst, nicht an sich selbst
CREATE POLICY "thanks_insert_own"
  ON public.thanks
  FOR INSERT
  WITH CHECK (auth.uid() = from_user_id AND from_user_id <> to_user_id);

-- Kein Update / Delete – Danke ist immutable
