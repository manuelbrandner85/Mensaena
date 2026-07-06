-- [Security] Post-Kontaktdaten: Freigabe-Prüfung serverseitig erzwingen.
--
-- Root-Cause: post_contact_preferences enthält sensible Klartext-Kontaktfelder
-- (phone_number, email_address, whatsapp_number). Die bisherige Freigabe-Prüfung
-- (R7) lief NUR im Client (post_contact_repository.getRevealedContactInfo):
-- erst wurde die volle Zeile per Direkt-Select geladen, dann client-seitig
-- geprüft, ob eine akzeptierte Anfrage existiert. Wer die RLS-SELECT-Policy
-- passiert, konnte die sensiblen Felder also trotzdem über die API auslesen,
-- ohne je eine akzeptierte Kontaktanfrage zu haben.
--
-- Fix (belt & suspenders):
--   1) RLS verschärfen: Direkt-SELECT auf post_contact_preferences NUR für den
--      Owner. Fremde bekommen die Zeile (und damit die sensiblen Felder) per
--      Direkt-Select gar nicht mehr.
--   2) SECURITY-DEFINER-RPC get_revealed_contact_info(post_id): führt die
--      Owner/accepted-Prüfung in SQL aus und liefert die sensiblen Felder nur,
--      wenn der Aufrufer Owner ist ODER eine status='accepted'-Anfrage hat.
--   3) SECURITY-DEFINER-RPC get_post_contact_meta(post_id): liefert die
--      NICHT-sensiblen Metadaten (allow_*-Flags, Verfügbarkeit, Notizen) für
--      jeden angemeldeten Nutzer, damit die Kontakt-CTA weiter gerendert werden
--      kann — OHNE Telefon/E-Mail/WhatsApp preiszugeben.
--
-- Idempotent: alle Statements sind wiederholbar (IF EXISTS / CREATE OR REPLACE).

-- ---------------------------------------------------------------------------
-- 1) RLS aktivieren + alle bestehenden Policies neu setzen
-- ---------------------------------------------------------------------------
ALTER TABLE public.post_contact_preferences ENABLE ROW LEVEL SECURITY;

-- Bestehende Policies (ggf. manuell im Dashboard angelegt, unbekannte Namen)
-- deterministisch entfernen, damit keine zu großzügige SELECT-Policy überlebt.
DO $$
DECLARE pol record;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'post_contact_preferences'
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON public.post_contact_preferences', pol.policyname);
  END LOOP;
END $$;

-- Direkt-SELECT nur für den Owner (sensible Felder für Fremde nicht lesbar).
CREATE POLICY "pcp_owner_select" ON public.post_contact_preferences
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Owner darf eigene Prefs anlegen/ändern/löschen.
CREATE POLICY "pcp_owner_insert" ON public.post_contact_preferences
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "pcp_owner_update" ON public.post_contact_preferences
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "pcp_owner_delete" ON public.post_contact_preferences
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 2) Reveal-RPC: sensible Kontaktfelder nur bei Owner ODER accepted-Anfrage
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_revealed_contact_info(p_post_id uuid)
RETURNS TABLE (
  id                    uuid,
  post_id               uuid,
  user_id               uuid,
  allow_in_app_chat     boolean,
  allow_phone           boolean,
  allow_email           boolean,
  allow_whatsapp        boolean,
  allow_location_meetup boolean,
  phone_number          text,
  email_address         text,
  whatsapp_number       text,
  meetup_note           text,
  available_from        time,
  available_until       time,
  available_days        text[],
  contact_note          text
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT
    p.id, p.post_id, p.user_id,
    p.allow_in_app_chat, p.allow_phone, p.allow_email,
    p.allow_whatsapp, p.allow_location_meetup,
    p.phone_number, p.email_address, p.whatsapp_number, p.meetup_note,
    p.available_from, p.available_until, p.available_days, p.contact_note
  FROM public.post_contact_preferences p
  WHERE p.post_id = p_post_id
    AND (
      p.user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.post_contact_requests r
        WHERE r.post_id = p_post_id
          AND r.requester_id = auth.uid()
          AND r.status = 'accepted'
      )
    );
$$;

REVOKE ALL ON FUNCTION public.get_revealed_contact_info(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.get_revealed_contact_info(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3) Meta-RPC: nicht-sensible Kontakt-Metadaten für alle angemeldeten Nutzer
--    (bewusst OHNE phone_number/email_address/whatsapp_number)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_post_contact_meta(p_post_id uuid)
RETURNS TABLE (
  id                    uuid,
  post_id               uuid,
  user_id               uuid,
  allow_in_app_chat     boolean,
  allow_phone           boolean,
  allow_email           boolean,
  allow_whatsapp        boolean,
  allow_location_meetup boolean,
  meetup_note           text,
  available_from        time,
  available_until       time,
  available_days        text[],
  contact_note          text
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT
    p.id, p.post_id, p.user_id,
    p.allow_in_app_chat, p.allow_phone, p.allow_email,
    p.allow_whatsapp, p.allow_location_meetup,
    p.meetup_note, p.available_from, p.available_until,
    p.available_days, p.contact_note
  FROM public.post_contact_preferences p
  WHERE p.post_id = p_post_id;
$$;

REVOKE ALL ON FUNCTION public.get_post_contact_meta(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.get_post_contact_meta(uuid) TO authenticated;
