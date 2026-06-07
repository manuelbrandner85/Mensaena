-- ════════════════════════════════════════════════════════════════════════
-- KI-Admin-Fundament — zentrale Steuerungsebene für alle KI-Features.
--
-- Baut NICHT die KI-Aufrufe neu (die laufen über supabase/functions/_shared/
-- ai.ts: Gemini→Groq→Cerebras→OpenRouter). Liefert das, was bisher fehlte:
--   1. ai_feature_flags  — jedes KI-Feature einzeln an/aus (Admin-Schalter)
--   2. ai_admin_audit     — was die KI getan/empfohlen hat (Admin-sichtbar)
--   3. ai_user_risk       — lernende Risiko-Profile (Feature: Wiederholungstäter)
--   4. ai_admin_digests   — gecachte KI-Tages-Zusammenfassungen (Feature: Report)
--
-- RLS: admin/moderator lesen; Edge Functions schreiben via service_role
-- (bypassed RLS). Flag-Toggle nur via SECURITY-DEFINER-RPC set_ai_feature_flag.
-- Additiv + idempotent (IF NOT EXISTS / ON CONFLICT) — sicher mehrfach ausführbar.
-- ════════════════════════════════════════════════════════════════════════

-- ─── 1. ai_feature_flags ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ai_feature_flags (
  key         text        PRIMARY KEY,
  category    text        NOT NULL DEFAULT 'general',
  label       text        NOT NULL,
  description text        NOT NULL DEFAULT '',
  enabled     boolean     NOT NULL DEFAULT false,
  sort_order  int         NOT NULL DEFAULT 100,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  updated_by  uuid        REFERENCES public.profiles(id) ON DELETE SET NULL
);

