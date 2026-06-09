-- ════════════════════════════════════════════════════════════════════════
-- notification_preferences JSONB in profiles
--
-- Speichert 5 Push-Kategorien direkt im Profil (kein separater JOIN).
-- Die 5 Keys bilden die Mensaena-Feature-Kategorien ab:
--   messages     — Chat & Direktnachrichten
--   interactions — Reaktionen, Kommentare, Matches
--   zeitbank     — Zeitbank-Angebote & -Anfragen
--   crisis       — Krisen & Notfälle
--   marketing    — Tipps, Neuigkeiten (DSGVO: default false)
--
-- Lesen/Schreiben via SettingsRepository (Flutter).
-- ════════════════════════════════════════════════════════════════════════

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS notification_preferences JSONB
    NOT NULL DEFAULT '{"messages":true,"interactions":true,"zeitbank":true,"crisis":true,"marketing":false}'::jsonb;
