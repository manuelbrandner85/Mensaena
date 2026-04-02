-- ============================================================
-- MENSAENA – Migration 008: Fehlende Tabellen
-- Enthält alle Tabellen die noch nicht in der DB existieren:
--   1.  organizations        – Hilfsorganisationen DE/AT/CH
--   2.  push_subscriptions   – Web Push Benachrichtigungen
--   3.  user_status          – Online-Status der Nutzer
--   4.  message_reactions    – Emoji-Reaktionen auf Nachrichten
--   5.  message_pins         – Angepinnte Nachrichten
--   6.  chat_announcements   – Admin-Ankündigungen
--   7.  chat_banned_users    – Gebannte Chat-Nutzer
--   8.  post_tags            – Tag-Tabelle für Posts (normalisiert)
--   9.  timebank_entries     – Zeitbank-Stunden-Buchungen
--  10.  knowledge_articles   – Wissens-Artikel / Guides
--  11.  crisis_reports       – Krisenberichte / Notfallmeldungen
--  12.  skill_offers         – Skill-Angebote im Zeitbank-Modul
--  13.  volunteer_signups    – Freiwilligen-Anmeldungen
-- ============================================================

-- Sicherstellen dass uuid-ossp verfügbar ist
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- handle_updated_at Funktion (CREATE OR REPLACE – sicher wenn schon vorhanden)
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- ============================================================
-- 1. TABELLE: organizations
-- ============================================================
CREATE TABLE IF NOT EXISTS public.organizations (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name            TEXT NOT NULL,
  category        TEXT NOT NULL DEFAULT 'allgemein' CHECK (category IN (
    'tierheim','tierschutz','suppenkueche','obdachlosenhilfe',
    'tafel','kleiderkammer','sozialkaufhaus','krisentelefon',
    'notschlafstelle','jugend','senioren','behinderung',
    'sucht','fluechtlingshilfe','allgemein'
  )),
  description     TEXT,
  address         TEXT,
  zip_code        TEXT,
  city            TEXT NOT NULL,
  state           TEXT,
  country         TEXT NOT NULL DEFAULT 'DE' CHECK (country IN ('DE','AT','CH')),
  latitude        DOUBLE PRECISION,
  longitude       DOUBLE PRECISION,
  phone           TEXT,
  email           TEXT,
  website         TEXT,
  opening_hours   TEXT,
  services        TEXT[] DEFAULT '{}',
  tags            TEXT[] DEFAULT '{}',
  is_verified     BOOLEAN DEFAULT FALSE,
  is_active       BOOLEAN DEFAULT TRUE,
  source_url      TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

DROP TRIGGER IF EXISTS handle_organizations_updated_at ON public.organizations;
CREATE TRIGGER handle_organizations_updated_at
  BEFORE UPDATE ON public.organizations
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_org_category ON public.organizations(category);
CREATE INDEX IF NOT EXISTS idx_org_city     ON public.organizations(city);
CREATE INDEX IF NOT EXISTS idx_org_country  ON public.organizations(country);
CREATE INDEX IF NOT EXISTS idx_org_active   ON public.organizations(is_active);

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='organizations' AND policyname='organizations_public_read') THEN
    CREATE POLICY "organizations_public_read"
      ON public.organizations FOR SELECT USING (is_active = TRUE);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='organizations' AND policyname='organizations_service_write') THEN
    CREATE POLICY "organizations_service_write"
      ON public.organizations FOR ALL USING (auth.role() = 'service_role');
  END IF;
END $$;

-- ============================================================
-- 2. TABELLE: push_subscriptions
-- ============================================================
CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  endpoint    TEXT NOT NULL UNIQUE,
  p256dh      TEXT NOT NULL,
  auth        TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_push_subs_user ON public.push_subscriptions(user_id);

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='push_subscriptions' AND policyname='push_subs_own') THEN
    CREATE POLICY "push_subs_own"
      ON public.push_subscriptions FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;

-- ============================================================
-- 3. TABELLE: user_status
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_status (
  user_id     UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'offline' CHECK (status IN ('online','away','busy','offline')),
  last_seen   TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE public.user_status ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='user_status' AND policyname='user_status_read') THEN
    CREATE POLICY "user_status_read"
      ON public.user_status FOR SELECT USING (auth.uid() IS NOT NULL);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='user_status' AND policyname='user_status_own_write') THEN
    CREATE POLICY "user_status_own_write"
      ON public.user_status FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;

-- ============================================================
-- 4. TABELLE: message_reactions
-- ============================================================
CREATE TABLE IF NOT EXISTS public.message_reactions (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  message_id  UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  emoji       TEXT NOT NULL CHECK (char_length(emoji) BETWEEN 1 AND 10),
  created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(message_id, user_id, emoji)
);

CREATE INDEX IF NOT EXISTS idx_reactions_msg ON public.message_reactions(message_id);

ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='message_reactions' AND policyname='reactions_read') THEN
    CREATE POLICY "reactions_read"
      ON public.message_reactions FOR SELECT USING (auth.uid() IS NOT NULL);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='message_reactions' AND policyname='reactions_insert') THEN
    CREATE POLICY "reactions_insert"
      ON public.message_reactions FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='message_reactions' AND policyname='reactions_delete') THEN
    CREATE POLICY "reactions_delete"
      ON public.message_reactions FOR DELETE USING (auth.uid() = user_id);
  END IF;
END $$;

-- ============================================================
-- 5. TABELLE: message_pins
-- ============================================================
CREATE TABLE IF NOT EXISTS public.message_pins (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  message_id      UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  pinned_by       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  pinned_at       TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(message_id, conversation_id)
);

CREATE INDEX IF NOT EXISTS idx_pins_conv ON public.message_pins(conversation_id);

