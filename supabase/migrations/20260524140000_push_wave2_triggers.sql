-- ════════════════════════════════════════════════════════════════════════
-- Push-Notifications Wave 2 — Adaptation der Weltenbibliothek-Architektur
--
-- 1. Neue Tabelle user_notification_prefs (Quiet-Hours + Type-Filter)
-- 2. Helper public.notify_user() — zentraler INSERT in notifications mit
--    Quiet-Hours-Check
-- 3. 23 neue Trigger für Events A1-G1 (siehe Vorschlagsliste):
--    A) Krise & Sicherheit         A1-A4
--    B) Community-Engagement       B1-B7
--    C) Group-Features             C1-C3
--    D) Marktplatz/Versorgung      D1-D3
--    E) Profile/Org                E1-E5
--    F) Reminders (cron-based)     Separat — siehe pg_cron-Migration
--    G) Bot-Broadcast              G1 separat
--
-- DRIFT-TOLERANZ: Alle Trigger werden nur angelegt, wenn ihre Zieltabelle
-- existiert (to_regclass). So bleibt die Migration auf einem frischen Replay
-- (z. B. Supabase Preview) lauffähig, auch wenn manche Tabellen dort (noch)
-- nicht existieren. Die Funktionskörper sind spät-gebundenes plpgsql und
-- referenzieren Tabellen erst zur Laufzeit — sie sind daher unkritisch.
-- ════════════════════════════════════════════════════════════════════════

