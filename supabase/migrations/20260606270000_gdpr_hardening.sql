-- ============================================================
-- DSGVO-Härtung (Audit-Umsetzung). Additiv & idempotent.
-- Rechtliche Endprüfung durch Anwält:in bleibt empfohlen.
--
-- HINWEIS zu Bestandsnutzern: Diese Migration ändert nur DEFAULTS für NEUE
-- Zeilen. Bestehende `marketing_opt_in=true` (unter altem Opt-OUT-Default
-- gesetzt) werden NICHT automatisch zurückgesetzt — das ist eine
-- rechtlich/geschäftliche Entscheidung (Re-Permission-Kampagne) und sollte
-- mit der/dem Anwält:in abgestimmt werden.
-- ============================================================

-- ─────────────────────────────────────────────────────────────────────────
-- P0 #1/#9: Privacy by default — Opt-ins & Standort-Sichtbarkeit auf false
-- (Spalten wurden historisch manuell im Dashboard angelegt → ADD IF NOT
--  EXISTS bringt sie unter Versionskontrolle, ALTER SET DEFAULT korrigiert
--  den Default auch bei bereits existierender Spalte.)
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS marketing_opt_in boolean DEFAULT false;
ALTER TABLE public.profiles ALTER COLUMN marketing_opt_in SET DEFAULT false;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS reactivation_opt_in boolean DEFAULT false;
ALTER TABLE public.profiles ALTER COLUMN reactivation_opt_in SET DEFAULT false;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email_opt_in boolean DEFAULT false;
ALTER TABLE public.profiles ALTER COLUMN email_opt_in SET DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email_opt_in_at timestamptz;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS show_location boolean DEFAULT false;
ALTER TABLE public.profiles ALTER COLUMN show_location SET DEFAULT false;

-- ─────────────────────────────────────────────────────────────────────────
-- P0 #1: E-Mail Double-Opt-in — Voraussetzungen in der DB
--   • subscribed-Default false (kein Auto-Abo mehr)
--   • confirm_token + confirmed_at für den Bestätigungs-Klick
--   • Signup-Trigger legt NUR noch einen unbestätigten Eintrag an (subscribed=false)
-- Der eigentliche Versand der Bestätigungs-Mail + /confirm-Endpoint sind als
-- Folge-Schritt umzusetzen (braucht Mail-Provider-Wiring + Test). Bis dahin
-- ist der Zustand DSGVO-SICHER: ohne Bestätigung wird NICHTS versendet.
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.email_subscriptions ALTER COLUMN subscribed SET DEFAULT false;
ALTER TABLE public.email_subscriptions ADD COLUMN IF NOT EXISTS confirmed_at timestamptz;
ALTER TABLE public.email_subscriptions ADD COLUMN IF NOT EXISTS confirm_token text DEFAULT gen_random_uuid()::text;
UPDATE public.email_subscriptions SET confirm_token = gen_random_uuid()::text WHERE confirm_token IS NULL;

CREATE OR REPLACE FUNCTION public.handle_new_user_email_subscription()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- KEIN Auto-Opt-in mehr: unbestätigter Eintrag, subscribed=false.
  -- Aktivierung erst nach Bestätigungs-Klick (Double-Opt-in).
  INSERT INTO public.email_subscriptions (user_id, email, subscribed)
  VALUES (NEW.id, NEW.email, false)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END $$;