ALTER TABLE public.message_pins ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='message_pins' AND policyname='pins_read') THEN
    CREATE POLICY "pins_read"
      ON public.message_pins FOR SELECT USING (auth.uid() IS NOT NULL);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='message_pins' AND policyname='pins_admin_write') THEN
    CREATE POLICY "pins_admin_write"
      ON public.message_pins FOR ALL USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
        OR auth.uid() = pinned_by
      );
  END IF;
END $$;

-- ============================================================
-- 6. TABELLE: chat_announcements
-- ============================================================
CREATE TABLE IF NOT EXISTS public.chat_announcements (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE,
  author_id       UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  title           TEXT NOT NULL,
  content         TEXT NOT NULL,
  type            TEXT DEFAULT 'info' CHECK (type IN ('info','warning','success','error')),
  is_active       BOOLEAN DEFAULT TRUE,
  expires_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_announcements_conv   ON public.chat_announcements(conversation_id);
CREATE INDEX IF NOT EXISTS idx_announcements_active ON public.chat_announcements(is_active);

ALTER TABLE public.chat_announcements ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='chat_announcements' AND policyname='announcements_read') THEN
    CREATE POLICY "announcements_read"
      ON public.chat_announcements FOR SELECT USING (
        is_active = TRUE AND (expires_at IS NULL OR expires_at > NOW())
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='chat_announcements' AND policyname='announcements_admin_write') THEN
    CREATE POLICY "announcements_admin_write"
      ON public.chat_announcements FOR ALL USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
        OR auth.uid() = author_id
      );
  END IF;
END $$;

-- ============================================================
-- 7. TABELLE: chat_banned_users
-- ============================================================
CREATE TABLE IF NOT EXISTS public.chat_banned_users (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  banned_by       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason          TEXT,
  banned_until    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_banned_user ON public.chat_banned_users(user_id);

ALTER TABLE public.chat_banned_users ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='chat_banned_users' AND policyname='banned_admin_read') THEN
    CREATE POLICY "banned_admin_read"
      ON public.chat_banned_users FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
        OR auth.uid() = user_id
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='chat_banned_users' AND policyname='banned_admin_write') THEN
    CREATE POLICY "banned_admin_write"
      ON public.chat_banned_users FOR ALL USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
      );
  END IF;
END $$;

-- ============================================================
-- 8. TABELLE: post_tags
-- ============================================================
CREATE TABLE IF NOT EXISTS public.post_tags (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id    UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  tag        TEXT NOT NULL CHECK (char_length(tag) BETWEEN 2 AND 30),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(post_id, tag)
);

CREATE INDEX IF NOT EXISTS idx_post_tags_post ON public.post_tags(post_id);
CREATE INDEX IF NOT EXISTS idx_post_tags_tag  ON public.post_tags(tag);

ALTER TABLE public.post_tags ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='post_tags' AND policyname='post_tags_read') THEN
    CREATE POLICY "post_tags_read"
      ON public.post_tags FOR SELECT USING (TRUE);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='post_tags' AND policyname='post_tags_write') THEN
    CREATE POLICY "post_tags_write"
      ON public.post_tags FOR INSERT WITH CHECK (
        auth.uid() = (SELECT user_id FROM public.posts WHERE id = post_id)
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='post_tags' AND policyname='post_tags_delete') THEN
    CREATE POLICY "post_tags_delete"
      ON public.post_tags FOR DELETE USING (
        auth.uid() = (SELECT user_id FROM public.posts WHERE id = post_id)
      );
  END IF;
END $$;

-- ============================================================
-- 9. TABELLE: timebank_entries
-- ============================================================
CREATE TABLE IF NOT EXISTS public.timebank_entries (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  giver_id        UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  post_id         UUID REFERENCES public.posts(id) ON DELETE SET NULL,
  hours           NUMERIC(4,1) NOT NULL CHECK (hours > 0 AND hours <= 24),
  description     TEXT NOT NULL,
  category        TEXT DEFAULT 'general' CHECK (category IN (
    'food','everyday','moving','animals','housing',
    'knowledge','skills','mental','mobility','sharing','emergency','general'
  )),
  status          TEXT DEFAULT 'pending' CHECK (status IN ('pending','confirmed','cancelled')),
  confirmed_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_timebank_giver    ON public.timebank_entries(giver_id);
CREATE INDEX IF NOT EXISTS idx_timebank_receiver ON public.timebank_entries(receiver_id);

ALTER TABLE public.timebank_entries ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='timebank_entries' AND policyname='timebank_own_read') THEN
    CREATE POLICY "timebank_own_read"
      ON public.timebank_entries FOR SELECT USING (
        auth.uid() = giver_id OR auth.uid() = receiver_id
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='timebank_entries' AND policyname='timebank_insert') THEN
    CREATE POLICY "timebank_insert"
      ON public.timebank_entries FOR INSERT WITH CHECK (auth.uid() = giver_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='timebank_entries' AND policyname='timebank_receiver_update') THEN
    CREATE POLICY "timebank_receiver_update"
      ON public.timebank_entries FOR UPDATE USING (
        auth.uid() = receiver_id OR auth.uid() = giver_id
      );
  END IF;
END $$;