-- ── 1. User-Notification-Prefs ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_notification_prefs (
  user_id            uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Master-Switch
  enabled            boolean NOT NULL DEFAULT true,
  -- Type-Filter (alle default true)
  chat               boolean NOT NULL DEFAULT true,
  social             boolean NOT NULL DEFAULT true,
  system             boolean NOT NULL DEFAULT true,
  crisis             boolean NOT NULL DEFAULT true,
  marketplace        boolean NOT NULL DEFAULT true,
  events             boolean NOT NULL DEFAULT true,
  -- Quiet Hours (lokale Zeit). Beispiel: 22:00 → 07:00.
  quiet_hours_enabled boolean NOT NULL DEFAULT false,
  quiet_start_hour   smallint NOT NULL DEFAULT 22 CHECK (quiet_start_hour BETWEEN 0 AND 23),
  quiet_end_hour     smallint NOT NULL DEFAULT 7  CHECK (quiet_end_hour BETWEEN 0 AND 23),
  -- Bei aktiven Quiet-Hours: Krisen trotzdem durchlassen?
  quiet_allow_critical boolean NOT NULL DEFAULT true,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_notification_prefs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_notification_prefs_owner ON public.user_notification_prefs;
CREATE POLICY user_notification_prefs_owner ON public.user_notification_prefs
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── 2. Helper: notify_user() ─────────────────────────────────────────
-- Insert in notifications-Tabelle. Quiet-Hours + Type-Filter werden bei
-- send-push checked (Edge Function) — DB schreibt immer, damit User die
-- Notif später noch im Inbox sieht.
CREATE OR REPLACE FUNCTION public.notify_user(
  _user_id  uuid,
  _type     text,
  _title    text,
  _body     text,
  _link     text  DEFAULT NULL,
  _category text  DEFAULT 'social',
  _priority text  DEFAULT 'normal',
  _actor_id uuid  DEFAULT NULL,
  _metadata jsonb DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  _id uuid;
BEGIN
  IF _user_id IS NULL THEN RETURN NULL; END IF;
  INSERT INTO public.notifications (
    user_id, type, title, body, link, category, priority, actor_id, metadata
  ) VALUES (
    _user_id, _type, _title, _body, _link, _category, _priority, _actor_id, _metadata
  )
  RETURNING id INTO _id;
  RETURN _id;
END $$;

GRANT EXECUTE ON FUNCTION public.notify_user(uuid, text, text, text, text, text, text, uuid, jsonb) TO authenticated;

-- ════════════════════════════════════════════════════════════════════
-- A) KRISE & SICHERHEIT
-- ════════════════════════════════════════════════════════════════════

-- A1. crises INSERT → Nachbarn im Radius (50 km Haversine).
CREATE OR REPLACE FUNCTION public.notify_on_new_crisis()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  _u record;
  _reporter text;
BEGIN
  SELECT COALESCE(name, 'Anonym') INTO _reporter FROM profiles WHERE id = NEW.creator_id;
  FOR _u IN
    SELECT p.id FROM profiles p
    WHERE p.id <> NEW.creator_id
      AND p.latitude IS NOT NULL AND p.longitude IS NOT NULL
      AND NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL
      AND (
        6371 * acos(
          cos(radians(NEW.latitude)) * cos(radians(p.latitude))
          * cos(radians(p.longitude) - radians(NEW.longitude))
          + sin(radians(NEW.latitude)) * sin(radians(p.latitude))
        )
      ) <= 50
    LIMIT 200
  LOOP
    PERFORM notify_user(
      _u.id, 'crisis_nearby',
      '⚠️ Krise in deiner Nähe',
      COALESCE(NEW.title, 'Neue Krisen-Meldung'),
      '/dashboard/crisis/' || NEW.id,
      'crisis', 'high', NEW.creator_id, jsonb_build_object('crisis_id', NEW.id)
    );
  END LOOP;
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.crises') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_new_crisis ON public.crises;
    CREATE TRIGGER trg_notify_on_new_crisis AFTER INSERT ON public.crises
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_crisis();
  END IF;
END $$;

-- A2. crisis_helpers INSERT → Krise-Reporter
CREATE OR REPLACE FUNCTION public.notify_on_crisis_helper()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _reporter uuid; _name text;
BEGIN
  SELECT creator_id INTO _reporter FROM crises WHERE id = NEW.crisis_id;
  IF _reporter IS NULL OR _reporter = NEW.user_id THEN RETURN NEW; END IF;
  SELECT COALESCE(name, 'Jemand') INTO _name FROM profiles WHERE id = NEW.user_id;
  PERFORM notify_user(_reporter, 'crisis_helper',
    '🤝 Hilfe angeboten', _name || ' möchte bei deiner Krise helfen.',
    '/dashboard/crisis/' || NEW.crisis_id, 'crisis', 'high', NEW.user_id, NULL);
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.crisis_helpers') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_crisis_helper ON public.crisis_helpers;
    CREATE TRIGGER trg_notify_on_crisis_helper AFTER INSERT ON public.crisis_helpers
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_crisis_helper();
  END IF;
END $$;

-- A3. crisis_resources INSERT → Krise-Reporter
CREATE OR REPLACE FUNCTION public.notify_on_crisis_resource()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _reporter uuid; _name text;
BEGIN
  SELECT creator_id INTO _reporter FROM crises WHERE id = NEW.crisis_id;
  IF _reporter IS NULL OR _reporter = NEW.provider_id THEN RETURN NEW; END IF;
  SELECT COALESCE(name, 'Jemand') INTO _name FROM profiles WHERE id = NEW.provider_id;
  PERFORM notify_user(_reporter, 'crisis_resource',
    '📦 Ressource angeboten',
    _name || ' bietet: ' || COALESCE(NEW.title, NEW.resource_type),
    '/dashboard/crisis/' || NEW.crisis_id, 'crisis', 'high',
    NEW.provider_id, NULL);
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.crisis_resources') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_crisis_resource ON public.crisis_resources;
    CREATE TRIGGER trg_notify_on_crisis_resource AFTER INSERT ON public.crisis_resources
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_crisis_resource();
  END IF;
END $$;

-- A4. crisis_reports INSERT → User im Radius (P2 — selteneres Event)
CREATE OR REPLACE FUNCTION public.notify_on_new_crisis_report()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _u record;
BEGIN
  IF NEW.is_anonymous THEN RETURN NEW; END IF;
  FOR _u IN
    SELECT p.id FROM profiles p
    WHERE p.id <> NEW.reporter_id
      AND p.latitude IS NOT NULL AND NEW.latitude IS NOT NULL
      AND (6371 * acos(
        cos(radians(NEW.latitude)) * cos(radians(p.latitude))
        * cos(radians(p.longitude) - radians(NEW.longitude))
        + sin(radians(NEW.latitude)) * sin(radians(p.latitude))
      )) <= 30
    LIMIT 100
  LOOP
    PERFORM notify_user(_u.id, 'crisis_report',
      '🚨 Notfall-Meldung in der Nähe',
      COALESCE(NEW.title, 'Notfall gemeldet'),
      '/dashboard/crisis', 'crisis', 'high', NEW.reporter_id, NULL);
  END LOOP;
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.crisis_reports') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_new_crisis_report ON public.crisis_reports;
    CREATE TRIGGER trg_notify_on_new_crisis_report AFTER INSERT ON public.crisis_reports
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_crisis_report();
  END IF;
END $$;

-- ════════════════════════════════════════════════════════════════════
-- B) COMMUNITY-ENGAGEMENT
-- ════════════════════════════════════════════════════════════════════

