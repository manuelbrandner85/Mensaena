-- ── 1-zu-1 Video/Sprachcalls in Direktnachrichten ────────────────────────────
-- Speichert aktive Anrufe für Echtzeit-Signaling (klingeln, annehmen, beenden).

CREATE TABLE IF NOT EXISTS public.dm_calls (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid        NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  caller_id       uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  call_type       text        NOT NULL CHECK (call_type IN ('audio', 'video')),
  room_name       text        NOT NULL,
  status          text        NOT NULL DEFAULT 'ringing'
                              CHECK (status IN ('ringing', 'active', 'ended')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  ended_at        timestamptz
);

CREATE INDEX IF NOT EXISTS idx_dm_calls_conv_status
  ON public.dm_calls(conversation_id, status, created_at DESC);

ALTER TABLE public.dm_calls ENABLE ROW LEVEL SECURITY;

-- Alle Konversations-Mitglieder können Anrufe sehen
CREATE POLICY "dm_calls_select" ON public.dm_calls
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.conversation_members
      WHERE conversation_id = dm_calls.conversation_id
        AND user_id = auth.uid()
    )
  );

-- Nur der Anrufer darf einfügen (muss selbst Mitglied sein)
CREATE POLICY "dm_calls_insert" ON public.dm_calls
  FOR INSERT WITH CHECK (
    auth.uid() = caller_id
    AND EXISTS (
      SELECT 1 FROM public.conversation_members
      WHERE conversation_id = dm_calls.conversation_id
        AND user_id = auth.uid()
    )
  );

-- Jedes Konversations-Mitglied darf den Status ändern (annehmen/beenden)
CREATE POLICY "dm_calls_update" ON public.dm_calls
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.conversation_members
      WHERE conversation_id = dm_calls.conversation_id
        AND user_id = auth.uid()
    )
  );