-- ─── 2. ai_admin_audit ────────────────────────────────────────────────────
-- Was die KI getan/empfohlen hat. Bewusst getrennt von admin_audit_log
-- (menschliche Admin-Aktionen), damit KI-Aktivität separat auditierbar ist.
CREATE TABLE IF NOT EXISTS public.ai_admin_audit (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  feature     text        NOT NULL,
  actor_id    uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  action      text        NOT NULL,
  target_type text,
  target_id   text,
  summary     text,
  provider    text,
  meta        jsonb       NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_ai_admin_audit_created
  ON public.ai_admin_audit (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_admin_audit_feature
  ON public.ai_admin_audit (feature, created_at DESC);

-- ─── 3. ai_user_risk ──────────────────────────────────────────────────────
-- Lernendes Risiko-Profil pro Nutzer (0–100). Signals als JSONB
-- (z.B. {"reports":3,"velocity_flags":1,"sockpuppet_score":0.2}).
CREATE TABLE IF NOT EXISTS public.ai_user_risk (
  user_id     uuid        PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  risk_score  int         NOT NULL DEFAULT 0 CHECK (risk_score BETWEEN 0 AND 100),
  level       text        NOT NULL DEFAULT 'low' CHECK (level IN ('low','medium','high')),
  signals     jsonb       NOT NULL DEFAULT '{}'::jsonb,
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ai_user_risk_score
  ON public.ai_user_risk (risk_score DESC);

-- ─── 4. ai_admin_digests ──────────────────────────────────────────────────
-- Gecachte KI-Zusammenfassungen. period+scope unique → ein Digest je Tag.
CREATE TABLE IF NOT EXISTS public.ai_admin_digests (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  period      date        NOT NULL DEFAULT current_date,
  scope       text        NOT NULL DEFAULT 'daily',
  summary     text        NOT NULL DEFAULT '',
  stats       jsonb       NOT NULL DEFAULT '{}'::jsonb,
  provider    text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (period, scope)
);
CREATE INDEX IF NOT EXISTS idx_ai_admin_digests_period
  ON public.ai_admin_digests (period DESC);

-- ════════════════════════════════════════════════════════════════════════
-- RLS — admin/moderator lesen; service_role (Edge Functions) bypassed RLS.
-- ════════════════════════════════════════════════════════════════════════
ALTER TABLE public.ai_feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_admin_audit   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_user_risk     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_admin_digests ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'ai_feature_flags','ai_admin_audit','ai_user_risk','ai_admin_digests'
  ] LOOP
    EXECUTE format($f$
      DROP POLICY IF EXISTS "ai admin read %1$s" ON public.%1$s;
      CREATE POLICY "ai admin read %1$s" ON public.%1$s
        FOR SELECT TO authenticated
        USING (EXISTS (SELECT 1 FROM public.profiles
                       WHERE id = auth.uid()
                         AND role IN ('admin','moderator')));
    $f$, t);
  END LOOP;
END $$;

-- ════════════════════════════════════════════════════════════════════════
-- Flag-Toggle: nur via SECURITY DEFINER RPC (kein direkter UPDATE-Policy).
-- ════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.set_ai_feature_flag(
  p_key     text,
  p_enabled boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role text;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  IF caller_role <> 'admin' THEN
    RAISE EXCEPTION 'set_ai_feature_flag only callable by admin'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  UPDATE public.ai_feature_flags
     SET enabled    = p_enabled,
         updated_at = now(),
         updated_by = auth.uid()
   WHERE key = p_key;

  RETURN FOUND;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_ai_feature_flag(text, boolean) TO authenticated;

-- Helper für Edge Functions / RPC: prüft ob ein Feature aktiv ist (default false).
CREATE OR REPLACE FUNCTION public.ai_feature_enabled(p_key text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT enabled FROM public.ai_feature_flags WHERE key = p_key),
    false
  );
$$;

GRANT EXECUTE ON FUNCTION public.ai_feature_enabled(text) TO authenticated, anon, service_role;

-- ════════════════════════════════════════════════════════════════════════
-- Seed — alle KI-Features als Flags. ON CONFLICT DO NOTHING → bestehende
-- Schalter (inkl. enabled-Zustand) bleiben unangetastet bei Re-Runs.
-- Labels/Beschreibungen sind operative Admin-Config (DE) — die Panel-Chrome
-- (Titel/Buttons/Status) wird via easy_localization in 7 Sprachen übersetzt.
-- ════════════════════════════════════════════════════════════════════════
INSERT INTO public.ai_feature_flags (key, category, label, description, enabled, sort_order) VALUES
  -- Moderation & Sicherheit
  ('content_moderation', 'moderation', 'Automatische Content-Moderation',
   'Posts, Kommentare & Marktplatz werden vor Veröffentlichung KI-geprüft (Spam, Hass, unangemessen).', true, 10),
  ('image_moderation', 'moderation', 'Bild-Moderation (Vision)',
   'Hochgeladene Fotos werden auf NSFW, Gewalt & Fakes gescannt, bevor sie live gehen.', false, 11),
  ('scam_detection', 'moderation', 'Scam- & Betrugs-Erkennung',
   'Marktplatz-Angebote werden auf Vorkasse-Betrug, Phishing & Fake-Verkäufer bewertet.', false, 12),
  ('sockpuppet_detection', 'moderation', 'Mehrfach-Account-Erkennung',
   'Schreibstil- & Verhaltensmuster erkennen denselben Menschen hinter mehreren Accounts.', false, 13),
  ('risk_profiling', 'moderation', 'Wiederholungstäter-Risikoprofil',
   'Lernendes Risiko-Level pro Nutzer aus Meldungen & Mustern.', false, 14),
  -- Wachstum & Community
  ('community_health', 'growth', 'Nachbarschafts-Gesundheits-Score',
   'KI bewertet Aktivität, Hilfsbereitschaft & Stimmung pro Region.', false, 20),
  ('dead_region_alerts', 'growth', 'Tote-Region-Erkennung',
   'Findet Regionen mit Nachfrage aber ohne Helfer.', false, 21),
  ('churn_prediction', 'growth', 'Churn-Vorhersage',
   'Erkennt Nutzer kurz vor dem Absprung für Re-Engagement.', false, 22),
  ('helper_matching', 'growth', 'Semantisches Helfer-Matchmaking',
   'Verbindet Hilfegesuche mit passenden Helfern in der Nähe.', false, 23),
  ('onboarding_personalization', 'growth', 'Onboarding-Personalisierung',
   'KI-personalisierte erste Schritte für neue Nutzer.', false, 24),
  -- Insights & Analytics
  ('nl_analytics', 'insights', 'Frag-dein-Dashboard (NL-Analytics)',
   'Admin stellt Fragen in natürlicher Sprache, KI baut Abfrage & erklärt das Ergebnis.', false, 30),
  ('sentiment_trends', 'insights', 'Stimmungs-Trends',
   'Verfolgt Community-Stimmung pro Region/Modul über Zeit.', false, 31),
  ('topic_clustering', 'insights', 'Themen-Clustering',
   'Gruppiert Posts in Themen — worüber die Nachbarschaft gerade redet.', false, 32),
  ('demand_forecast', 'insights', 'Nachfrage-Prognose',
   'Prognostiziert Bedarfsspitzen (z.B. Krisen-Saison).', false, 33),
  -- Inhalte & Betrieb
  ('auto_tagging', 'content', 'Auto-Kategorisierung & Tagging',
   'Posts & Angebote werden automatisch korrekt kategorisiert.', false, 40),
  ('duplicate_detection', 'content', 'Duplikat-Erkennung',
   'Erkennt mehrfach gepostete Angebote & Spam-Wellen.', false, 41),
  ('copy_generation', 'content', 'Push-/E-Mail-Texte (mit A/B)',
   'KI schreibt Benachrichtigungs-Texte im Mensaena-Ton, schlägt Varianten vor.', false, 42),
  ('content_enhancement', 'content', 'Event-/Angebots-Veredelung',
   'Macht aus wenigen Stichworten eine vollständige Beschreibung.', false, 43),
  ('personalized_digest', 'content', 'Personalisierte Digest-Mails',
   '"Das ist in deiner Nachbarschaft passiert" — KI-kuratiert pro Nutzer.', false, 44),
  -- Vertrauen & Verifizierung
  ('verification_assist', 'trust', 'Verifizierungs-Prüfung',
   'KI prüft Verifizierungs-Anträge auf Plausibilität.', false, 50),
  ('review_authenticity', 'trust', 'Bewertungs-Echtheits-Check',
   'Erkennt Fake-, gekaufte & Rache-Bewertungen.', false, 51),
  -- Admin-Produktivität
  ('daily_digest', 'productivity', 'KI-Tages-Zusammenfassung',
   'Tägliche deutsche Zusammenfassung der wichtigsten Plattform-Ereignisse.', true, 60),
  ('support_assistant', 'productivity', 'Admin-Support-Assistent',
   'Beantwortet Admin-Fragen zu Sichtbarkeit, Sperren & RLS in Klartext.', false, 61),
  ('crisis_triage', 'productivity', 'Krisen-Triage',
   'Priorisiert neue Krisen-Meldungen automatisch nach Dringlichkeit.', false, 62),
  ('org_prevalidation', 'productivity', 'Organisations-Vorprüfung',
   'Bewertet Organisations-Vorschläge: legitim / prüfen / ablehnen.', false, 63),
  ('translation_assist', 'productivity', 'Übersetzung für Moderatoren',
   'Fremdsprachige Inhalte direkt im Dashboard übersetzen.', false, 64),
  ('report_drafts', 'productivity', 'Auto-Entwurf für Meldungs-Antworten',
   'Schlägt freundliche Antworten an Melder/Gemeldete vor.', false, 65),
  ('policy_bot', 'productivity', 'Policy-Bot (Regelwerk)',
   'Beantwortet "Ist das erlaubt?" konsistent nach Mensaena-Richtlinien.', false, 66),
  ('bulk_actions', 'productivity', 'Bulk-Action-Vorschläge',
   'Bündelt ähnliche Spam-/Verstoß-Fälle für 1-Klick-Aktionen.', false, 67),
  ('anomaly_detection', 'moderation', 'Anomalie-Erkennung',
   'Erkennt Bot-Verhalten, Massen-Posts & Meldungs-Häufungen.', false, 15)
ON CONFLICT (key) DO NOTHING;