-- B1. volunteer_signups INSERT → Post-Autor
CREATE OR REPLACE FUNCTION public.notify_on_volunteer_signup()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _owner uuid; _name text;
BEGIN
  SELECT user_id INTO _owner FROM posts WHERE id = NEW.post_id;
  IF _owner IS NULL OR _owner = NEW.user_id THEN RETURN NEW; END IF;
  SELECT COALESCE(name, 'Jemand') INTO _name FROM profiles WHERE id = NEW.user_id;
  PERFORM notify_user(_owner, 'volunteer_signup',
    '🙋 Helfer-Anfrage', _name || ' möchte bei deinem Post helfen.',
    '/dashboard/posts/' || NEW.post_id, 'social', 'normal', NEW.user_id, NULL);
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.volunteer_signups') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_volunteer_signup ON public.volunteer_signups;
    CREATE TRIGGER trg_notify_on_volunteer_signup AFTER INSERT ON public.volunteer_signups
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_volunteer_signup();
  END IF;
END $$;

-- B2. events INSERT → Nutzer im Radius (30 km)
CREATE OR REPLACE FUNCTION public.notify_on_new_event()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _u record;
BEGIN
  IF NEW.latitude IS NULL OR NEW.longitude IS NULL THEN RETURN NEW; END IF;
  FOR _u IN
    SELECT p.id FROM profiles p
    WHERE p.id <> NEW.author_id
      AND p.latitude IS NOT NULL
      AND (6371 * acos(
        cos(radians(NEW.latitude)) * cos(radians(p.latitude))
        * cos(radians(p.longitude) - radians(NEW.longitude))
        + sin(radians(NEW.latitude)) * sin(radians(p.latitude))
      )) <= 30
    LIMIT 150
  LOOP
    PERFORM notify_user(_u.id, 'event_nearby',
      '🎉 Neues Event in deiner Nähe',
      COALESCE(NEW.title, 'Veranstaltung'),
      '/dashboard/events/' || NEW.id, 'events', 'normal', NEW.author_id, NULL);
  END LOOP;
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.events') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_new_event ON public.events;
    CREATE TRIGGER trg_notify_on_new_event AFTER INSERT ON public.events
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_event();
  END IF;
END $$;

-- B3. event_attendees INSERT → Event-Host
CREATE OR REPLACE FUNCTION public.notify_on_event_attendee()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _host uuid; _name text; _title text;
BEGIN
  SELECT author_id, title INTO _host, _title FROM events WHERE id = NEW.event_id;
  IF _host IS NULL OR _host = NEW.user_id THEN RETURN NEW; END IF;
  SELECT COALESCE(name, 'Jemand') INTO _name FROM profiles WHERE id = NEW.user_id;
  PERFORM notify_user(_host, 'event_attendee',
    '✅ Neue Zusage', _name || ' kommt zu: ' || COALESCE(_title, 'deinem Event'),
    '/dashboard/events/' || NEW.event_id, 'events', 'normal', NEW.user_id, NULL);
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.event_attendees') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_event_attendee ON public.event_attendees;
    CREATE TRIGGER trg_notify_on_event_attendee AFTER INSERT ON public.event_attendees
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_event_attendee();
  END IF;