-- ============================================================
-- 10. TABELLE: knowledge_articles
-- ============================================================
CREATE TABLE IF NOT EXISTS public.knowledge_articles (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title       TEXT NOT NULL CHECK (char_length(title) BETWEEN 5 AND 200),
  slug        TEXT UNIQUE NOT NULL,
  content     TEXT NOT NULL CHECK (char_length(content) >= 50),
  summary     TEXT,
  category    TEXT DEFAULT 'general' CHECK (category IN (
    'food','everyday','moving','animals','housing',
    'knowledge','skills','mental','mobility','sharing','emergency','general'
  )),
  tags        TEXT[] DEFAULT '{}',
  image_url   TEXT,
  views       INTEGER DEFAULT 0,
  is_public   BOOLEAN DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE,
  status      TEXT DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
  published_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

DROP TRIGGER IF EXISTS handle_knowledge_updated_at ON public.knowledge_articles;
CREATE TRIGGER handle_knowledge_updated_at
  BEFORE UPDATE ON public.knowledge_articles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_knowledge_author   ON public.knowledge_articles(author_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_category ON public.knowledge_articles(category);
CREATE INDEX IF NOT EXISTS idx_knowledge_status   ON public.knowledge_articles(status);
CREATE INDEX IF NOT EXISTS idx_knowledge_slug     ON public.knowledge_articles(slug);

ALTER TABLE public.knowledge_articles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='knowledge_articles' AND policyname='knowledge_public_read') THEN
    CREATE POLICY "knowledge_public_read"
      ON public.knowledge_articles FOR SELECT USING (
        (is_public = TRUE AND status = 'published')
        OR auth.uid() = author_id
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='knowledge_articles' AND policyname='knowledge_auth_insert') THEN
    CREATE POLICY "knowledge_auth_insert"
      ON public.knowledge_articles FOR INSERT WITH CHECK (auth.uid() = author_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='knowledge_articles' AND policyname='knowledge_own_update') THEN
    CREATE POLICY "knowledge_own_update"
      ON public.knowledge_articles FOR UPDATE USING (auth.uid() = author_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='knowledge_articles' AND policyname='knowledge_own_delete') THEN
    CREATE POLICY "knowledge_own_delete"
      ON public.knowledge_articles FOR DELETE USING (auth.uid() = author_id);
  END IF;
END $$;

-- ============================================================
-- 11. TABELLE: crisis_reports
-- ============================================================
CREATE TABLE IF NOT EXISTS public.crisis_reports (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  title           TEXT NOT NULL CHECK (char_length(title) BETWEEN 5 AND 200),
  description     TEXT NOT NULL CHECK (char_length(description) >= 20),
  type            TEXT DEFAULT 'general' CHECK (type IN (
    'natural_disaster','accident','missing_person','supply_shortage',
    'infrastructure','health','security','general'
  )),
  severity        TEXT DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  latitude        DOUBLE PRECISION,
  longitude       DOUBLE PRECISION,
  address         TEXT,
  city            TEXT,
  country         TEXT DEFAULT 'DE' CHECK (country IN ('DE','AT','CH')),
  status          TEXT DEFAULT 'active' CHECK (status IN ('active','resolved','archived')),
  contact_phone   TEXT,
  is_anonymous    BOOLEAN DEFAULT FALSE,
  verified        BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

DROP TRIGGER IF EXISTS handle_crisis_updated_at ON public.crisis_reports;
CREATE TRIGGER handle_crisis_updated_at
  BEFORE UPDATE ON public.crisis_reports
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_crisis_status   ON public.crisis_reports(status);
CREATE INDEX IF NOT EXISTS idx_crisis_severity ON public.crisis_reports(severity);
CREATE INDEX IF NOT EXISTS idx_crisis_city     ON public.crisis_reports(city);

ALTER TABLE public.crisis_reports ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='crisis_reports' AND policyname='crisis_public_read') THEN
    CREATE POLICY "crisis_public_read"
      ON public.crisis_reports FOR SELECT USING (status = 'active');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='crisis_reports' AND policyname='crisis_auth_insert') THEN
    CREATE POLICY "crisis_auth_insert"
      ON public.crisis_reports FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='crisis_reports' AND policyname='crisis_own_update') THEN
    CREATE POLICY "crisis_own_update"
      ON public.crisis_reports FOR UPDATE USING (
        auth.uid() = reporter_id
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
      );
  END IF;
END $$;

-- ============================================================
-- 12. TABELLE: skill_offers
-- ============================================================
CREATE TABLE IF NOT EXISTS public.skill_offers (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title           TEXT NOT NULL CHECK (char_length(title) BETWEEN 5 AND 120),
  description     TEXT NOT NULL CHECK (char_length(description) >= 20),
  skill_category  TEXT DEFAULT 'general' CHECK (skill_category IN (
    'handwerk','technik','bildung','gesundheit','sprachen',
    'musik_kunst','sport','kochen','garten','haushalt',
    'transport','beratung','soziales','digital','sonstiges','general'
  )),
  level           TEXT DEFAULT 'intermediate' CHECK (level IN ('beginner','intermediate','advanced','expert')),
  is_free         BOOLEAN DEFAULT TRUE,
  hourly_rate     NUMERIC(6,2),
  currency        TEXT DEFAULT 'EUR' CHECK (currency IN ('EUR','CHF')),
  available_from  DATE,
  available_until DATE,
  max_hours_week  NUMERIC(4,1),
  location_type   TEXT DEFAULT 'both' CHECK (location_type IN ('local','remote','both')),
  city            TEXT,
  country         TEXT DEFAULT 'DE' CHECK (country IN ('DE','AT','CH')),
  tags            TEXT[] DEFAULT '{}',
  status          TEXT DEFAULT 'active' CHECK (status IN ('active','paused','archived')),
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

DROP TRIGGER IF EXISTS handle_skill_offers_updated_at ON public.skill_offers;
CREATE TRIGGER handle_skill_offers_updated_at
  BEFORE UPDATE ON public.skill_offers
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_skill_offers_user     ON public.skill_offers(user_id);
CREATE INDEX IF NOT EXISTS idx_skill_offers_category ON public.skill_offers(skill_category);
CREATE INDEX IF NOT EXISTS idx_skill_offers_status   ON public.skill_offers(status);
CREATE INDEX IF NOT EXISTS idx_skill_offers_city     ON public.skill_offers(city);

ALTER TABLE public.skill_offers ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='skill_offers' AND policyname='skill_offers_public_read') THEN
    CREATE POLICY "skill_offers_public_read"
      ON public.skill_offers FOR SELECT USING (status = 'active');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='skill_offers' AND policyname='skill_offers_auth_insert') THEN
    CREATE POLICY "skill_offers_auth_insert"
      ON public.skill_offers FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='skill_offers' AND policyname='skill_offers_own_update') THEN
    CREATE POLICY "skill_offers_own_update"
      ON public.skill_offers FOR UPDATE USING (auth.uid() = user_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='skill_offers' AND policyname='skill_offers_own_delete') THEN
    CREATE POLICY "skill_offers_own_delete"
      ON public.skill_offers FOR DELETE USING (auth.uid() = user_id);
  END IF;
