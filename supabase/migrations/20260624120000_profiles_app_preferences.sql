-- ════════════════════════════════════════════════════════════════════════
-- app_preferences JSONB in profiles
--
-- Geräteübergreifende App-Präferenzen (kein separater JOIN). Erster Key:
--   live_weather_background — Atmosphäre: animierter Live-Wetter-Hintergrund
--                             (Regen/Schnee/Wolken/Sonne) hinter den Inhalten.
--
-- Default ist bewusst ein LEERES Objekt '{}' (NICHT der Wert true): so lässt
-- sich „Nutzer hat noch nie gewählt" (Key fehlt) von „Nutzer hat aus" (Key =
-- false) unterscheiden. Der Client wendet den Funktions-Default (an) erst an,
-- wenn der Key fehlt, und migriert dabei eine zuvor lokal getroffene Wahl hoch.
--
-- Lesen/Schreiben via SettingsRepository (Flutter). Zugriff über die schon
-- bestehende RLS „profiles_own_update" — nur der Eigentümer ändert seine Zeile.
-- ════════════════════════════════════════════════════════════════════════

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS app_preferences JSONB
    NOT NULL DEFAULT '{}'::jsonb;