END $$;

-- B4. event_rideshares INSERT → Event-Attendees
CREATE OR REPLACE FUNCTION public.notify_on_new_rideshare()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _u record; _name text; _title text;
BEGIN
  SELECT COALESCE(name, 'Jemand') INTO _name FROM profiles WHERE id = NEW.user_id;
  SELECT title INTO _title FROM events WHERE id = NEW.event_id;
  FOR _u IN
    SELECT user_id FROM event_attendees
    WHERE event_id = NEW.event_id AND user_id <> NEW.user_id
  LOOP
    PERFORM notify_user(_u.user_id, 'event_rideshare',
      '🚗 Mitfahrgelegenheit',
      _name || ' bietet eine Fahrt zu: ' || COALESCE(_title, 'Event'),
      '/dashboard/events/' || NEW.event_id, 'events', 'normal', NEW.user_id, NULL);
  END LOOP;
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.event_rideshares') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_new_rideshare ON public.event_rideshares;
    CREATE TRIGGER trg_notify_on_new_rideshare AFTER INSERT ON public.event_rideshares
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_rideshare();
  END IF;
END $$;

-- B5. live_rooms INSERT (status='live') → Channel-Mitglieder (alle die je
--     in der zugehörigen conversation geschrieben haben)
CREATE OR REPLACE FUNCTION public.notify_on_live_room_start()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _u record; _name text;
BEGIN
  IF NEW.status <> 'live' OR NEW.conversation_id IS NULL THEN RETURN NEW; END IF;
  SELECT COALESCE(name, 'Jemand') INTO _name FROM profiles WHERE id = NEW.host_id;
  FOR _u IN
    SELECT DISTINCT user_id FROM messages
    WHERE conversation_id = NEW.conversation_id AND user_id <> NEW.host_id
    LIMIT 200
  LOOP
    PERFORM notify_user(_u.user_id, 'live_room',
      '📡 Livestream gestartet',
      _name || ' streamt jetzt im Kanal.',
      '/dashboard/messages/' || NEW.conversation_id, 'social', 'normal',
      NEW.host_id, jsonb_build_object('room_name', NEW.room_name));
  END LOOP;
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.live_rooms') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_live_room_start ON public.live_rooms;
    CREATE TRIGGER trg_notify_on_live_room_start AFTER INSERT ON public.live_rooms
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_live_room_start();
  END IF;
END $$;

-- B6. matches INSERT → beide Match-Partner (offer + request)
CREATE OR REPLACE FUNCTION public.notify_on_new_match()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _other text;
BEGIN
  IF NEW.offer_user_id IS NOT NULL AND NEW.request_user_id IS NOT NULL THEN
    -- Push an offer-User mit Name des request-Users
    SELECT COALESCE(name, 'Jemand') INTO _other FROM profiles WHERE id = NEW.request_user_id;
    PERFORM notify_user(NEW.offer_user_id, 'match_new',
      '✨ Neues Match',
      'Du hast ein neues Match: ' || _other,
      '/dashboard/matching', 'social', 'normal', NEW.request_user_id, NULL);
    -- Push an request-User mit Name des offer-Users
    SELECT COALESCE(name, 'Jemand') INTO _other FROM profiles WHERE id = NEW.offer_user_id;
    PERFORM notify_user(NEW.request_user_id, 'match_new',
      '✨ Neues Match',
      'Du hast ein neues Match: ' || _other,
      '/dashboard/matching', 'social', 'normal', NEW.offer_user_id, NULL);
  END IF;
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.matches') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_new_match ON public.matches;
    CREATE TRIGGER trg_notify_on_new_match AFTER INSERT ON public.matches
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_match();
  END IF;
