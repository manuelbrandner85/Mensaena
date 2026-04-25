-- ============================================================
-- A/B-Tests + Social-Post-Erweiterungen
-- ============================================================

-- ── 1. ab_tests ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ab_tests (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id   uuid        NOT NULL REFERENCES public.email_campaigns(id) ON DELETE CASCADE,
  subject_a     text        NOT NULL,
  subject_b     text        NOT NULL,
  split_pct     int         NOT NULL DEFAULT 10,
  winner        text        CHECK (winner IN ('a', 'b')),
  opens_a       int         NOT NULL DEFAULT 0,
  opens_b       int         NOT NULL DEFAULT 0,
  sent_a        int         NOT NULL DEFAULT 0,
  sent_b        int         NOT NULL DEFAULT 0,
  status        text        NOT NULL DEFAULT 'running'
                CHECK (status IN ('running', 'resolved')),
  resolve_at    timestamptz NOT NULL DEFAULT (now() + interval '4 hours'),
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(campaign_id)
);

-- ── 2. social_media_posts: source_campaign_id hinzufügen ─────
ALTER TABLE public.social_media_posts
  ADD COLUMN IF NOT EXISTS source_campaign_id uuid
    REFERENCES public.email_campaigns(id) ON DELETE SET NULL;

-- ── 3. email_subscriptions: optimal_send_hour für Smart Timing
ALTER TABLE public.email_subscriptions
  ADD COLUMN IF NOT EXISTS optimal_send_hour int;

-- ── 4. RLS ───────────────────────────────────────────────────
ALTER TABLE public.ab_tests ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS admin_ab_tests ON public.ab_tests;
  CREATE POLICY admin_ab_tests ON public.ab_tests FOR ALL
    USING (EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')
    ));

  DROP POLICY IF EXISTS service_ab_tests ON public.ab_tests;
  CREATE POLICY service_ab_tests ON public.ab_tests FOR INSERT WITH CHECK (true);
END $$;
