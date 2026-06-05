-- ═══════════════════════════════════════════════════════════════════════════
-- RLS für livestream_messages (Live-Audit-Fund)
--
-- Audit 2026-06-05 (externer Anon-Test ueber die REST-API): die Tabelle
-- public.livestream_messages lieferte ihre Zeilen an einen voellig
-- anonymen Aufrufer aus (kein ENABLE ROW LEVEL SECURITY). Damit konnte
-- JEDER -- auch nicht eingeloggt, auch nicht im Stream -- saemtliche
-- Livestream-Chat-Nachrichten (room_id, user_id, content) mitlesen.
--
-- Die App ist login-gated; legitime Zuschauer sind immer authentifiziert.
-- Daher: RLS an, Lesen nur authentifiziert, Schreiben/Loeschen nur eigene
-- Zeilen. service_role (Edge Functions / Mod-Tools) umgeht RLS weiterhin.
--
-- HINWEIS: livestream_messages ist eine nicht-versionierte (Drift-)Tabelle
-- (siehe docs/SCHEMA_DRIFT.md) -- sie existiert live, wurde aber nie als
-- CREATE TABLE committet. Diese Migration ergaenzt nur RLS auf der
-- bestehenden Tabelle (kein CREATE noetig). Spalten (room_id, user_id,
-- content) sind aus dem Repository-Code verifiziert.
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.livestream_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS livestream_messages_select ON public.livestream_messages;
CREATE POLICY livestream_messages_select ON public.livestream_messages
  FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS livestream_messages_insert_own ON public.livestream_messages;
CREATE POLICY livestream_messages_insert_own ON public.livestream_messages
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS livestream_messages_delete_own ON public.livestream_messages;
CREATE POLICY livestream_messages_delete_own ON public.livestream_messages
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);