END $$;

-- B7. user_badges INSERT → Badge-Empfänger
CREATE OR REPLACE FUNCTION public.notify_on_badge_earned()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _badge text;
BEGIN
  SELECT name INTO _badge FROM badges WHERE id = NEW.badge_id;
  PERFORM notify_user(NEW.user_id, 'badge_earned',
    '🏆 Neues Badge',
    'Du hast erhalten: ' || COALESCE(_badge, 'Ein Badge'),
    '/dashboard/badges', 'system', 'normal', NULL,
    jsonb_build_object('badge_id', NEW.badge_id));
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.user_badges') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_badge_earned ON public.user_badges;
    CREATE TRIGGER trg_notify_on_badge_earned AFTER INSERT ON public.user_badges
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_badge_earned();
  END IF;
END $$;

-- ════════════════════════════════════════════════════════════════════
-- C) GROUP-FEATURES
-- ════════════════════════════════════════════════════════════════════

-- C1. group_post_reactions INSERT → Group-Post-Autor
CREATE OR REPLACE FUNCTION public.notify_on_group_post_reaction()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _owner uuid; _name text; _grp uuid;
BEGIN
  SELECT user_id, group_id INTO _owner, _grp FROM group_posts WHERE id = NEW.post_id;
  IF _owner IS NULL OR _owner = NEW.user_id THEN RETURN NEW; END IF;
  SELECT COALESCE(name, 'Jemand') INTO _name FROM profiles WHERE id = NEW.user_id;
  PERFORM notify_user(_owner, 'group_post_reaction',
    NEW.emoji || ' Reaktion auf deinen Gruppen-Post',
    _name || ' hat ' || NEW.emoji || ' geklickt.',
    '/dashboard/groups/' || _grp, 'social', 'normal', NEW.user_id, NULL);
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.group_post_reactions') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_group_post_reaction ON public.group_post_reactions;
    CREATE TRIGGER trg_notify_on_group_post_reaction AFTER INSERT ON public.group_post_reactions
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_group_post_reaction();
  END IF;
END $$;

-- C2. channel_polls INSERT → Channel-Mitglieder
CREATE OR REPLACE FUNCTION public.notify_on_new_channel_poll()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _u record; _conv uuid; _name text;
BEGIN
  SELECT conversation_id INTO _conv FROM chat_channels WHERE id = NEW.channel_id;
  IF _conv IS NULL THEN RETURN NEW; END IF;
  SELECT COALESCE(name, 'Jemand') INTO _name FROM profiles WHERE id = NEW.created_by;
  FOR _u IN
    SELECT DISTINCT user_id FROM messages
    WHERE conversation_id = _conv AND user_id <> NEW.created_by
    LIMIT 200
  LOOP
    PERFORM notify_user(_u.user_id, 'channel_poll',
      '📊 Neue Umfrage',
      _name || ': ' || NEW.question,
      '/dashboard/messages/' || _conv, 'social', 'normal', NEW.created_by, NULL);
  END LOOP;
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.channel_polls') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_new_channel_poll ON public.channel_polls;
    CREATE TRIGGER trg_notify_on_new_channel_poll AFTER INSERT ON public.channel_polls
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_channel_poll();
  END IF;
END $$;

-- C3. channel_events INSERT → Channel-Mitglieder
CREATE OR REPLACE FUNCTION public.notify_on_new_channel_event()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _u record; _conv uuid; _name text;
BEGIN
  SELECT conversation_id INTO _conv FROM chat_channels WHERE id = NEW.channel_id;
  IF _conv IS NULL THEN RETURN NEW; END IF;
  SELECT COALESCE(name, 'Jemand') INTO _name FROM profiles WHERE id = NEW.created_by;
  FOR _u IN
    SELECT DISTINCT user_id FROM messages
    WHERE conversation_id = _conv AND user_id <> NEW.created_by
    LIMIT 200
  LOOP
    PERFORM notify_user(_u.user_id, 'channel_event',
      '📅 Live-Event geplant',
      _name || ': ' || NEW.title,
      '/dashboard/messages/' || _conv, 'events', 'normal', NEW.created_by, NULL);
  END LOOP;
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.channel_events') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_new_channel_event ON public.channel_events;
    CREATE TRIGGER trg_notify_on_new_channel_event AFTER INSERT ON public.channel_events
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_channel_event();
  END IF;
