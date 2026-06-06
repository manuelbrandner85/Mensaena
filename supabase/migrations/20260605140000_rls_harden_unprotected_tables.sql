-- ═══════════════════════════════════════════════════════════════════════════
-- RLS-Härtung: 11 Tabellen ohne Row Level Security absichern
--
-- Audit 2026-06-05: Diese Tabellen sind im Schema definiert, hatten aber KEIN
-- "ENABLE ROW LEVEL SECURITY". Da Supabase Tabellen im public-Schema über den
-- öffentlichen Anon-Key exponiert, konnte JEDER Anonyme sie voll lesen —
-- inkl. E-Mail-Logs/Kampagnen (PII: Adressen, Open/Click-Tracking) und
-- Social-/Drip-Marketing-Daten. Mehrere werden aus 'use client'-Web-
-- Komponenten mit dem Anon-Key abgefragt → echtes Datenleck.
--
-- Strategie:
--   • E-Mail-/Social-/Drip-Backend (Admin-/Marketing-Tooling): RLS an +
--     NUR Admins (profiles.role='admin') dürfen lesen/schreiben. service_role
--     umgeht RLS weiterhin (Server-Routen/Edge-Functions bleiben unberührt).
--   • poll_votes / event_rsvps (Channel-Nutzerdaten): RLS an + authentifizierte
--     dürfen LESEN (Ergebnisanzeige), aber nur EIGENE Zeilen schreiben/ändern/
--     löschen (auth.uid() = user_id). Legitime Nutzung (abstimmen, Ergebnisse
--     sehen) bleibt, Anon + Cross-User-Manipulation werden geblockt.
--
-- Idempotent: ENABLE ist no-op wenn schon an, DROP POLICY IF EXISTS davor.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Admin-only Backend-Tabellen ────────────────────────────────────────────
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'email_logs', 'email_campaigns', 'email_opens', 'email_clicks',
    'email_bounces', 'drip_campaigns', 'drip_steps',
    'social_media_channels', 'social_media_posts'
  ] LOOP
    -- Drift-Vorsorge: einige Tabellen existieren nur auf Prod, nicht auf
    -- frischem Preview-Replay. RLS-Härtung darf das nicht stoppen.
    IF to_regclass('public.' || t) IS NULL THEN
      RAISE NOTICE 'Skip RLS — Tabelle % nicht vorhanden.', t;
      CONTINUE;
    END IF;
    EXECUTE format(
      'ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON public.%I', t || '_admin_all', t);
    -- FOR ALL: lesen + schreiben nur für Admins. service_role bypassed RLS.
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR ALL TO authenticated '
      'USING (EXISTS (SELECT 1 FROM public.profiles p '
      '  WHERE p.id = auth.uid() AND p.role = ''admin'')) '
      'WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p '
      '  WHERE p.id = auth.uid() AND p.role = ''admin''))',
      t || '_admin_all', t);
  END LOOP;
END $$;

-- ── poll_votes: Channel-Abstimmungen ───────────────────────────────────────
DO $$ BEGIN
  IF to_regclass('public.poll_votes') IS NULL THEN
    RAISE NOTICE 'Skip RLS — poll_votes nicht vorhanden.';
    RETURN;
  END IF;
  ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS poll_votes_select ON public.poll_votes;
  CREATE POLICY poll_votes_select ON public.poll_votes
    FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
  DROP POLICY IF EXISTS poll_votes_insert_own ON public.poll_votes;
  CREATE POLICY poll_votes_insert_own ON public.poll_votes
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
  DROP POLICY IF EXISTS poll_votes_update_own ON public.poll_votes;
  CREATE POLICY poll_votes_update_own ON public.poll_votes
    FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  DROP POLICY IF EXISTS poll_votes_delete_own ON public.poll_votes;
  CREATE POLICY poll_votes_delete_own ON public.poll_votes
    FOR DELETE TO authenticated USING (auth.uid() = user_id);
END $$;

-- ── event_rsvps: Channel-Event-Teilnahmen ──────────────────────────────────
DO $$ BEGIN
  IF to_regclass('public.event_rsvps') IS NULL THEN
    RAISE NOTICE 'Skip RLS — event_rsvps nicht vorhanden.';
    RETURN;
  END IF;
  ALTER TABLE public.event_rsvps ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS event_rsvps_select ON public.event_rsvps;
  CREATE POLICY event_rsvps_select ON public.event_rsvps
    FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
  DROP POLICY IF EXISTS event_rsvps_insert_own ON public.event_rsvps;
  CREATE POLICY event_rsvps_insert_own ON public.event_rsvps
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
  DROP POLICY IF EXISTS event_rsvps_update_own ON public.event_rsvps;
  CREATE POLICY event_rsvps_update_own ON public.event_rsvps
    FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  DROP POLICY IF EXISTS event_rsvps_delete_own ON public.event_rsvps;
  CREATE POLICY event_rsvps_delete_own ON public.event_rsvps
    FOR DELETE TO authenticated USING (auth.uid() = user_id);
END $$;
