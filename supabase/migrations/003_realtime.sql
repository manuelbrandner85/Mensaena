-- ============================================================
-- MENSAENA – Supabase Realtime Konfiguration
-- Realtime nur für sinnvolle Tabellen aktivieren
-- ============================================================

-- Realtime für Nachrichten (Chat)
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;

-- Realtime für Benachrichtigungen
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- Realtime für Posts (Live-Updates auf Karte)
ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
