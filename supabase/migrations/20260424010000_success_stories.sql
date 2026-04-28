-- ── success_stories ───────────────────────────────────────────────────────────
-- Nutzer können nach einer abgeschlossenen Interaction eine kurze Erfolgs-
-- geschichte schreiben. Admins prüfen und genehmigen (is_approved).

CREATE TABLE IF NOT EXISTS public.success_stories (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  interaction_id  UUID        REFERENCES public.interactions(id) ON DELETE SET NULL,
  author_id       UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title           TEXT        NOT NULL,
  body            TEXT        NOT NULL,
  image_url       TEXT,
  is_approved     BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT success_stories_title_len CHECK (char_length(title) BETWEEN 5 AND 120),
  CONSTRAINT success_stories_body_len  CHECK (char_length(body)  BETWEEN 20 AND 2000)
);

CREATE INDEX IF NOT EXISTS idx_success_stories_approved
  ON public.success_stories(is_approved, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_success_stories_author
  ON public.success_stories(author_id);

ALTER TABLE public.success_stories ENABLE ROW LEVEL SECURITY;

-- Öffentlich lesbar (nur genehmigte) + eigene immer sichtbar
CREATE POLICY "success_stories_read"
  ON public.success_stories FOR SELECT
  USING (is_approved = TRUE OR auth.uid() = author_id);

-- Nur der Autor selbst darf einfügen
CREATE POLICY "success_stories_insert_own"
  ON public.success_stories FOR INSERT
  WITH CHECK (auth.uid() = author_id);

-- Admins dürfen alles (approve, delete, …)
CREATE POLICY "success_stories_admin"
  ON public.success_stories FOR ALL
  USING (auth.role() = 'service_role');