END $$;

-- ============================================================
-- 13. TABELLE: volunteer_signups
-- ============================================================
CREATE TABLE IF NOT EXISTS public.volunteer_signups (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id         UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message         TEXT,
  status          TEXT DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected','cancelled')),
  responded_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_volunteer_post ON public.volunteer_signups(post_id);
CREATE INDEX IF NOT EXISTS idx_volunteer_user ON public.volunteer_signups(user_id);

ALTER TABLE public.volunteer_signups ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='volunteer_signups' AND policyname='volunteer_read') THEN
    CREATE POLICY "volunteer_read"
      ON public.volunteer_signups FOR SELECT USING (
        auth.uid() = user_id
        OR auth.uid() = (SELECT user_id FROM public.posts WHERE id = post_id)
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='volunteer_signups' AND policyname='volunteer_insert') THEN
    CREATE POLICY "volunteer_insert"
      ON public.volunteer_signups FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='volunteer_signups' AND policyname='volunteer_update') THEN
    CREATE POLICY "volunteer_update"
      ON public.volunteer_signups FOR UPDATE USING (
        auth.uid() = user_id
        OR auth.uid() = (SELECT user_id FROM public.posts WHERE id = post_id)
      );
  END IF;
END $$;

-- ============================================================
-- ORGANISATIONS-DATEN: Tierheime
-- Kategorie-Werte ohne Umlaute: tierheim, tierschutz,
-- suppenkueche, obdachlosenhilfe, tafel, kleiderkammer,
-- sozialkaufhaus, krisentelefon, notschlafstelle, allgemein
-- ============================================================

INSERT INTO public.organizations (name, category, description, address, zip_code, city, state, country, phone, email, website, opening_hours, services, tags, is_verified) VALUES

-- DEUTSCHLAND: Tierheime
('Tierheim Berlin (Tierschutzverein fuer Berlin)', 'tierheim',
 'Das groesste staedtische Tierheim Deutschlands - betreut jaehrlich ueber 16.000 Tiere.',
 'Hausvaterweg 39', '13057', 'Berlin', 'Berlin', 'DE',
 '030 76888-0', 'tierheim@tierschutz-berlin.de', 'https://tierschutz-berlin.de',
 'Di-Sa 10-16 Uhr', ARRAY['Tiervermittlung','Fundtiere','Kastrationshilfe'], ARRAY['hund','katze','tier','berlin'], TRUE),

('Hamburger Tierschutzverein - Tierheim Hamburg', 'tierheim',
 'Tierheim des aeltesten Tierschutzvereins Deutschlands (gegr. 1841).',
 'Neue Suederstrasse 25', '20537', 'Hamburg', 'Hamburg', 'DE',
 '040 21110625', 'kontakt@hamburger-tierschutzverein.de', 'https://www.hamburger-tierschutzverein.de',
 'Di-So 11-16 Uhr', ARRAY['Tiervermittlung','Fundtiere','Tierberatung'], ARRAY['hund','katze','tier','hamburg'], TRUE),

('Franziskus Tierheim Hamburg', 'tierheim',
 'Tierheim in Hamburg-Eimsbuettel mit bis zu 30 Hunden, 40 Katzen und 30 Kleintieren.',
 'Hagenbeckstrasse 15', '22527', 'Hamburg', 'Hamburg', 'DE',
 '040 55492834', 'office@franziskustierheim.de', 'https://www.franziskustierheim.de',
 'Di-So 12-16 Uhr', ARRAY['Tiervermittlung','Kastration','Ehrenamt'], ARRAY['hund','katze','tier','hamburg'], TRUE),

('Tierschutzverein Frankfurt - Tierheim', 'tierheim',
 'Tierheim Frankfurt am Main - Fundtiere, Vermittlung, Tierschutzberatung.',
 'Ferdinand-Porsche-Strasse 2-4', '60386', 'Frankfurt am Main', 'Hessen', 'DE',
 '069 423005', 'info@tsv-frankfurt.de', 'https://www.tsv-frankfurt.de',
 'Di-Sa 10-16 Uhr', ARRAY['Tiervermittlung','Fundtiere','Tierschutz'], ARRAY['hund','katze','tier','frankfurt'], TRUE),

('Tierheim Koeln-Dellbrueck', 'tierheim',
 'Tierheim in Koeln-Dellbrueck - Hunde, Katzen, Kleintiere, Vermittlung.',
 'Iddelsfelder Hardt', '51069', 'Koeln', 'Nordrhein-Westfalen', 'DE',
 '0221 684926', NULL, 'https://tierheim-koeln-dellbrueck.de',
 'Di-Sa 10-16 Uhr', ARRAY['Tiervermittlung','Fundtiere'], ARRAY['hund','katze','tier','koeln'], TRUE),

('Tierschutzverein Nuernberg - Tierheim Nuernberg', 'tierheim',
 'Tierheim Nuernberg - eines der groessten Tierheime in Bayern.',
 'Stadenstrasse 90', '90491', 'Nuernberg', 'Bayern', 'DE',
 '0911 919890', 'info@tierheim-nuernberg.de', 'https://tierheim-nuernberg.de',
 'Di-Sa 10-17 Uhr', ARRAY['Tiervermittlung','Fundtiere','Ehrenamt'], ARRAY['hund','katze','tier','nuernberg'], TRUE),

