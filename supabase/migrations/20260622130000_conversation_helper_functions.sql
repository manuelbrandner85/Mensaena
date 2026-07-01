-- Backfill: is_conversation_member() fehlte in der Migrationshistorie.
--
-- Root-Cause (Preview-Branch-Bug, gefunden 2026-07-01): die Funktion wurde
-- NIE über eine Migration angelegt, sondern nur einmalig manuell im Supabase
-- Dashboard SQL-Editor ausgeführt (supabase/FIX_RLS_RECURSION.sql bzw.
-- FIX_DM_AND_ALL.sql — beide sind lose Skripte, keine Migrationen). Auf
-- Production existiert die Funktion daher bereits; ein FRISCHES Aufsetzen der
-- DB (Preview-Branch, Disaster-Recovery, neues Projekt) spielt aber NUR die
-- Migrationen ab und bricht dann in 20260622140000_community_channel_create_rpc.sql
-- mit "function is_conversation_member(uuid, uuid) does not exist" (SQLSTATE
-- 42883), weil die Policy dort die Funktion referenziert, bevor sie je
-- angelegt wurde.
--
-- Diese Migration holt die Funktion nach — Definition 1:1 identisch zu der
-- bereits auf Production laufenden Version (CREATE OR REPLACE = No-Op dort).
-- Zeitstempel bewusst VOR 20260622140000 gesetzt, damit ein frischer Replay
-- die Funktion vor ihrer ersten Nutzung anlegt.

CREATE OR REPLACE FUNCTION public.is_conversation_member(conv_id UUID, uid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.conversation_members
    WHERE conversation_id = conv_id AND user_id = uid
  );
$$;
