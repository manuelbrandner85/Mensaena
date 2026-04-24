-- ============================================================
-- Social Media System: Kanäle, Posts, Logs
-- ============================================================

-- ── 1. social_media_channels ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.social_media_channels (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  platform        text        NOT NULL CHECK (platform IN ('facebook', 'instagram', 'x', 'linkedin')),
  label           text        NOT NULL DEFAULT '',
  access_token    text,
  api_key         text,
  api_secret      text,
  page_id         text,
  is_connected    boolean     NOT NULL DEFAULT false,
  last_verified   timestamptz,
  config          jsonb       NOT NULL DEFAULT '{}',
  created_by      uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE(platform)
);

-- ── 2. social_media_posts ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.social_media_posts (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  status          text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'scheduled', 'publishing', 'published', 'failed')),
  content         text        NOT NULL DEFAULT '',
  platforms       text[]      NOT NULL DEFAULT '{}',
  media_urls      text[]      DEFAULT '{}',
  hashtags        text[]      DEFAULT '{}',
  scheduled_at    timestamptz,
  published_at    timestamptz,
  auto_generated  boolean     NOT NULL DEFAULT false,
  ai_prompt       text,
  created_by      uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- ── 3. social_media_post_logs ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.social_media_post_logs (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id         uuid        NOT NULL REFERENCES public.social_media_posts(id) ON DELETE CASCADE,
  platform        text        NOT NULL,
  status          text        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
  platform_post_id text,
  error_msg       text,
  posted_at       timestamptz NOT NULL DEFAULT now()
);

-- ── 4. Triggers ───────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_social_channels_updated ON public.social_media_channels;
CREATE TRIGGER trg_social_channels_updated
  BEFORE UPDATE ON public.social_media_channels
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_social_posts_updated ON public.social_media_posts;
CREATE TRIGGER trg_social_posts_updated
  BEFORE UPDATE ON public.social_media_posts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 5. RLS ────────────────────────────────────────────────────
ALTER TABLE public.social_media_channels  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_media_posts     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_media_post_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sm_channels_admin" ON public.social_media_channels
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'moderator'))
  );

CREATE POLICY "sm_posts_admin" ON public.social_media_posts
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'moderator'))
  );

CREATE POLICY "sm_logs_admin" ON public.social_media_post_logs
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'moderator'))
  );

-- ── 6. Indexes ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_sm_posts_status ON public.social_media_posts(status);
CREATE INDEX IF NOT EXISTS idx_sm_posts_scheduled ON public.social_media_posts(scheduled_at) WHERE status = 'scheduled';
CREATE INDEX IF NOT EXISTS idx_sm_logs_post_id ON public.social_media_post_logs(post_id);