('Muenchner Tierschutzverein - Tierheim Muenchen', 'tierheim',
 'Das staedtische Tierheim Muenchen - Hunde, Katzen, Kleintiere, Reptilien.',
 'Schoenblick 1', '80999', 'Muenchen', 'Bayern', 'DE',
 '089 8109950', 'info@mtvev.de', 'https://www.mtvev.de',
 'Di-So 10-17 Uhr', ARRAY['Tiervermittlung','Fundtiere','Tierarzt'], ARRAY['hund','katze','tier','muenchen'], TRUE),

('Tierschutzverein Stuttgart - Tierheim Stuttgart', 'tierheim',
 'Tierheim Stuttgart-Botnang - Hunde, Katzen, Kleintiere.',
 'Steckfeldstrasse 35', '70599', 'Stuttgart', 'Baden-Wuerttemberg', 'DE',
 '0711 451069', 'info@tierheim-stuttgart.de', 'https://www.tierheim-stuttgart.de',
 'Di-Sa 11-16 Uhr', ARRAY['Tiervermittlung','Fundtiere'], ARRAY['hund','katze','tier','stuttgart'], TRUE),

-- OESTERREICH: Tierheime
('TierQuarTier Wien', 'tierheim',
 'Staedtisches Tierheim Wien - Fundtiere, Adoptionen, Tieraerztliche Versorgung.',
 'Assmayergasse 32-36', '1120', 'Wien', 'Wien', 'AT',
 '+43 1 734 11 02', 'office@tierquartier.at', 'https://www.tierquartier.at',
 'Mo-So 8-17 Uhr', ARRAY['Tiervermittlung','Fundtiere','Tieraerztl. Versorgung'], ARRAY['hund','katze','tier','wien'], TRUE),

('Tierschutz Austria - Voesendorf', 'tierheim',
 'Groesstes Tierheim Oesterreichs - betreut ueber 10.000 Tiere pro Jahr.',
 'Triester Strasse 8', '2331', 'Voesendorf', 'Niederoesterreich', 'AT',
 '+43 1 699 24 50', NULL, 'https://www.tierschutz-austria.at',
 'Di-So 11-17 Uhr', ARRAY['Tiervermittlung','Kastration','Tierschutz'], ARRAY['hund','katze','tier','wien'], TRUE),

('Landestierschutzverein Steiermark - Tierheim Graz', 'tierheim',
 'Das Tierheim Graz des Landestierschutzvereins Steiermark.',
 'Huettenbrennergasse 2', '8052', 'Graz', 'Steiermark', 'AT',
 '0316 684212', 'graz@landestierschutzverein.at', 'https://www.landestierschutzverein.at',
 'Di-Sa 10-16 Uhr', ARRAY['Tiervermittlung','Fundtiere','Kastration'], ARRAY['hund','katze','tier','graz'], TRUE),

('Tierheim Linz (OOe Landestierschutzverein)', 'tierheim',
 'Das Tierheim Linz - Hunde, Katzen, Kleintiere, Fundtiere.',
 'Siemensstrasse 39', '4020', 'Linz', 'Oberoesterreich', 'AT',
 '0732 247887', 'office@tierheim-linz.at', 'https://www.tierheim-linz.at',
 'Di-So 10-17 Uhr', ARRAY['Tiervermittlung','Fundtiere','Beratung'], ARRAY['hund','katze','tier','linz'], TRUE),

-- SCHWEIZ: Tierheime
('Zuercher Tierschutz - Tierheim Zuerich', 'tierheim',
 'Tierheim des Zuercher Tierschutzes - Hunde, Katzen, Kleintiere, Adoption.',
 'Antonin-Schueler-Strasse 14', '8051', 'Zuerich', 'Zuerich', 'CH',
 '044 442 14 00', 'info@zuerchertierschutz.ch', 'https://www.zuerchertierschutz.ch',
 'Mo-Do 9-12/14-16 Uhr', ARRAY['Tiervermittlung','Tierschutzberatung'], ARRAY['hund','katze','tier','zuerich'], TRUE),

('Berner Tierschutz - Tierheim Bern', 'tierheim',
 'Tierheim des Berner Tierschutzes - Hunde, Katzen, Kleintiere.',
 'Schuepfenweg 9', '3036', 'Bern', 'Bern', 'CH',
 '031 926 64 64', 'info@bernertierschutz.ch', 'https://www.bernertierschutz.ch',
 'Mo-Fr 10-12 Uhr (tel.)', ARRAY['Tiervermittlung','Tierschutz','Kastration'], ARRAY['hund','katze','tier','bern'], TRUE),

-- UEBERREGIONAL: Tierschutz
('VIER PFOTEN Oesterreich', 'tierschutz',
 'Globale Tierschutzorganisation fuer Tiere unter menschlichem Einfluss.',
 'Linke Wienzeile 236', '1150', 'Wien', 'Wien', 'AT',
 '+43 1 895 02 02', 'office@vier-pfoten.at', 'https://www.vier-pfoten.at',
 'Mo-Fr 9-17 Uhr', ARRAY['Tierschutz','Lobbying','Notrettung'], ARRAY['tierschutz','oesterreich'], TRUE),

('Deutscher Tierschutzbund e.V.', 'tierschutz',
 'Dachverband von ueber 740 Tierschutzvereinen in Deutschland.',
 'In der Raste 10', '53129', 'Bonn', 'Nordrhein-Westfalen', 'DE',
 '0228 60496-0', 'info@tierschutzbund.de', 'https://www.tierschutzbund.de',
 'Mo-Fr 9-17 Uhr', ARRAY['Tierschutz','Lobbying','Tierheim-Finder'], ARRAY['tierschutz','deutschland'], TRUE),

-- SUPPENKUECHEN
('Franziskaner Suppenkueche Berlin-Pankow', 'suppenkueche',
 'Taegliche Essensausgabe fuer Obdachlose und Beduerftige.',
 'Wollankstrasse 19', '13187', 'Berlin', 'Berlin', 'DE',
 '030 4883 96-60', NULL, 'https://suppe.franziskaner.net',
 'Di-Fr 8-14:30 Uhr', ARRAY['Warme Mahlzeit','Beratung','Lebensmittelausgabe'], ARRAY['essen','obdachlos','berlin'], TRUE),

