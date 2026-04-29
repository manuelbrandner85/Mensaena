-- ═══════════════════════════════════════════════════════════════════════════
-- DM-Calls WhatsApp-Pattern Erweiterung
-- - callee_id: explizite Empfänger-Referenz (statt impliziter Konversations-Lookup)
-- - answered_at: Zeitpunkt der Annahme (für Dauer-Berechnung)
-- - ended_reason: 'completed','declined','missed','cancelled','error'
-- - status erweitert um 'missed' und 'declined'
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.dm_calls ADD COLUMN IF NOT EXISTS callee_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.dm_calls ADD COLUMN IF NOT EXISTS answered_at TIMESTAMPTZ;
ALTER TABLE public.dm_calls ADD COLUMN IF NOT EXISTS ended_reason TEXT
  CHECK (ended_reason IN ('completed','declined','missed','cancelled','error'));

ALTER TABLE public.dm_calls DROP CONSTRAINT IF EXISTS dm_calls_status_check;
ALTER TABLE public.dm_calls ADD CONSTRAINT dm_calls_status_check
  CHECK (status IN ('ringing','active','ended','missed','declined'));

CREATE INDEX IF NOT EXISTS idx_dm_calls_conv_status
  ON public.dm_calls(conversation_id, status);

CREATE INDEX IF NOT EXISTS idx_dm_calls_callee_ringing
  ON public.dm_calls(callee_id, status)
  WHERE status = 'ringing';

-- ── Backfill callee_id für existierende Calls ─────────────────────────────
UPDATE public.dm_calls dc
SET callee_id = cm.user_id
FROM public.conversation_members cm
WHERE dc.callee_id IS NULL
  AND cm.conversation_id = dc.conversation_id
  AND cm.user_id <> dc.caller_id;

-- ── RLS Policies ──────────────────────────────────────────────────────────
ALTER TABLE public.dm_calls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dm_calls_select" ON public.dm_calls;
CREATE POLICY "dm_calls_select" ON public.dm_calls FOR SELECT
  USING (auth.uid() = caller_id OR auth.uid() = callee_id);

DROP POLICY IF EXISTS "dm_calls_insert" ON public.dm_calls;
CREATE POLICY "dm_calls_insert" ON public.dm_calls FOR INSERT
  WITH CHECK (auth.uid() = caller_id);

DROP POLICY IF EXISTS "dm_calls_update" ON public.dm_calls;
CREATE POLICY "dm_calls_update" ON public.dm_calls FOR UPDATE
  USING (auth.uid() = caller_id OR auth.uid() = callee_id);

-- DELETE niemals erlaubt (kein POLICY → default deny)

-- ── push_subscriptions: device_type für Mobile-Filter ─────────────────────
ALTER TABLE public.push_subscriptions ADD COLUMN IF NOT EXISTS device_type TEXT
  CHECK (device_type IN ('desktop','mobile','tablet'));
