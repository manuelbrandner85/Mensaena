-- KI-Analyse-Spalten für Moderations-Queue und Krisen-Triage.
-- Die Spalten werden von den Edge Functions ai-moderation-queue und
-- ai-crisis-triage befüllt und im Admin-Panel angezeigt.

-- ── reports: KI-Empfehlung pro Meldung ──────────────────────────────────
ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS ai_recommendation TEXT
    CHECK (ai_recommendation IN ('remove', 'keep', 'escalate', 'needs_review')),
  ADD COLUMN IF NOT EXISTS ai_confidence    NUMERIC(3, 2),
  ADD COLUMN IF NOT EXISTS ai_reason        TEXT,
  ADD COLUMN IF NOT EXISTS ai_analyzed_at   TIMESTAMPTZ;

-- ── crises: KI-Triage pro Krise ──────────────────────────────────────────
ALTER TABLE public.crises
  ADD COLUMN IF NOT EXISTS ai_triage         TEXT,
  ADD COLUMN IF NOT EXISTS ai_triage_urgency TEXT
    CHECK (ai_triage_urgency IN ('critical', 'high', 'medium', 'low')),
  ADD COLUMN IF NOT EXISTS ai_triage_actions TEXT[]     DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS ai_triage_at      TIMESTAMPTZ;