('Caritas Suppenkueche Berlin', 'suppenkueche',
 'Warme Mahlzeiten und Kleiderkammer der Caritas Berlin fuer Beduerftige.',
 'Residenzstrasse 90', '13409', 'Berlin', 'Berlin', 'DE',
 '030 666 33 1222', 'kleiderkammer@caritas-berlin.de', 'https://www.caritas-berlin.de',
 'Mo-Fr 9-13 Uhr', ARRAY['Warme Mahlzeit','Kleidung','Beratung'], ARRAY['essen','obdachlos','berlin'], TRUE),

('Franziskaner Suppenkueche Muenchen', 'suppenkueche',
 'Essensausgabe der Muenchner Franziskaner fuer obdachlose und arme Menschen.',
 'Rosenheimer Strasse 128d', '81669', 'Muenchen', 'Bayern', 'DE',
 '089 27781152', NULL, 'https://franziskaner-helfen.de/projekte/deutschland_suppenkuechen',
 'Mo-Fr 14-16 Uhr', ARRAY['Warme Mahlzeit','Sozialberatung'], ARRAY['essen','obdachlos','muenchen'], TRUE),

('Caritas Gruft Wien', 'suppenkueche',
 'Betreuungszentrum fuer obdachlose Menschen - warme Mahlzeiten, Unterkunft, Kleidung, Dusche.',
 'Barnabitengasse 12a', '1060', 'Wien', 'Wien', 'AT',
 '01 587 87 54', 'gruft@caritas-wien.at', 'https://www.gruft.at',
 'Taegl. 7-20 Uhr', ARRAY['Warme Mahlzeit','Unterkunft','Kleidung','Dusche','Sozialberatung'], ARRAY['essen','obdachlos','wien'], TRUE),

('Stiftung Schweizer Tafel - Essensverteilung', 'suppenkueche',
 'Rettet taeglich einwandfreie Lebensmittel und verteilt sie an soziale Institutionen.',
 NULL, NULL, 'Zuerich', 'Zuerich', 'CH',
 NULL, NULL, 'https://schweizertafel.ch',
 NULL, ARRAY['Lebensmittelrettung','Verteilung'], ARRAY['essen','lebensmittel','schweiz'], TRUE),

-- OBDACHLOSENHILFE
('Berliner Stadtmission - Kleiderkammer & Waermestube', 'obdachlosenhilfe',
 'Taegliche Versorgung von bis zu 180 obdachlosen Menschen mit Kleidung und Hygiene.',
 'Lehrter Strasse 68', '10557', 'Berlin', 'Berlin', 'DE',
 '030 690033-0', NULL, 'https://www.berliner-stadtmission.de/komm-sieh/kleiderkammer',
 'Mo-So 10-16 Uhr', ARRAY['Kleidung','Schlafsaecke','Hygieneartikel','Waermestube'], ARRAY['obdachlos','kleidung','berlin'], TRUE),

('Caritas Berlin - Wohnungslosenhilfe', 'obdachlosenhilfe',
 'Beratung und Unterstuetzung fuer wohnungslose Menschen in Berlin.',
 'Residenzstrasse 90', '13409', 'Berlin', 'Berlin', 'DE',
 '030 666 33 0', NULL, 'https://www.caritas-berlin.de',
 'Mo-Fr 9-16 Uhr', ARRAY['Sozialberatung','Wohnhilfe','Kleiderkammer'], ARRAY['obdachlos','beratung','berlin'], TRUE),

('Caritas Wien - Kaeltetelefon', 'obdachlosenhilfe',
 'Das Kaeltetelefon der Caritas Wien - Hinweise helfen Obdachlose zu retten.',
 NULL, NULL, 'Wien', 'Wien', 'AT',
 '01 480 45 53', 'kaeltetelefon@caritas-wien.at', 'https://www.caritas-wien.at',
 '24/7 (Nov-Maerz)', ARRAY['Kaeltetelefon','Notversorgung'], ARRAY['notfall','kaelte','obdachlos','wien'], TRUE),

('Winterhilfe Schweiz', 'obdachlosenhilfe',
 'Winterhilfe fuer Beduerftige in der Schweiz - Gutscheine, Sachleistungen, Beratung.',
 'Clausiusstrasse 45', '8006', 'Zuerich', 'Zuerich', 'CH',
 '044 269 40 50', 'info@winterhilfe.ch', 'https://www.winterhilfe.ch',
 'Mo-Fr 9-17 Uhr', ARRAY['Winterhilfe','Gutscheine','Sachleistungen'], ARRAY['winterhilfe','obdachlos','schweiz'], TRUE),

-- NOTSCHLAFSTELLEN
('Caritas Wien - Gruft Notschlafstelle', 'notschlafstelle',
 'Notschlafstelle der Caritas fuer obdachlose Menschen in Wien.',
 'Barnabitengasse 12a', '1060', 'Wien', 'Wien', 'AT',
 '01 587 87 54', 'gruft@caritas-wien.at', 'https://www.gruft.at',
 'Taegl. 20-9 Uhr', ARRAY['Notschlafstelle','Mahlzeiten','Kleidung','Dusche'], ARRAY['notschlafstelle','obdachlos','wien'], TRUE),

('Heilsarmee Schweiz - Notschlafstellen', 'notschlafstelle',
 'Notschlafstellen der Heilsarmee in Bern, Basel, Zuerich und weiteren Staedten.',
 'Laupenstrasse 5', '3008', 'Bern', 'Bern', 'CH',
 '+41 31 388 05 91', 'info@heilsarmee.ch', 'https://heilsarmee.ch/notunterkuenfte',
 'Taegl. ab 18 Uhr', ARRAY['Notschlafstelle','Fruehstueck','Sozialberatung'], ARRAY['notschlafstelle','obdachlos','schweiz'], TRUE),