-- ─────────────────────────────────────────────────────────────────────────
-- P0 #2: Einwilligungs-Nachweis (Art. 7 Abs. 1) — append-only consents-Log
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.consents (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  consent_type  text NOT NULL,   -- 'marketing' | 'reactivation' | 'email' | 'location' | 'privacy_policy'
  granted       boolean NOT NULL,
  source        text,            -- 'settings' | 'signup' | 'onboarding'
  policy_version text,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_consents_user
  ON public.consents(user_id, consent_type, created_at DESC);

ALTER TABLE public.consents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS consents_insert_own ON public.consents;
CREATE POLICY consents_insert_own ON public.consents
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS consents_select_own ON public.consents;
CREATE POLICY consents_select_own ON public.consents
  FOR SELECT USING (auth.uid() = user_id);

-- Schreibt einen Einwilligungs-/Widerrufs-Nachweis (immer als neue Zeile).
CREATE OR REPLACE FUNCTION public.record_consent(
  p_type text,
  p_granted boolean,
  p_source text DEFAULT 'settings',
  p_policy_version text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public' AS $$
DECLARE me uuid;
BEGIN
  me := auth.uid();
  IF me IS NULL THEN
    RAISE EXCEPTION 'auth required' USING errcode = 'insufficient_privilege';
  END IF;
  INSERT INTO public.consents(user_id, consent_type, granted, source, policy_version)
  VALUES (me, p_type, p_granted, p_source, p_policy_version);
END $$;
REVOKE ALL ON FUNCTION public.record_consent(text, boolean, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.record_consent(text, boolean, text, text) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- P0 #5: Recht auf Löschung — FK-Referenzen auf auth.users, die bisher
-- KEIN ON DELETE hatten (NO ACTION). Folge: delete_my_account schlug fehl,
-- sobald der Nutzer z.B. ein Match abgelehnt (matches.declined_by) oder einen
-- Live-Raum gehostet hatte (live_rooms.host_id NOT NULL). Fix:
--   • Moderations-/Audit-Felder → ON DELETE SET NULL (Aktion bleibt, PII weg)
--   • eigene Inhalte (live_rooms.host_id) → ON DELETE CASCADE
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.crises DROP CONSTRAINT IF EXISTS crises_verified_by_fkey;
ALTER TABLE public.crises ADD CONSTRAINT crises_verified_by_fkey
  FOREIGN KEY (verified_by) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.crises DROP CONSTRAINT IF EXISTS crises_resolved_by_fkey;
ALTER TABLE public.crises ADD CONSTRAINT crises_resolved_by_fkey
  FOREIGN KEY (resolved_by) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.crises DROP CONSTRAINT IF EXISTS crises_false_alarm_by_fkey;
ALTER TABLE public.crises ADD CONSTRAINT crises_false_alarm_by_fkey
  FOREIGN KEY (false_alarm_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.matches DROP CONSTRAINT IF EXISTS matches_declined_by_fkey;
ALTER TABLE public.matches ADD CONSTRAINT matches_declined_by_fkey
  FOREIGN KEY (declined_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- reports.reviewed_by (Moderator, der den Report bearbeitet hat).
ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_reviewed_by_fkey;
ALTER TABLE public.reports ADD CONSTRAINT reports_reviewed_by_fkey
  FOREIGN KEY (reviewed_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- live_rooms.host_id ist NOT NULL → CASCADE (Räume des Hosts gehen mit).
ALTER TABLE public.live_rooms DROP CONSTRAINT IF EXISTS live_rooms_host_id_fkey;
ALTER TABLE public.live_rooms ADD CONSTRAINT live_rooms_host_id_fkey
  FOREIGN KEY (host_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- audit_logs.actor_id ist NOT NULL → NOT NULL droppen + SET NULL
-- (Moderations-Log bleibt erhalten, Akteur wird anonymisiert).
ALTER TABLE public.audit_logs ALTER COLUMN actor_id DROP NOT NULL;
ALTER TABLE public.audit_logs DROP CONSTRAINT IF EXISTS audit_logs_actor_id_fkey;
ALTER TABLE public.audit_logs ADD CONSTRAINT audit_logs_actor_id_fkey
  FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- ─────────────────────────────────────────────────────────────────────────
-- P0 #5/#6: delete_my_account robuster — Storage-Objekte + unsichere Tabellen
-- explizit bereinigen, danach auth.users löschen (CASCADE für den Rest).
-- (plpgsql bindet Tabellen erst zur Laufzeit → Referenzen auf evtl. nur in
--  Prod existierende Tabellen brechen die Migration nicht.)
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'storage'
AS $$
DECLARE
  me uuid;
BEGIN
  me := auth.uid();
  IF me IS NULL THEN
    RAISE EXCEPTION 'auth required' USING errcode = 'insufficient_privilege';
  END IF;

  -- 1) Storage: alle vom Nutzer hochgeladenen Objekte (alle Buckets via owner).
  BEGIN
    DELETE FROM storage.objects WHERE owner = me;
  EXCEPTION WHEN OTHERS THEN
    NULL; -- Storage-Cleanup darf die Konto-Löschung nicht blockieren
  END;

  -- 2) Tabellen ohne sichere CASCADE/manuell angelegt → explizit entfernen.
  BEGIN DELETE FROM public.ai_chat_feedback   WHERE user_id = me; EXCEPTION WHEN undefined_table THEN NULL; END;
  BEGIN DELETE FROM public.ai_chat_analytics  WHERE user_id = me; EXCEPTION WHEN undefined_table THEN NULL; END;

  -- 3) Lösch-Request + auth.users (CASCADE entfernt den Rest).
  DELETE FROM public.account_deletion_requests WHERE user_id = me;
  DELETE FROM auth.users WHERE id = me;
END;
$$;
REVOKE ALL ON FUNCTION public.delete_my_account() FROM public;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- P1 #8: audit_logs IP-Anonymisierung (letztes IPv4-Oktett auf 0) bei INSERT.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.mask_audit_ip()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.ip_address IS NOT NULL THEN
    NEW.ip_address := regexp_replace(
      NEW.ip_address, '^(\d+)\.(\d+)\.(\d+)\.\d+', '\1.\2.\3.0');
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_mask_audit_ip ON public.audit_logs;
CREATE TRIGGER trg_mask_audit_ip
  BEFORE INSERT ON public.audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.mask_audit_ip();

-- ─────────────────────────────────────────────────────────────────────────
-- P0 #4: Standort-Datensparsamkeit — get_nearby_posts gibt nur noch GROBE
-- Koordinaten (~1,1 km, 2 Nachkommastellen) aus statt exakter GPS-Position.
-- (Distanzberechnung weiterhin auf Basis der exakten geog-Spalte/Index.)
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_nearby_posts(
  p_lat double precision,
  p_lng double precision,
  p_radius_km integer DEFAULT 10,
  p_limit integer DEFAULT 10
)
RETURNS SETOF json
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT row_to_json(t) FROM (
    SELECT
      p.id,
      p.title,
      p.description,
      p.type,
      p.category,
      p.status,
      p.urgency,
      ROUND(p.latitude::numeric, 2)::double precision  AS latitude,
      ROUND(p.longitude::numeric, 2)::double precision AS longitude,
      p.location_text,
      p.created_at,
      p.user_id,
      pr.name       AS author_name,
      pr.avatar_url AS author_avatar,
      ROUND(
        (ST_Distance(
           p.geog,
           ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
         ) / 1000.0)::numeric, 1
      ) AS distance_km
    FROM posts p
    LEFT JOIN profiles pr ON pr.id = p.user_id
    WHERE p.status = 'active'
      AND p.geog IS NOT NULL
      AND ST_DWithin(
            p.geog,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
            p_radius_km * 1000.0
          )
    ORDER BY p.geog <-> ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
    LIMIT p_limit
  ) t;
$$;
