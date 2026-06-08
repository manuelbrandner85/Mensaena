-- ════════════════════════════════════════════════════════════════════════
-- Modul-Intelligenz: neuer insight_type 'extension' (Erweiterung).
--
-- Bisher gab es nur improvement / new_module / vulnerability / inspiration.
-- 'extension' deckt die Lücke: ein bestehendes Modul um neue Fähigkeiten
-- ERWEITERN (kein komplett neues Modul, mehr als nur eine kleine Verbesserung).
--
-- Idempotent: Constraint wird gedroppt und neu gesetzt.
-- ════════════════════════════════════════════════════════════════════════

ALTER TABLE public.admin_module_insights
  DROP CONSTRAINT IF EXISTS admin_module_insights_type_check;

ALTER TABLE public.admin_module_insights
  ADD CONSTRAINT admin_module_insights_type_check
  CHECK (insight_type IN ('improvement', 'new_module', 'extension', 'vulnerability', 'inspiration'));