-- TAFELN
('Tafel Deutschland e.V. (Dachverband)', 'tafel',
 'Dachverband von ueber 970 Tafel-Standorten deutschlandweit.',
 'Germaniastrasse 18', '12099', 'Berlin', 'Berlin', 'DE',
 '030 200 59 76-0', 'info@tafel.de', 'https://www.tafel.de',
 'Mo-Fr 9-17 Uhr', ARRAY['Lebensmittelverteilung','Sachspenden','Ehrenamt'], ARRAY['tafel','lebensmittel','deutschland'], TRUE),

('Berliner Tafel e.V.', 'tafel',
 'Die Berliner Tafel versorgt ueber 350 Ausgabestellen mit geretteten Lebensmitteln.',
 'Beusselstrasse 44 N-Q', '10553', 'Berlin', 'Berlin', 'DE',
 '030 782 74 14', 'ber.ta@berliner-tafel.de', 'https://www.berliner-tafel.de',
 'Mo-Fr 9-17 Uhr', ARRAY['Lebensmittelverteilung','Ehrenamt'], ARRAY['tafel','lebensmittel','berlin'], TRUE),

('Hamburger Tafel e.V.', 'tafel',
 'Hamburger Tafel - rettet ueberschuessige Lebensmittel und verteilt sie an Beduerftige.',
 NULL, NULL, 'Hamburg', 'Hamburg', 'DE',
 '040 300 605 600', 'info@hamburger-tafel.de', 'https://hamburger-tafel.de',
 'Mo-Fr 9-16 Uhr', ARRAY['Lebensmittelverteilung','Ehrenamt'], ARRAY['tafel','lebensmittel','hamburg'], TRUE),

('Muenchner Tafel e.V.', 'tafel',
 'Versorgt woechentlich 22.000 Beduerftige an 30 Ausgabestellen in Muenchen.',
 NULL, NULL, 'Muenchen', 'Bayern', 'DE',
 '089 292250', 'spenden@muenchner-tafel.de', 'https://muenchner-tafel.de',
 'Mo-Fr 9-16 Uhr', ARRAY['Lebensmittelverteilung','Ausgabestellen','Ehrenamt'], ARRAY['tafel','lebensmittel','muenchen'], TRUE),

('Wiener Tafel', 'tafel',
 'Oesterreichs aelteste Lebensmittelrettungsorganisation.',
 'Sechshauser Strasse 55', '1150', 'Wien', 'Wien', 'AT',
 '+43 1 786 67 25', 'office@wienertafel.at', 'https://www.wienertafel.at',
 'Mo-Fr 9-17 Uhr', ARRAY['Lebensmittelrettung','Verteilung'], ARRAY['tafel','lebensmittel','wien'], TRUE),

-- KLEIDERKAMMERN
('Caritas Berlin - Kleiderkammer', 'kleiderkammer',
 'Kleiderkammer und Second-Hand-Laden der Caritas Berlin fuer Beduerftige.',
 'Residenzstrasse 90', '13409', 'Berlin', 'Berlin', 'DE',
 '030 666 33 1222', 'kleiderkammer@caritas-berlin.de', 'https://www.caritas-berlin.de',
 'Mo-Fr 9-13 Uhr', ARRAY['Kleidung','Second-Hand','Spendenannahme'], ARRAY['kleidung','spenden','berlin'], TRUE),

('Carla Wien - Caritas Second-Hand-Laeden', 'kleiderkammer',
 'Second-Hand-Laeden der Caritas Wien - guenstig einkaufen und gleichzeitig helfen.',
 'Mittersteig 10', '1050', 'Wien', 'Wien', 'AT',
 '+43 1 890 02 78', 'info@carla-wien.at', 'https://www.carla-wien.at',
 'Mo-Sa 9-18 Uhr', ARRAY['Second-Hand','Kleidung','Moebel','Spendenannahme'], ARRAY['kleidung','moebel','wien'], TRUE),

-- KRISENTELEFONE
('TelefonSeelsorge Deutschland (0800 111 0 111)', 'krisentelefon',
 'Kostenlose, anonyme Telefonseelsorge - rund um die Uhr erreichbar.',
 NULL, NULL, 'Berlin', 'Berlin', 'DE',
 '0800 111 0 111', NULL, 'https://www.telefonseelsorge.de',
 '24/7 kostenlos', ARRAY['Krisenberatung','Seelsorge','Chat','E-Mail-Beratung'], ARRAY['krisentelefon','seelsorge','deutschland'], TRUE),

('TelefonSeelsorge Deutschland (0800 111 0 222)', 'krisentelefon',
 'Zweite kostenlose Notfallleitung der TelefonSeelsorge Deutschland.',
 NULL, NULL, 'Berlin', 'Berlin', 'DE',
 '0800 111 0 222', NULL, 'https://www.telefonseelsorge.de',
 '24/7 kostenlos', ARRAY['Krisenberatung','Seelsorge'], ARRAY['krisentelefon','seelsorge','deutschland'], TRUE),

('TelefonSeelsorge Deutschland (116 123)', 'krisentelefon',
 'Europaeische Notfallnummer fuer emotionale Unterstuetzung - kostenlos.',
 NULL, NULL, 'Berlin', 'Berlin', 'DE',
 '116 123', NULL, 'https://www.telefonseelsorge.de',
 '24/7 kostenlos', ARRAY['Krisenberatung','Seelsorge'], ARRAY['krisentelefon','notfall','deutschland'], TRUE),

('Telefonseelsorge Oesterreich (142)', 'krisentelefon',
 'Die oesterreichische Telefonseelsorge - kostenlos, anonym, rund um die Uhr.',
 NULL, NULL, 'Wien', 'Wien', 'AT',
 '142', NULL, 'https://www.telefonseelsorge.at',
 '24/7 kostenlos', ARRAY['Krisenberatung','Seelsorge','Anonym'], ARRAY['krisentelefon','seelsorge','oesterreich'], TRUE),

