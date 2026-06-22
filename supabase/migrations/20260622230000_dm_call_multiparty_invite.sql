-- Multi-Party-DM-Call: „Teilnehmer einladen" schlug fehl mit
-- duplicate key on idx_dm_calls_active_conv — das alte UNIQUE(conversation_id)
-- WHERE status IN ('ringing','active') erlaubte nur EINEN aktiven Call pro
-- Konversation (1:1-Modell). Eine Einladung erzeugt aber eine zweite
-- ringing-Zeile im selben Gespräch.
--
-- Fix: Eindeutigkeit auf (conversation_id, callee_id) → mehrere Teilnehmer
-- können in denselben Call/Raum eingeladen werden; Doppel-Klingeln beim
-- SELBEN Empfänger bleibt verhindert.
drop index if exists idx_dm_calls_active_conv;
create unique index if not exists idx_dm_calls_active_conv_callee
  on public.dm_calls (conversation_id, callee_id)
  where (status = any (array['ringing'::text, 'active'::text]));
