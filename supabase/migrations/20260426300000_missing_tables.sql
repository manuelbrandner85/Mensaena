-- ═══════════════════════════════════════════════════════════════════════════
-- Fehlende Tabellen anlegen
--
-- content_reports: Im Code referenziert (ReportButton, Admin-Panel)
--                  aber nie als Migration angelegt.
-- user_blocks:     Im Code referenziert (Chat, Profil, Einstellungen)
--                  aber nie als Migration angelegt.
-- crises.resolved_image_url: 20260424_image_uploads_expansion.sql hat versucht
--                  diese Spalte auf crisis_posts zu setzen (existiert nicht),
--                  tatsächlich ist die Tabelle 'crises'.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. content_reports ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.content_reports (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id  UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content_type TEXT        NOT NULL,
  content_id   UUID        NOT NULL,
  reason       TEXT        NOT NULL,
  status       TEXT        NOT NULL DEFAULT 'pending',
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT content_reports_type_check
    CHECK (content_type IN ('post','comment','message','profile','board_post','event','organization')),
  CONSTRAINT content_reports_status_check
    CHECK (status IN ('pending','reviewed','dismissed')),
  CONSTRAINT content_reports_unique
    UNIQUE (reporter_id, content_id, content_type)
);

CREATE INDEX IF NOT EXISTS idx_content_reports_status   ON public.content_reports(status);
CREATE INDEX IF NOT EXISTS idx_content_reports_reporter ON public.content_reports(reporter_id);

ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Nutzer können eigene Meldungen einsehen" ON public.content_reports
  FOR SELECT USING (reporter_id = auth.uid());

CREATE POLICY "Authentifizierte Nutzer können Inhalte melden" ON public.content_reports
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND reporter_id = auth.uid());

CREATE POLICY "Admins können alle Meldungen verwalten" ON public.content_reports
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true)
  );

-- ── 2. user_blocks ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_blocks (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type       TEXT        DEFAULT 'general',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT user_blocks_no_self CHECK (blocker_id <> blocked_id),
  CONSTRAINT user_blocks_unique  UNIQUE (blocker_id, blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON public.user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON public.user_blocks(blocked_id);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Nutzer sehen ihre eigenen Blocks" ON public.user_blocks
  FOR SELECT USING (blocker_id = auth.uid());

CREATE POLICY "Nutzer können andere blockieren" ON public.user_blocks
  FOR INSERT WITH CHECK (auth.uid() = blocker_id);

CREATE POLICY "Nutzer können ihre Blocks entfernen" ON public.user_blocks
  FOR DELETE USING (blocker_id = auth.uid());

-- ── 3. crises: resolved_image_url ────────────────────────────────────────
-- Die Migration 20260424_image_uploads_expansion.sql hat versucht diese
-- Spalte auf 'crisis_posts' zu setzen (existiert nicht).
-- Die echte Tabelle ist 'crises'.
ALTER TABLE public.crises ADD COLUMN IF NOT EXISTS resolved_image_url TEXT;
