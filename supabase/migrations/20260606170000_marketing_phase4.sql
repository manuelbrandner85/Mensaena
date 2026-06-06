-- ════════════════════════════════════════════════════════════════════════
-- Marketing Phase 4 — Content-Planer, Smart-Timing, Kampagnen-Tracking.
-- (Phase 3: reactivation_log/milestone_log/region_alerts + testimonials-
--  Erweiterung wurden bereits live angelegt — hier NUR die neuen Tabellen.)
--
-- Schutzregeln (Notbremse/Opt-out/Frequenz/stille Zeiten) erzwingen die Edge
-- Functions via _shared/notify_guard.ts. Hier nur Daten-Tabellen + RLS.
-- Nur role='admin' liest; Edge Functions schreiben via service_role (bypass RLS).
-- ════════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── content_plan ───────────────────────────────────────────────────────────
-- Content-Planer (B9): teilbare Wochenrückblicke, KI-Social-Posts (C18),
-- geplante Ankündigungen. Veröffentlichen ist IMMER manuell (kein Auto-Posting).
CREATE TABLE IF NOT EXISTS public.content_plan (
  id            uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  kind          text        NOT NULL DEFAULT 'announcement'
                            CHECK (kind IN ('announcement', 'recap', 'social', 'milestone')),
  title         text        NOT NULL,
  body          text        NOT NULL DEFAULT '',
  share_text    text,
  status        text        NOT NULL DEFAULT 'draft'
                            CHECK (status IN ('draft', 'scheduled', 'published')),
  scheduled_for timestamptz,
  source        text        NOT NULL DEFAULT 'manual',  -- manual | ai_social | recap
  created_by    uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  published_at  timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_content_plan_status
  ON public.content_plan(status, scheduled_for);

-- ─── send_time_pref ─────────────────────────────────────────────────────────
-- Smart-Timing (C15): gelernte beste Versand-Stunde (0–23, Europe/Berlin)
-- pro Nutzer ODER pro Region (Fallback).
CREATE TABLE IF NOT EXISTS public.send_time_pref (
  id          uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  scope       text        NOT NULL CHECK (scope IN ('user', 'region', 'global')),
  scope_id    text        NOT NULL DEFAULT 'all',
  best_hour   int         NOT NULL CHECK (best_hour BETWEEN 0 AND 23),
  sample_size int         NOT NULL DEFAULT 0,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (scope, scope_id)
);

-- ─── campaign_events ────────────────────────────────────────────────────────
-- Open/Click/Sent-Tracking je Kampagne; speist Smart-Timing.
CREATE TABLE IF NOT EXISTS public.campaign_events (
  id          uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id uuid,
  user_id     uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  channel     text        NOT NULL DEFAULT 'email' CHECK (channel IN ('email', 'push')),
  kind        text        NOT NULL CHECK (kind IN ('sent', 'open', 'click')),
  url         text,
  hour_berlin int         CHECK (hour_berlin BETWEEN 0 AND 23),
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_campaign_events_campaign
  ON public.campaign_events(campaign_id, kind);
CREATE INDEX IF NOT EXISTS idx_campaign_events_hour
  ON public.campaign_events(kind, hour_berlin);

-- ════════════════════════════════════════════════════════════════════════
-- RLS — nur Admin liest; service_role (Functions) bypassed RLS automatisch.
-- ════════════════════════════════════════════════════════════════════════
ALTER TABLE public.content_plan    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.send_time_pref  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaign_events ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['content_plan', 'send_time_pref', 'campaign_events'] LOOP
    EXECUTE format($f$
      DROP POLICY IF EXISTS "admin read %1$s" ON public.%1$s;
      CREATE POLICY "admin read %1$s" ON public.%1$s
        FOR SELECT TO authenticated
        USING (EXISTS (SELECT 1 FROM public.profiles
                       WHERE id = auth.uid() AND role = 'admin'));
    $f$, t);
  END LOOP;
END $$;

-- content_plan: Admin darf voll schreiben (Flutter-Admin-UI).
DROP POLICY IF EXISTS "admin write content_plan" ON public.content_plan;
CREATE POLICY "admin write content_plan" ON public.content_plan
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = auth.uid() AND role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles
                      WHERE id = auth.uid() AND role = 'admin'));

-- ─── updated_at-Trigger für content_plan ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_content_plan_touch ON public.content_plan;
CREATE TRIGGER trg_content_plan_touch
  BEFORE UPDATE ON public.content_plan
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
