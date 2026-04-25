-- ============================================================
-- Email-Erweiterungen: Klick-Tracking, Bounces, Drip-Kampagnen
-- ============================================================

-- ── 1. email_opens (Öffnungs-Tracking) ──────────────────────
CREATE TABLE IF NOT EXISTS public.email_opens (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id  uuid        REFERENCES public.email_campaigns(id) ON DELETE CASCADE,
  email        text        NOT NULL,
  user_agent   text,
  ip_hash      text,
  opened_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_email_opens_campaign ON public.email_opens(campaign_id);

-- ── open_count / click_count / bounce_count in email_campaigns ─
ALTER TABLE public.email_campaigns
  ADD COLUMN IF NOT EXISTS open_count   int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS click_count  int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bounce_count int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS scheduled_at timestamptz,
  ADD COLUMN IF NOT EXISTS channels     text[] NOT NULL DEFAULT ARRAY['email'];

-- Status 'scheduled' erlauben (bestehende Constraint entfernen + neu setzen)
ALTER TABLE public.email_campaigns
  DROP CONSTRAINT IF EXISTS email_campaigns_status_check;
ALTER TABLE public.email_campaigns
  ADD CONSTRAINT email_campaigns_status_check
  CHECK (status IN ('draft', 'scheduled', 'sending', 'sent'));

-- RPCs für atomare Zähler
CREATE OR REPLACE FUNCTION public.increment_open_count(cid uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.email_campaigns SET open_count = open_count + 1 WHERE id = cid;
END;
$$;

-- ── 2. email_clicks ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.email_clicks (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id  uuid        REFERENCES public.email_campaigns(id) ON DELETE CASCADE,
  email        text        NOT NULL,
  url          text        NOT NULL,
  user_agent   text,
  ip_hash      text,
  clicked_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_email_clicks_campaign ON public.email_clicks(campaign_id);

CREATE OR REPLACE FUNCTION public.increment_click_count(cid uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.email_campaigns SET click_count = click_count + 1 WHERE id = cid;
END;
$$;

-- ── 3. email_bounces ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.email_bounces (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  email        text        NOT NULL,
  campaign_id  uuid        REFERENCES public.email_campaigns(id) ON DELETE SET NULL,
  bounce_type  text        NOT NULL DEFAULT 'hard' CHECK (bounce_type IN ('hard', 'soft', 'complaint')),
  reason       text,
  bounced_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_email_bounces_email    ON public.email_bounces(email);
CREATE INDEX IF NOT EXISTS idx_email_bounces_campaign ON public.email_bounces(campaign_id);

CREATE OR REPLACE FUNCTION public.increment_bounce_count(cid uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.email_campaigns SET bounce_count = bounce_count + 1 WHERE id = cid;
END;
$$;

-- ── 4. drip_campaigns ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.drip_campaigns (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text        NOT NULL,
  description  text,
  trigger_type text        NOT NULL DEFAULT 'on_register'
                CHECK (trigger_type IN ('on_register', 'on_inactive', 'manual')),
  active       boolean     NOT NULL DEFAULT false,
  created_by   uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_drip_campaigns_updated_at ON public.drip_campaigns;
CREATE TRIGGER trg_drip_campaigns_updated_at
  BEFORE UPDATE ON public.drip_campaigns
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 5. drip_steps ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.drip_steps (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  drip_campaign_id uuid        NOT NULL REFERENCES public.drip_campaigns(id) ON DELETE CASCADE,
  step_order       int         NOT NULL DEFAULT 0,
  delay_days       int         NOT NULL DEFAULT 0,
  subject          text        NOT NULL,
  html_content     text        NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_drip_steps_campaign ON public.drip_steps(drip_campaign_id, step_order);

-- ── 6. drip_enrollments ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.drip_enrollments (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  drip_campaign_id uuid        NOT NULL REFERENCES public.drip_campaigns(id) ON DELETE CASCADE,
  user_id          uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email            text        NOT NULL,
  current_step     int         NOT NULL DEFAULT 0,
  next_send_at     timestamptz NOT NULL DEFAULT now(),
  completed        boolean     NOT NULL DEFAULT false,
  enrolled_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE(drip_campaign_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_drip_enrollments_next
  ON public.drip_enrollments(next_send_at)
  WHERE completed = false;

-- ── RLS ──────────────────────────────────────────────────────
ALTER TABLE public.email_opens      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_clicks     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_bounces    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drip_campaigns   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drip_steps       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drip_enrollments ENABLE ROW LEVEL SECURITY;

-- Policies: DROP + CREATE statt IF NOT EXISTS (PG 15 kompatibel)
DO $$ BEGIN

  -- email_opens
  DROP POLICY IF EXISTS admin_email_opens ON public.email_opens;
  CREATE POLICY admin_email_opens ON public.email_opens FOR ALL
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')));

  DROP POLICY IF EXISTS service_email_opens ON public.email_opens;
  CREATE POLICY service_email_opens ON public.email_opens FOR INSERT WITH CHECK (true);

  -- email_clicks
  DROP POLICY IF EXISTS admin_email_clicks ON public.email_clicks;
  CREATE POLICY admin_email_clicks ON public.email_clicks FOR ALL
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')));

  DROP POLICY IF EXISTS service_email_clicks ON public.email_clicks;
  CREATE POLICY service_email_clicks ON public.email_clicks FOR INSERT WITH CHECK (true);

  -- email_bounces
  DROP POLICY IF EXISTS admin_email_bounces ON public.email_bounces;
  CREATE POLICY admin_email_bounces ON public.email_bounces FOR ALL
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')));

  DROP POLICY IF EXISTS service_email_bounces ON public.email_bounces;
  CREATE POLICY service_email_bounces ON public.email_bounces FOR INSERT WITH CHECK (true);

  -- drip_campaigns
  DROP POLICY IF EXISTS admin_drip_campaigns ON public.drip_campaigns;
  CREATE POLICY admin_drip_campaigns ON public.drip_campaigns FOR ALL
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')));

  -- drip_steps
  DROP POLICY IF EXISTS admin_drip_steps ON public.drip_steps;
  CREATE POLICY admin_drip_steps ON public.drip_steps FOR ALL
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')));

  -- drip_enrollments
  DROP POLICY IF EXISTS admin_drip_enrollments ON public.drip_enrollments;
  CREATE POLICY admin_drip_enrollments ON public.drip_enrollments FOR ALL
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator')));

END $$;