('Rat auf Draht (147) - Kinder- und Jugendtelefon Oesterreich', 'krisentelefon',
 'Kostenlose Krisenhotline fuer Kinder und Jugendliche in Oesterreich.',
 NULL, NULL, 'Wien', 'Wien', 'AT',
 '147', NULL, 'https://www.rataufdraht.at',
 '24/7 kostenlos', ARRAY['Kinder','Jugend','Krisenberatung','Anonym'], ARRAY['krisentelefon','kinder','oesterreich'], TRUE),

('Die Dargebotene Hand Schweiz (143)', 'krisentelefon',
 'Schweizer Krisentelefon - jederzeit, anonym und vertraulich.',
 NULL, NULL, 'Zuerich', 'Zuerich', 'CH',
 '143', NULL, 'https://www.143.ch',
 '24/7 kostenlos', ARRAY['Krisenberatung','Chat','E-Mail','Anonym'], ARRAY['krisentelefon','seelsorge','schweiz'], TRUE),

('PSD Wien - Sozialpsychiatrischer Notdienst', 'krisentelefon',
 'Psychiatrische Interventionen im Akut- und Krisenfall in Wien.',
 'Schottengasse 4', '1010', 'Wien', 'Wien', 'AT',
 '01 31330', NULL, 'https://psd-wien.at',
 '24/7', ARRAY['Psychiatrie','Krisenintervention','Akuthilfe'], ARRAY['krisentelefon','psychiatrie','wien'], TRUE),

-- ALLGEMEIN
('Caritas Deutschland', 'allgemein',
 'Groesster Wohlfahrtsverband Deutschlands - Nothilfe, Sozialberatung, Fluechtlingshilfe.',
 'Karlstrasse 40', '79104', 'Freiburg im Breisgau', 'Baden-Wuerttemberg', 'DE',
 '0761 200-0', 'info@caritas.de', 'https://www.caritas.de',
 'Mo-Fr 9-17 Uhr', ARRAY['Sozialberatung','Nothilfe','Fluechtlingshilfe','Pflegehilfe'], ARRAY['caritas','sozialhilfe','deutschland'], TRUE),

('Caritas Oesterreich', 'allgemein',
 'Die Caritas Oesterreich hilft in Not - Armutsbekaempfung, Fluechtlingshilfe.',
 'Albrechtskreithgasse 19-21', '1160', 'Wien', 'Wien', 'AT',
 '+43 1 878 12-0', 'office@caritas.at', 'https://www.caritas.at',
 'Mo-Fr 9-17 Uhr', ARRAY['Sozialberatung','Nothilfe','Obdachlosenhilfe'], ARRAY['caritas','sozialhilfe','oesterreich'], TRUE),

('Rotes Kreuz Oesterreich', 'allgemein',
 'Oesterreichisches Rotes Kreuz - Rettungsdienst, Katastrophenhilfe, Soziale Dienste.',
 'Wiedner Hauptstrasse 32', '1040', 'Wien', 'Wien', 'AT',
 '+43 1 589 00-0', 'office@roteskreuz.at', 'https://www.roteskreuz.at',
 '24/7 Notruf 144', ARRAY['Rettungsdienst','Katastrophenhilfe','Sozialdienste'], ARRAY['roteskreuz','nothilfe','oesterreich'], TRUE),

('Schweizerisches Rotes Kreuz', 'allgemein',
 'Schweizerisches Rotes Kreuz - Humanitaere Hilfe, Gesundheit, Integration.',
 'Rainmattstrasse 10', '3001', 'Bern', 'Bern', 'CH',
 '+41 31 387 71 11', 'info@redcross.ch', 'https://www.redcross.ch',
 'Mo-Fr 8-17 Uhr', ARRAY['Humanitaere Hilfe','Gesundheit','Integration'], ARRAY['roteskreuz','nothilfe','schweiz'], TRUE),

('AWO - Arbeiterwohlfahrt Deutschland', 'allgemein',
 'Einer der sechs Spitzenverbaende der freien Wohlfahrtspflege in Deutschland.',
 'Bluecher Strasse 62-63', '10961', 'Berlin', 'Berlin', 'DE',
 '030 26309-0', 'info@awo.org', 'https://www.awo.org',
 'Mo-Fr 9-17 Uhr', ARRAY['Sozialberatung','Kinder','Senioren','Pflege'], ARRAY['awo','sozialhilfe','deutschland'], TRUE),

('Diakonie Deutschland', 'allgemein',
 'Diakonisches Werk der EKD - Soziale Hilfe, Pflege, Beratung, Nothilfe.',
 'Reichensteiner Weg 24', '14195', 'Berlin', 'Berlin', 'DE',
 '030 65211-0', NULL, 'https://www.diakonie.de',
 'Mo-Fr 9-17 Uhr', ARRAY['Sozialberatung','Pflege','Nothilfe'], ARRAY['diakonie','sozialhilfe','deutschland'], TRUE);

-- ============================================================
-- POSTS: Fehlende Spalten ergaenzen
-- ============================================================
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS location_text TEXT;

-- ============================================================
-- POSTS: Type-Constraint aktualisieren
-- ============================================================
ALTER TABLE public.posts
  DROP CONSTRAINT IF EXISTS posts_type_check;

ALTER TABLE public.posts
  ADD CONSTRAINT posts_type_check CHECK (type IN (
    'rescue','animal','housing','supply','mobility',
    'sharing','community','crisis',
    'help_request','help_offer','skill','knowledge','mental'
  ));

-- ============================================================
-- INDEX-OPTIMIERUNGEN
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_posts_tags
  ON public.posts USING gin(tags);

CREATE INDEX IF NOT EXISTS idx_org_tags
  ON public.organizations USING gin(tags);