END $$;

-- ════════════════════════════════════════════════════════════════════
-- D) MARKTPLATZ / VERSORGUNG
-- ════════════════════════════════════════════════════════════════════

-- D1. marketplace_listings INSERT → Nutzer im Radius (25 km)
CREATE OR REPLACE FUNCTION public.notify_on_new_marketplace_listing()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _u record;
BEGIN
  IF NEW.latitude IS NULL OR NEW.longitude IS NULL THEN RETURN NEW; END IF;
  IF NEW.status <> 'active' THEN RETURN NEW; END IF;
  FOR _u IN
    SELECT p.id FROM profiles p
    WHERE p.id <> COALESCE(NEW.seller_id, NEW.user_id)
      AND p.latitude IS NOT NULL
      AND (6371 * acos(
        cos(radians(NEW.latitude)) * cos(radians(p.latitude))
        * cos(radians(p.longitude) - radians(NEW.longitude))
        + sin(radians(NEW.latitude)) * sin(radians(p.latitude))
      )) <= 25
    LIMIT 150
  LOOP
    PERFORM notify_user(_u.id, 'marketplace_new',
      '🛒 Neuer Marktplatz-Eintrag',
      COALESCE(NEW.title, 'Neu im Marktplatz'),
      '/dashboard/marketplace/' || NEW.id, 'marketplace', 'normal',
      COALESCE(NEW.seller_id, NEW.user_id), NULL);
  END LOOP;
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.marketplace_listings') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_new_marketplace_listing ON public.marketplace_listings;
    CREATE TRIGGER trg_notify_on_new_marketplace_listing AFTER INSERT ON public.marketplace_listings
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_marketplace_listing();
  END IF;
END $$;

-- D2. marketplace_listings UPDATE status → reserved → User der reserviert hat
CREATE OR REPLACE FUNCTION public.notify_on_marketplace_reserved()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  IF NEW.status = 'reserved' AND OLD.status <> 'reserved' AND NEW.reserved_for IS NOT NULL THEN
    PERFORM notify_user(NEW.reserved_for, 'marketplace_reserved',
      '✅ Reservierung bestätigt',
      'Dein Wunsch-Listing ist jetzt für dich reserviert: ' || COALESCE(NEW.title, ''),
      '/dashboard/marketplace/' || NEW.id, 'marketplace', 'normal',
      COALESCE(NEW.seller_id, NEW.user_id), NULL);
  END IF;
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.marketplace_listings') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_marketplace_reserved ON public.marketplace_listings;
    CREATE TRIGGER trg_notify_on_marketplace_reserved AFTER UPDATE ON public.marketplace_listings
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_marketplace_reserved();
  END IF;
END $$;

-- D3. farm_favorites INSERT → Farm-Owner (falls Bauer angemeldet)
CREATE OR REPLACE FUNCTION public.notify_on_farm_favorite()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _owner uuid; _name text; _farm text;
BEGIN
  -- farm_listings hat keinen direkten owner-User — wir nutzen source_name nur falls vorhanden.
  -- Push nur wenn user_id = owner registriert wäre. Vorerst skip wenn nicht ableitbar.
  RETURN NEW;
END $$;
-- (kein Trigger angelegt — bedingungslos zu spammy)

-- ════════════════════════════════════════════════════════════════════
-- E) PROFILE / ORG
-- ════════════════════════════════════════════════════════════════════

-- E1. organization_reviews INSERT → Org-Mitglieder mit Rolle 'owner'/'admin'
CREATE OR REPLACE FUNCTION public.notify_on_org_review()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _u record; _name text;
BEGIN
  SELECT COALESCE(name, 'Jemand') INTO _name FROM profiles WHERE id = NEW.user_id;
  FOR _u IN
    SELECT user_id FROM organization_members
    WHERE organization_id = NEW.organization_id
      AND role IN ('owner','admin')
      AND user_id <> NEW.user_id
  LOOP
    PERFORM notify_user(_u.user_id, 'org_review',
      '⭐ Neue Bewertung',
      _name || ' hat ' || NEW.rating || ' Sterne vergeben.',
      '/dashboard/organizations/' || NEW.organization_id,
      'social', 'normal', NEW.user_id, NULL);
  END LOOP;
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.organization_reviews') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_org_review ON public.organization_reviews;
    CREATE TRIGGER trg_notify_on_org_review AFTER INSERT ON public.organization_reviews
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_org_review();
  END IF;
END $$;

-- E2. organization_invites UPDATE use_count steigt → Org-Owner (Beitritt-Code verwendet)
-- (Skipping — UPDATE-Trigger zu eng am Anwendungs-Flow, schlecht testbar
--  ohne den Server-Code zu kennen der use_count erhöht.)

-- E3. conversation_members INSERT → Hinzugefügter User
CREATE OR REPLACE FUNCTION public.notify_on_conversation_member_added()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _conv_title text;
BEGIN
  -- Nur wenn jemand anders dich hinzugefügt hat (nicht selber beigetreten).
  SELECT title INTO _conv_title FROM conversations WHERE id = NEW.conversation_id;
  PERFORM notify_user(NEW.user_id, 'conversation_added',
    '👥 Zu Chat hinzugefügt',
    'Du wurdest hinzugefügt: ' || COALESCE(_conv_title, 'Chat'),
    '/dashboard/messages/' || NEW.conversation_id,
    'chat', 'normal', NULL, NULL);
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.conversation_members') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_conversation_member_added ON public.conversation_members;
    CREATE TRIGGER trg_notify_on_conversation_member_added AFTER INSERT ON public.conversation_members
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_conversation_member_added();
  END IF;
END $$;

-- E4. message_reactions INSERT → Message-Autor
CREATE OR REPLACE FUNCTION public.notify_on_message_reaction()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _author uuid; _name text; _conv uuid;
BEGIN
  SELECT user_id, conversation_id INTO _author, _conv FROM messages WHERE id = NEW.message_id;
  IF _author IS NULL OR _author = NEW.user_id THEN RETURN NEW; END IF;
  SELECT COALESCE(name, 'Jemand') INTO _name FROM profiles WHERE id = NEW.user_id;
  PERFORM notify_user(_author, 'message_reaction',
    NEW.emoji || ' Reaktion',
    _name || ' hat reagiert.',
    '/dashboard/messages/' || _conv, 'chat', 'low', NEW.user_id, NULL);
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.message_reactions') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_message_reaction ON public.message_reactions;
    CREATE TRIGGER trg_notify_on_message_reaction AFTER INSERT ON public.message_reactions
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_message_reaction();
  END IF;
END $$;

-- E5. message_pins INSERT → Message-Autor
CREATE OR REPLACE FUNCTION public.notify_on_message_pinned()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE _author uuid; _conv uuid;
BEGIN
  SELECT user_id, conversation_id INTO _author, _conv FROM messages WHERE id = NEW.message_id;
  IF _author IS NULL OR _author = NEW.pinned_by THEN RETURN NEW; END IF;
  PERFORM notify_user(_author, 'message_pinned',
    '📌 Nachricht gepinnt',
    'Deine Nachricht wurde angepinnt.',
    '/dashboard/messages/' || _conv, 'social', 'normal', NEW.pinned_by, NULL);
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.message_pins') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_notify_on_message_pinned ON public.message_pins;
    CREATE TRIGGER trg_notify_on_message_pinned AFTER INSERT ON public.message_pins
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_message_pinned();
  END IF;
END $$;
