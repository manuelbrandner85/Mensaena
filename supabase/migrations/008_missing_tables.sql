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

-- ============================================================
-- 1. TABELLE: organizations
-- Hilfsorganisationen aus Deutschland, Österreich, Schweiz
-- Tierheime, Suppenküchen, Obdachlosenhilfen, Tafeln u.v.m.
-- ============================================================
CREATE TABLE IF NOT EXISTS public.organizations (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name            TEXT NOT NULL,
  category        TEXT NOT NULL DEFAULT 'allgemein' CHECK (category IN (
    'tierheim',          -- Tierheime, Tierschutzvereine
    'tierschutz',        -- Tierschutzorganisationen (überregional)
    'suppenküche',       -- Suppenküchen, Essensausgaben
    'obdachlosenhilfe',  -- Notunterkünfte, Straßensozialarbeit
    'tafel',             -- Lebensmittelbanken, Tafeln
    'kleiderkammer',     -- Kleiderspenden, Second-Hand-Läden
    'sozialkaufhaus',    -- Sozialkaufhäuser, Möbelbörsen
    'krisentelefon',     -- Krisentelefone, Seelsorge-Hotlines
    'notschlafstelle',   -- Notschlafstellen, Unterkünfte
    'jugend',            -- Jugendhilfe, Jugendnotdienst
    'senioren',          -- Seniorenhilfe, Tagespflege
    'behinderung',       -- Behindertenhilfe, Inklusion
    'sucht',             -- Suchtberatung, Entzug
    'flüchtlingshilfe',  -- Flüchtlings- und Migrationsberatung
    'allgemein'          -- Allgemeine Sozialhilfe, sonstige
  )),
  description     TEXT,
  address         TEXT,                            -- Straße + Hausnummer
  zip_code        TEXT,                            -- Postleitzahl
  city            TEXT NOT NULL,                   -- Stadt
  state           TEXT,                            -- Bundesland / Kanton
  country         TEXT NOT NULL DEFAULT 'DE' CHECK (country IN ('DE','AT','CH')),
  latitude        DOUBLE PRECISION,
  longitude       DOUBLE PRECISION,
  phone           TEXT,
  email           TEXT,
  website         TEXT,
  opening_hours   TEXT,                            -- Freitext, z.B. "Mo-Fr 9-17 Uhr"
  services        TEXT[] DEFAULT '{}',             -- Angebote, z.B. ['Essen','Kleidung']
  tags            TEXT[] DEFAULT '{}',             -- Suchbegriffe
  is_verified     BOOLEAN DEFAULT FALSE,           -- Manuell verifiziert
  is_active       BOOLEAN DEFAULT TRUE,            -- Aktiv/Inaktiv
  source_url      TEXT,                            -- Quell-URL der Information
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TRIGGER handle_organizations_updated_at
  BEFORE UPDATE ON public.organizations
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_org_category  ON public.organizations(category);
CREATE INDEX IF NOT EXISTS idx_org_city      ON public.organizations(city);
CREATE INDEX IF NOT EXISTS idx_org_country   ON public.organizations(country);
CREATE INDEX IF NOT EXISTS idx_org_active    ON public.organizations(is_active);
CREATE INDEX IF NOT EXISTS idx_org_coords    ON public.organizations(latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- RLS: Öffentlich lesbar, nur Service-Role kann schreiben
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "organizations_public_read"
  ON public.organizations FOR SELECT USING (is_active = TRUE);

CREATE POLICY "organizations_service_write"
  ON public.organizations FOR ALL USING (auth.role() = 'service_role');

-- ============================================================
-- 2. TABELLE: push_subscriptions
-- Web-Push-Abonnements für Browser-Benachrichtigungen
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

CREATE POLICY "push_subs_own"
  ON public.push_subscriptions FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 3. TABELLE: user_status
-- Online-Status der Nutzer (Online / Away / Busy / Offline)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_status (
  user_id     UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'offline' CHECK (status IN ('online','away','busy','offline')),
  last_seen   TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE public.user_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_status_read"
  ON public.user_status FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "user_status_own_write"
  ON public.user_status FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 4. TABELLE: message_reactions
-- Emoji-Reaktionen auf Chat-Nachrichten
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

CREATE POLICY "reactions_read"
  ON public.message_reactions FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "reactions_insert"
  ON public.message_reactions FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "reactions_delete"
  ON public.message_reactions FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 5. TABELLE: message_pins
-- Angepinnte Nachrichten in Chat-Kanälen
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

CREATE POLICY "pins_read"
  ON public.message_pins FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "pins_admin_write"
  ON public.message_pins FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
    OR auth.uid() = pinned_by
  );

-- ============================================================
-- 6. TABELLE: chat_announcements
-- Öffentliche Admin-Ankündigungen im Chat
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

CREATE POLICY "announcements_read"
  ON public.chat_announcements FOR SELECT USING (
    is_active = TRUE AND (expires_at IS NULL OR expires_at > NOW())
  );

CREATE POLICY "announcements_admin_write"
  ON public.chat_announcements FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    OR auth.uid() = author_id
  );

-- ============================================================
-- 7. TABELLE: chat_banned_users
-- Im Chat gebannte Nutzer
-- ============================================================
CREATE TABLE IF NOT EXISTS public.chat_banned_users (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  banned_by       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason          TEXT,
  banned_until    TIMESTAMPTZ,                          -- NULL = dauerhaft
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_banned_user ON public.chat_banned_users(user_id);

ALTER TABLE public.chat_banned_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "banned_admin_read"
  ON public.chat_banned_users FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
    OR auth.uid() = user_id
  );

CREATE POLICY "banned_admin_write"
  ON public.chat_banned_users FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

-- ============================================================
-- 8. TABELLE: post_tags (normalisiert, ergänzt posts.tags TEXT[])
-- Separate Tag-Entitäten für Autocomplete / Statistiken
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

CREATE POLICY "post_tags_read"
  ON public.post_tags FOR SELECT USING (TRUE);

CREATE POLICY "post_tags_write"
  ON public.post_tags FOR INSERT WITH CHECK (
    auth.uid() = (SELECT user_id FROM public.posts WHERE id = post_id)
  );

CREATE POLICY "post_tags_delete"
  ON public.post_tags FOR DELETE USING (
    auth.uid() = (SELECT user_id FROM public.posts WHERE id = post_id)
  );

-- ============================================================
-- 9. TABELLE: timebank_entries
-- Zeitbank: Buchungen von Hilfsstunden zwischen Nutzern
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

CREATE POLICY "timebank_own_read"
  ON public.timebank_entries FOR SELECT USING (
    auth.uid() = giver_id OR auth.uid() = receiver_id
  );

CREATE POLICY "timebank_insert"
  ON public.timebank_entries FOR INSERT WITH CHECK (auth.uid() = giver_id);

CREATE POLICY "timebank_receiver_update"
  ON public.timebank_entries FOR UPDATE USING (
    auth.uid() = receiver_id OR auth.uid() = giver_id
  );

-- ============================================================
-- 10. TABELLE: knowledge_articles
-- Wissens-Datenbank: Guides, Anleitungen, Tipps
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

CREATE TRIGGER handle_knowledge_updated_at
  BEFORE UPDATE ON public.knowledge_articles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_knowledge_author   ON public.knowledge_articles(author_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_category ON public.knowledge_articles(category);
CREATE INDEX IF NOT EXISTS idx_knowledge_status   ON public.knowledge_articles(status);
CREATE INDEX IF NOT EXISTS idx_knowledge_slug     ON public.knowledge_articles(slug);

ALTER TABLE public.knowledge_articles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "knowledge_public_read"
  ON public.knowledge_articles FOR SELECT USING (
    is_public = TRUE AND status = 'published'
    OR auth.uid() = author_id
  );

CREATE POLICY "knowledge_auth_insert"
  ON public.knowledge_articles FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "knowledge_own_update"
  ON public.knowledge_articles FOR UPDATE USING (auth.uid() = author_id);

CREATE POLICY "knowledge_own_delete"
  ON public.knowledge_articles FOR DELETE USING (auth.uid() = author_id);

-- ============================================================
-- 11. TABELLE: crisis_reports
-- Krisenberichte & Notfallmeldungen aus der Community
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

CREATE TRIGGER handle_crisis_updated_at
  BEFORE UPDATE ON public.crisis_reports
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_crisis_status   ON public.crisis_reports(status);
CREATE INDEX IF NOT EXISTS idx_crisis_severity ON public.crisis_reports(severity);
CREATE INDEX IF NOT EXISTS idx_crisis_city     ON public.crisis_reports(city);
CREATE INDEX IF NOT EXISTS idx_crisis_coords   ON public.crisis_reports(latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

ALTER TABLE public.crisis_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "crisis_public_read"
  ON public.crisis_reports FOR SELECT USING (status = 'active');

CREATE POLICY "crisis_auth_insert"
  ON public.crisis_reports FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "crisis_own_update"
  ON public.crisis_reports FOR UPDATE USING (
    auth.uid() = reporter_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

-- ============================================================
-- 12. TABELLE: skill_offers
-- Skill-Angebote für das Zeitbank-/Kompetenz-Modul
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

CREATE TRIGGER handle_skill_offers_updated_at
  BEFORE UPDATE ON public.skill_offers
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_skill_offers_user     ON public.skill_offers(user_id);
CREATE INDEX IF NOT EXISTS idx_skill_offers_category ON public.skill_offers(skill_category);
CREATE INDEX IF NOT EXISTS idx_skill_offers_status   ON public.skill_offers(status);
CREATE INDEX IF NOT EXISTS idx_skill_offers_city     ON public.skill_offers(city);

ALTER TABLE public.skill_offers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "skill_offers_public_read"
  ON public.skill_offers FOR SELECT USING (status = 'active');

CREATE POLICY "skill_offers_auth_insert"
  ON public.skill_offers FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "skill_offers_own_update"
  ON public.skill_offers FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "skill_offers_own_delete"
  ON public.skill_offers FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 13. TABELLE: volunteer_signups
-- Freiwilligen-Anmeldungen für Aktionen / Events
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

CREATE POLICY "volunteer_read"
  ON public.volunteer_signups FOR SELECT USING (
    auth.uid() = user_id
    OR auth.uid() = (SELECT user_id FROM public.posts WHERE id = post_id)
  );

CREATE POLICY "volunteer_insert"
  ON public.volunteer_signups FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "volunteer_update"
  ON public.volunteer_signups FOR UPDATE USING (
    auth.uid() = user_id
    OR auth.uid() = (SELECT user_id FROM public.posts WHERE id = post_id)
  );

-- ============================================================
-- ORGANISATIONS-DATEN: Deutschland, Österreich, Schweiz
-- Kategorie: Tierheime
-- ============================================================
INSERT INTO public.organizations (name, category, description, address, zip_code, city, state, country, phone, email, website, opening_hours, services, tags, is_verified) VALUES

-- ── DEUTSCHLAND: Tierheime ──────────────────────────────────
('Tierheim Berlin (Tierschutzverein für Berlin)', 'tierheim',
 'Das größte städtische Tierheim Deutschlands – betreut jährlich über 16.000 Tiere. Fundtiere, Vermittlung, Kastrationshilfe.',
 'Hausvaterweg 39', '13057', 'Berlin', 'Berlin', 'DE',
 '030 76888-0', 'tierheim@tierschutz-berlin.de', 'https://tierschutz-berlin.de',
 'Di–Sa 10–16 Uhr', ARRAY['Tiervermittlung','Fundtiere','Kastrationshilfe','Beratung'], ARRAY['hund','katze','tier','berlin'], TRUE),

('Hamburger Tierschutzverein – Tierheim Hamburg', 'tierheim',
 'Tierheim des ältesten Tierschutzvereins Deutschlands (gegr. 1841). Hunde, Katzen, Kleintiere.',
 'Neue Süderstraße 25', '20537', 'Hamburg', 'Hamburg', 'DE',
 '040 21110625', 'kontakt@hamburger-tierschutzverein.de', 'https://www.hamburger-tierschutzverein.de',
 'Di–So 11–16 Uhr', ARRAY['Tiervermittlung','Fundtiere','Tierberatung'], ARRAY['hund','katze','tier','hamburg'], TRUE),

('Franziskus Tierheim Hamburg', 'tierheim',
 'Tierheim in Hamburg-Eimsbüttel mit bis zu 30 Hunden, 40 Katzen und 30 Kleintieren.',
 'Hagenbeckstraße 15', '22527', 'Hamburg', 'Hamburg', 'DE',
 '040 55492834', 'office@franziskustierheim.de', 'https://www.franziskustierheim.de',
 'Di–So 12–16 Uhr', ARRAY['Tiervermittlung','Kastration','Ehrenamt'], ARRAY['hund','katze','tier','hamburg'], TRUE),

('Tierschutzverein Frankfurt – Tierheim', 'tierheim',
 'Tierheim Frankfurt am Main – Fundtiere, Vermittlung, Tierschutzberatung.',
 'Ferdinand-Porsche-Straße 2-4', '60386', 'Frankfurt am Main', 'Hessen', 'DE',
 '069 423005', 'info@tsv-frankfurt.de', 'https://www.tsv-frankfurt.de',
 'Di–Sa 10–16 Uhr', ARRAY['Tiervermittlung','Fundtiere','Tierschutz'], ARRAY['hund','katze','tier','frankfurt'], TRUE),

('Tierheim Köln-Dellbrück (Bund gegen den Missbrauch der Tiere)', 'tierheim',
 'Tierheim in Köln-Dellbrück – Hunde, Katzen, Kleintiere, Vermittlung.',
 'Iddelsfelder Hardt', '51069', 'Köln', 'Nordrhein-Westfalen', 'DE',
 '0221 684926', NULL, 'https://tierheim-koeln-dellbrueck.de',
 'Di–Sa 10–16 Uhr', ARRAY['Tiervermittlung','Fundtiere'], ARRAY['hund','katze','tier','köln'], TRUE),

('Tierschutzverein Nürnberg – Tierheim Nürnberg', 'tierheim',
 'Tierheim Nürnberg – eines der größten Tierheime in Bayern.',
 'Stadenstraße 90', '90491', 'Nürnberg', 'Bayern', 'DE',
 '0911 919890', 'info@tierheim-nuernberg.de', 'https://tierheim-nuernberg.de',
 'Di–Sa 10–17 Uhr', ARRAY['Tiervermittlung','Fundtiere','Ehrenamt'], ARRAY['hund','katze','tier','nürnberg'], TRUE),

('Münchner Tierschutzverein – Tierheim München', 'tierheim',
 'Das städtische Tierheim München – Hunde, Katzen, Kleintiere, Reptilien.',
 'Schönblick 1', '80999', 'München', 'Bayern', 'DE',
 '089 8109950', 'info@mtvev.de', 'https://www.mtvev.de',
 'Di–So 10–17 Uhr', ARRAY['Tiervermittlung','Fundtiere','Tierarzt'], ARRAY['hund','katze','tier','münchen'], TRUE),

('Tierschutzverein Stuttgart – Tierheim Stuttgart', 'tierheim',
 'Tierheim Stuttgart-Botnang – Hunde, Katzen, Kleintiere.',
 'Steckfeldstraße 35', '70599', 'Stuttgart', 'Baden-Württemberg', 'DE',
 '0711 451069', 'info@tierheim-stuttgart.de', 'https://www.tierheim-stuttgart.de',
 'Di–Sa 11–16 Uhr', ARRAY['Tiervermittlung','Fundtiere'], ARRAY['hund','katze','tier','stuttgart'], TRUE),

-- ── ÖSTERREICH: Tierheime ───────────────────────────────────
('TierQuarTier Wien', 'tierheim',
 'Städtisches Tierheim Wien – Fundtiere, Adoptionen, Tierärztliche Versorgung.',
 'Aßmayergasse 32-36', '1120', 'Wien', 'Wien', 'AT',
 '+43 1 734 11 02-114', 'office@tierquartier.at', 'https://www.tierquartier.at',
 'Mo–So 8–17 Uhr', ARRAY['Tiervermittlung','Fundtiere','Tierärztl. Versorgung'], ARRAY['hund','katze','tier','wien'], TRUE),

('Tierschutz Austria (Wiener Tierschutzverein) – Vösendorf', 'tierheim',
 'Größtes Tierheim Österreichs – betreut über 10.000 Tiere pro Jahr.',
 'Triester Straße 8', '2331', 'Vösendorf', 'Niederösterreich', 'AT',
 '+43 1 699 24 50', NULL, 'https://www.tierschutz-austria.at',
 'Di–So 11–17 Uhr', ARRAY['Tiervermittlung','Kastration','Tierschutz'], ARRAY['hund','katze','tier','wien','niederösterreich'], TRUE),

('Landestierschutzverein Steiermark – Tierheim Graz', 'tierheim',
 'Das Tierheim Graz des Landestierschutzvereins Steiermark.',
 'Hüttenbrennergasse 2', '8052', 'Graz', 'Steiermark', 'AT',
 '0316 684212', 'graz@landestierschutzverein.at', 'https://www.landestierschutzverein.at',
 'Di–Sa 10–16 Uhr', ARRAY['Tiervermittlung','Fundtiere','Kastration'], ARRAY['hund','katze','tier','graz'], TRUE),

('Tierheim Linz (OÖ Landestierschutzverein)', 'tierheim',
 'Das Tierheim Linz – Hunde, Katzen, Kleintiere, Fundtiere.',
 'Siemensstraße 39', '4020', 'Linz', 'Oberösterreich', 'AT',
 '0732 247887', 'office@tierheim-linz.at', 'https://www.tierheim-linz.at',
 'Di–So 10–17 Uhr', ARRAY['Tiervermittlung','Fundtiere','Beratung'], ARRAY['hund','katze','tier','linz'], TRUE),

-- ── SCHWEIZ: Tierheime ──────────────────────────────────────
('Zürcher Tierschutz – Tierheim Zürich', 'tierheim',
 'Tierheim des Zürcher Tierschutzes – Hunde, Katzen, Kleintiere, Adoption.',
 'Antonin-Schueler-Strasse 14', '8051', 'Zürich', 'Zürich', 'CH',
 '044 442 14 00', 'info@zuerchertierschutz.ch', 'https://www.zuerchertierschutz.ch',
 'Mo–Do 9–12/14–16 Uhr', ARRAY['Tiervermittlung','Tierschutzberatung','Fundtiere'], ARRAY['hund','katze','tier','zürich'], TRUE),

('Berner Tierschutz – Tierheim Bern', 'tierheim',
 'Tierheim des Berner Tierschutzes – Hunde, Katzen, Kleintiere.',
 'Schüpfenweg 9', '3036', 'Bern', 'Bern', 'CH',
 '031 926 64 64', 'info@bernertierschutz.ch', 'https://www.bernertierschutz.ch',
 'Mo–Fr 10–12 Uhr (tel.)', ARRAY['Tiervermittlung','Tierschutz','Kastration'], ARRAY['hund','katze','tier','bern'], TRUE),

('Stiftung TBB Schweiz – Tierheim beider Basel', 'tierheim',
 'Tierheim beider Basel – Hunde, Katzen, Kleintiere, Reptilien.',
 'Mühlematten 12', '4106', 'Therwil', 'Basel-Landschaft', 'CH',
 NULL, 'tierschutz@tbb.ch', 'https://www.tbb.ch',
 'Mi–Sa 14:30–17 Uhr', ARRAY['Tiervermittlung','Tierschutz','Fundtiere'], ARRAY['hund','katze','tier','basel'], TRUE),

-- ── ÜBERREGIONAL: Tierschutz ────────────────────────────────
('VIER PFOTEN Österreich', 'tierschutz',
 'Globale Tierschutzorganisation für Tiere unter menschlichem Einfluss.',
 'Linke Wienzeile 236', '1150', 'Wien', 'Wien', 'AT',
 '+43 1 895 02 02-0', 'office@vier-pfoten.at', 'https://www.vier-pfoten.at',
 'Mo–Fr 9–17 Uhr', ARRAY['Tierschutz','Lobbying','Notrettung'], ARRAY['tierschutz','österreich','vierPfoten'], TRUE),

('Gut Aiderbichl – Gnadenhof Henndorf', 'tierschutz',
 'Gnadenhof für gerettete Tiere – Kühe, Pferde, Schafe, Katzen und mehr.',
 'Gut Aiderbichl 1', '5302', 'Henndorf am Wallersee', 'Salzburg', 'AT',
 '+43 662 62 53 95', 'info@gut-aiderbichl.com', 'https://www.gut-aiderbichl.com',
 'Tägl. 9–17 Uhr', ARRAY['Gnadenhof','Tierpatenschaft','Tierrettung'], ARRAY['gnadenhof','tiere','salzburg','österreich'], TRUE),

('Deutscher Tierschutzbund e.V.', 'tierschutz',
 'Dachverband von über 740 Tierschutzvereinen in Deutschland. Tierheim-Finder auf Website.',
 'In der Raste 10', '53129', 'Bonn', 'Nordrhein-Westfalen', 'DE',
 '0228 60496-0', 'info@tierschutzbund.de', 'https://www.tierschutzbund.de',
 'Mo–Fr 9–17 Uhr', ARRAY['Tierschutz','Lobbying','Tierheim-Finder'], ARRAY['tierschutz','deutschland','dachverband'], TRUE),

('Schweizer Tierschutz STS', 'tierschutz',
 'Schweizer Tierschutzorganisation – seit 160 Jahren im Einsatz für das Wohl der Tiere.',
 'Dornacherstrasse 101', '4008', 'Basel', 'Basel-Stadt', 'CH',
 NULL, NULL, 'https://tierschutz.com',
 NULL, ARRAY['Tierschutz','Lobbying','Beratung'], ARRAY['tierschutz','schweiz'], TRUE),

-- ============================================================
-- ORGANISATIONS-DATEN: Suppenküchen & Essensausgaben
-- ============================================================

-- ── DEUTSCHLAND ─────────────────────────────────────────────
('Franziskaner Suppenküche Berlin-Pankow', 'suppenküche',
 'Tägliche Essensausgabe für Obdachlose und Bedürftige im Franziskanerkloster Pankow.',
 'Wollankstraße 19', '13187', 'Berlin', 'Berlin', 'DE',
 '030 4883 96-60', NULL, 'https://suppe.franziskaner.net',
 'Di–Fr 8–14:30 Uhr', ARRAY['Warme Mahlzeit','Beratung','Lebensmittelausgabe'], ARRAY['essen','obdachlos','berlin'], TRUE),

('Caritas Suppenküche Berlin (Kleiderkammer & Essen)', 'suppenküche',
 'Warme Mahlzeiten und Kleiderkammer der Caritas Berlin für Bedürftige.',
 'Residenzstraße 90', '13409', 'Berlin', 'Berlin', 'DE',
 '030 666 33 1222', 'kleiderkammer@caritas-berlin.de', 'https://www.caritas-berlin.de',
 'Mo–Fr 9–13 Uhr', ARRAY['Warme Mahlzeit','Kleidung','Beratung'], ARRAY['essen','obdachlos','berlin','kleidung'], TRUE),

('Caritas Suppenküche Düsseldorf', 'suppenküche',
 'Essensausgabe der Caritas Düsseldorf für obdachlose und arme Menschen.',
 'Hubertusstraße 5', '40219', 'Düsseldorf', 'Nordrhein-Westfalen', 'DE',
 '0211 16020', NULL, 'https://www.caritas-duesseldorf.de/engagement/suppenkueche',
 'nach Bekanntmachung', ARRAY['Warme Mahlzeit','Sozialberatung'], ARRAY['essen','obdachlos','düsseldorf'], TRUE),

('Franziskaner Suppenküche München', 'suppenküche',
 'Essensausgabe der Münchner Franziskaner für obdachlose und arme Menschen.',
 'Rosenheimer Straße 128d', '81669', 'München', 'Bayern', 'DE',
 '089 27781152', NULL, 'https://franziskaner-helfen.de/projekte/deutschland_suppenkuechen',
 'Mo–Fr 14–16 Uhr', ARRAY['Warme Mahlzeit','Sozialberatung'], ARRAY['essen','obdachlos','münchen'], TRUE),

('Caritas Nürnberg – Suppenküche & Beratung', 'suppenküche',
 'Soziale Beratung und Essensausgabe der Caritas in Nürnberg.',
 'Obstmarkt 28', '90403', 'Nürnberg', 'Bayern', 'DE',
 '0911 235 40', 'info@caritas-nuernberg.de', 'https://www.caritas-nuernberg.de',
 'Mo–Di 9–13 Uhr', ARRAY['Warme Mahlzeit','Sozialberatung','Lebensmittelhilfe'], ARRAY['essen','beratung','nürnberg'], TRUE),

-- ── ÖSTERREICH ──────────────────────────────────────────────
('Caritas Gruft Wien', 'suppenküche',
 'Betreuungszentrum für obdachlose Menschen – warme Mahlzeiten, Unterkunft, Kleidung, Dusche.',
 'Barnabitengasse 12a', '1060', 'Wien', 'Wien', 'AT',
 '01 587 87 54', 'gruft@caritas-wien.at', 'https://www.gruft.at',
 'Tägl. 7–20 Uhr', ARRAY['Warme Mahlzeit','Unterkunft','Kleidung','Dusche','Sozialberatung'], ARRAY['essen','obdachlos','wien','notschlafstelle'], TRUE),

('Canisibus / Caritas Wien', 'suppenküche',
 'Mobiler Suppenbus der Caritas Wien – verteilt täglich warme Mahlzeiten an Bedürftige.',
 NULL, NULL, 'Wien', 'Wien', 'AT',
 '01 878 12-0', 'office@caritas-wien.at', 'https://www.caritas-wien.at/hilfe-angebote/obdach-wohnen/mobile-notversorgung',
 'täglich, Touren nach Plan', ARRAY['Mobile Essensausgabe','Getränke','Sozialberatung'], ARRAY['essen','obdachlos','wien','mobil'], TRUE),

-- ── SCHWEIZ ─────────────────────────────────────────────────
('Stiftung Schweizer Tafel – Essensverteilung Schweiz', 'suppenküche',
 'Rettet täglich einwandfreie Lebensmittel und verteilt sie an soziale Institutionen schweizweit.',
 NULL, NULL, 'Zürich', 'Zürich', 'CH',
 NULL, NULL, 'https://schweizertafel.ch',
 NULL, ARRAY['Lebensmittelrettung','Verteilung','Partnerorganisationen'], ARRAY['essen','lebensmittel','schweiz'], TRUE),

-- ============================================================
-- ORGANISATIONS-DATEN: Obdachlosenhilfe & Notunterkünfte
-- ============================================================

-- ── DEUTSCHLAND ─────────────────────────────────────────────
('FSW Obdach – Sachspendenannahme Wien', 'obdachlosenhilfe',
 'FSW (Fonds Soziales Wien) – Sachspendenannahme und Unterstützung für Obdachlose.',
 'Sautergasse 34-38', '1170', 'Wien', 'Wien', 'AT',
 '0676 8289 40 472', 'obdach.sg.nz@fsw.at', 'https://www.obdach.wien',
 'Mo–Fr 9–15 Uhr', ARRAY['Sachspenden','Kleidung','Lebensmittel','Beratung'], ARRAY['spenden','obdachlos','wien'], TRUE),

('Berliner Stadtmission – Kleiderkammer & Wärmestube', 'obdachlosenhilfe',
 'Tägliche Versorgung von bis zu 180 obdachlosen Menschen mit Kleidung, Schlafsäcken und Hygiene.',
 'Lehrter Straße 68', '10557', 'Berlin', 'Berlin', 'DE',
 '030 690033-0', NULL, 'https://www.berliner-stadtmission.de/komm-sieh/kleiderkammer',
 'Mo–So 10–16 Uhr', ARRAY['Kleidung','Schlafsäcke','Hygieneartikel','Wärmestube'], ARRAY['obdachlos','kleidung','berlin'], TRUE),

('Caritas Berlin – Wohnungslosenhilfe', 'obdachlosenhilfe',
 'Beratung und Unterstützung für wohnungslose Menschen in Berlin.',
 'Residenzstraße 90', '13409', 'Berlin', 'Berlin', 'DE',
 '030 666 33 0', NULL, 'https://www.caritas-berlin.de',
 'Mo–Fr 9–16 Uhr', ARRAY['Sozialberatung','Wohnhilfe','Kleiderkammer'], ARRAY['obdachlos','beratung','berlin'], TRUE),

('Diakonie Düsseldorf – Wohnungslose & Arme', 'obdachlosenhilfe',
 'Hilfe für wohnungslose und arme Menschen in Düsseldorf.',
 'An der Icklack 26', '40233', 'Düsseldorf', 'Nordrhein-Westfalen', 'DE',
 '0211 7338220', NULL, 'https://www.diakonie-duesseldorf.de/gesundheit-soziales/wohnungslose-arme',
 'Mo–Fr 9–16 Uhr', ARRAY['Sozialberatung','Unterkunft','Streetwork'], ARRAY['obdachlos','beratung','düsseldorf'], TRUE),

('Caritas Düsseldorf – Wohnungslosigkeit', 'obdachlosenhilfe',
 'Beratung und Hilfe für wohnungslose Menschen durch Caritas Düsseldorf.',
 'Hubertusstraße 5', '40219', 'Düsseldorf', 'Nordrhein-Westfalen', 'DE',
 '0211 1602-0', 'info@caritas-duesseldorf.de', 'https://www.caritas-duesseldorf.de',
 'Mo–Fr 9–16 Uhr', ARRAY['Sozialberatung','Wohnhilfe','Obdachlosenhilfe'], ARRAY['obdachlos','beratung','düsseldorf'], TRUE),

-- ── ÖSTERREICH ──────────────────────────────────────────────
('Caritas Wien – Betreuungszentrum Gruft (Notschlafstelle)', 'notschlafstelle',
 'Notschlafstelle der Caritas für obdachlose Menschen in Wien. Kältetelefon: 01/480 45 53.',
 'Barnabitengasse 12a', '1060', 'Wien', 'Wien', 'AT',
 '01 587 87 54', 'gruft@caritas-wien.at', 'https://www.gruft.at',
 'Tägl. 7–20 Uhr (Notschlafstelle 20–9 Uhr)', ARRAY['Notschlafstelle','Mahlzeiten','Kleidung','Dusche'], ARRAY['notschlafstelle','obdachlos','wien'], TRUE),

('Caritas Wien – Kältetelefon (Wiener Wohnungslosenhilfe)', 'obdachlosenhilfe',
 'Das Kältetelefon der Caritas Wien – Hinweise aus der Bevölkerung helfen Obdachlose zu retten.',
 NULL, NULL, 'Wien', 'Wien', 'AT',
 '01 480 45 53', 'kaeltetelefon@caritas-wien.at', 'https://www.caritas-wien.at/hilfe-angebote/obdach-wohnen/mobile-notversorgung',
 '24/7 erreichbar (Nov–März)', ARRAY['Kältetelefon','Notversorgung','Hinweise-Hotline'], ARRAY['notfall','kälte','obdachlos','wien'], TRUE),

-- ── SCHWEIZ ─────────────────────────────────────────────────
('Heilsarmee Schweiz – Notschlafstellen', 'notschlafstelle',
 'Notschlafstellen der Heilsarmee in Bern, Basel, Zürich und weiteren Städten.',
 'Laupenstrasse 5', '3008', 'Bern', 'Bern', 'CH',
 '+41 31 388 05 91', 'info@heilsarmee.ch', 'https://heilsarmee.ch/notunterkuenfte',
 'Tägl. ab 18 Uhr', ARRAY['Notschlafstelle','Frühstück','Sozialberatung'], ARRAY['notschlafstelle','obdachlos','schweiz'], TRUE),

('Heilsarmee Basel – Männerwohnhaus', 'notschlafstelle',
 'Wohnheim und Notschlafstelle der Heilsarmee in Basel.',
 'Güterstraße 148', '4053', 'Basel', 'Basel-Stadt', 'CH',
 '+41 61 666 66 70', 'maennerwohnhaus.bs@heilsarmee.ch', 'https://wohnen-basel.heilsarmee.ch',
 'Tägl. 8–22 Uhr', ARRAY['Notschlafstelle','Wohnheim','Sozialberatung'], ARRAY['notschlafstelle','obdachlos','basel'], TRUE),

('Winterhilfe Schweiz', 'obdachlosenhilfe',
 'Winterhilfe für Bedürftige in der Schweiz – Gutscheine, Sachleistungen, Beratung.',
 'Clausiusstrasse 45', '8006', 'Zürich', 'Zürich', 'CH',
 '044 269 40 50', 'info@winterhilfe.ch', 'https://www.winterhilfe.ch',
 'Mo–Fr 9–17 Uhr', ARRAY['Winterhilfe','Gutscheine','Sachleistungen','Beratung'], ARRAY['winterhilfe','obdachlos','schweiz'], TRUE),

-- ============================================================
-- ORGANISATIONS-DATEN: Tafeln & Lebensmittelbanken
-- ============================================================

-- ── DEUTSCHLAND ─────────────────────────────────────────────
('Tafel Deutschland e.V. (Dachverband)', 'tafel',
 'Dachverband von über 970 Tafel-Standorten deutschlandweit – Lebensmittel retten, Menschen helfen.',
 'Germaniastraße 18', '12099', 'Berlin', 'Berlin', 'DE',
 '030 200 59 76-0', 'info@tafel.de', 'https://www.tafel.de',
 'Mo–Fr 9–17 Uhr', ARRAY['Lebensmittelverteilung','Sachspenden','Ehrenamt'], ARRAY['tafel','lebensmittel','deutschland'], TRUE),

('Berliner Tafel e.V.', 'tafel',
 'Die Berliner Tafel versorgt über 350 Ausgabestellen mit geretteten Lebensmitteln.',
 'Beusselstraße 44 N-Q', '10553', 'Berlin', 'Berlin', 'DE',
 '030 782 74 14', 'ber.ta@berliner-tafel.de', 'https://www.berliner-tafel.de',
 'Mo–Fr 9–17 Uhr (Büro)', ARRAY['Lebensmittelverteilung','Ehrenamt','Sachspenden'], ARRAY['tafel','lebensmittel','berlin'], TRUE),

('Hamburger Tafel e.V.', 'tafel',
 'Hamburger Tafel – rettet überschüssige Lebensmittel und verteilt sie an Bedürftige.',
 NULL, NULL, 'Hamburg', 'Hamburg', 'DE',
 '040 300 605 600', 'info@hamburger-tafel.de', 'https://hamburger-tafel.de',
 'Mo–Fr 9–16 Uhr', ARRAY['Lebensmittelverteilung','Ehrenamt'], ARRAY['tafel','lebensmittel','hamburg'], TRUE),

('Münchner Tafel e.V.', 'tafel',
 'Versorgt wöchentlich 22.000 Bedürftige an 30 Ausgabestellen in München.',
 NULL, NULL, 'München', 'Bayern', 'DE',
 '089 292250', 'spenden@muenchner-tafel.de', 'https://muenchner-tafel.de',
 'Mo–Fr 9–16 Uhr', ARRAY['Lebensmittelverteilung','Ausgabestellen','Ehrenamt'], ARRAY['tafel','lebensmittel','münchen'], TRUE),

('Tafel Köln', 'tafel',
 'Tafel Köln – Lebensmittel retten und Menschen helfen in Köln.',
 NULL, NULL, 'Köln', 'Nordrhein-Westfalen', 'DE',
 NULL, 'Info@Tafel.Koeln', 'https://tafel.koeln',
 'Mo–Fr 9–16 Uhr', ARRAY['Lebensmittelverteilung','Sachspenden'], ARRAY['tafel','lebensmittel','köln'], TRUE),

-- ── ÖSTERREICH ──────────────────────────────────────────────
('Wiener Tafel', 'tafel',
 'Österreichs älteste Lebensmittelrettungsorganisation – rettet Lebensmittel und hilft Bedürftigen.',
 'Sechshauser Straße 55', '1150', 'Wien', 'Wien', 'AT',
 '+43 1 786 67 25', 'office@wienertafel.at', 'https://www.wienertafel.at',
 'Mo–Fr 9–17 Uhr', ARRAY['Lebensmittelrettung','Verteilung','Soziale Einrichtungen'], ARRAY['tafel','lebensmittel','wien'], TRUE),

-- ── SCHWEIZ ─────────────────────────────────────────────────
('Schweizer Tafel – Stiftung', 'tafel',
 'Rettet täglich einwandfreie Lebensmittel und gibt sie an soziale Institutionen in der Schweiz weiter.',
 NULL, NULL, 'Zürich', 'Zürich', 'CH',
 NULL, NULL, 'https://schweizertafel.ch',
 NULL, ARRAY['Lebensmittelrettung','Verteilung','Soziale Einrichtungen'], ARRAY['tafel','lebensmittel','schweiz'], TRUE),

-- ============================================================
-- ORGANISATIONS-DATEN: Kleiderkammern & Sozialkaufhäuser
-- ============================================================

('Caritas Berlin – Kleiderkammer & Second-Hand-Laden', 'kleiderkammer',
 'Kleiderkammer und Second-Hand-Laden der Caritas Berlin für Bedürftige.',
 'Residenzstraße 90', '13409', 'Berlin', 'Berlin', 'DE',
 '030 666 33 1222', 'kleiderkammer@caritas-berlin.de', 'https://www.caritas-berlin.de/spenden-engagement/kleiderkammer-second-hand',
 'Mo–Fr 9–13 Uhr', ARRAY['Kleidung','Second-Hand','Spendenannahme'], ARRAY['kleidung','spenden','berlin'], TRUE),

('AWO Berlin – Kleiderkammer', 'kleiderkammer',
 'AWO Kreisverband Südwest Berlin – Kleiderkammer für Menschen mit sozialen Schwierigkeiten.',
 NULL, NULL, 'Berlin', 'Berlin', 'DE',
 '030 713 870 90', NULL, 'https://www.awoberlin.de/service/kleiderkammer',
 'Mo–Fr 10–16 Uhr', ARRAY['Kleidung','Sozialberatung'], ARRAY['kleidung','berlin','awo'], TRUE),

('diakonia Kleiderkammer München', 'kleiderkammer',
 'Kleiderkammer der Diakonia München – versorgt Bedürftige mit Kleidung.',
 'Moosfelder Straße', '81829', 'München', 'Bayern', 'DE',
 NULL, NULL, 'https://diakonia.de/unsere-angebote/kleiderkammern',
 'Mo 16–19 Uhr und nach Termin', ARRAY['Kleidung','Sozialberatung'], ARRAY['kleidung','münchen','diakonie'], TRUE),

('Carla Wien – Caritas Second-Hand-Läden', 'kleiderkammer',
 'Second-Hand-Läden der Caritas Wien – günstig einkaufen und gleichzeitig helfen.',
 'Mittersteig 10', '1050', 'Wien', 'Wien', 'AT',
 '+43 1 890 02 78', 'info@carla-wien.at', 'https://www.carla-wien.at',
 'Mo–Sa 9–18 Uhr', ARRAY['Second-Hand','Kleidung','Möbel','Spendenannahme'], ARRAY['kleidung','möbel','second-hand','wien'], TRUE),

('Caritas Secondhand Schweiz – Kleider bringen', 'kleiderkammer',
 'Caritas Secondhand Schweiz – Kleider spenden und für kleines Geld kaufen.',
 'Birmensdorferstrasse 38', '8004', 'Zürich', 'Zürich', 'CH',
 NULL, NULL, 'https://www.caritas-secondhand.ch',
 'Mo–Sa 10–18 Uhr', ARRAY['Second-Hand','Kleidung','Spendenannahme'], ARRAY['kleidung','second-hand','zürich'], TRUE),

('diakonia-Kaufhaus München – Gebrauchtwarenkaufhaus', 'sozialkaufhaus',
 'Großes Gebrauchtwarenkaufhaus der Diakonia in München – Möbel, Kleidung, Bücher, Elektronik.',
 'Dachauer Straße 189', '80637', 'München', 'Bayern', 'DE',
 NULL, NULL, 'https://diakonia-kaufhaus.de',
 'Mo–Sa 10–18 Uhr', ARRAY['Möbel','Kleidung','Bücher','Elektronik'], ARRAY['möbel','kaufhaus','münchen'], TRUE),

('Weißer Rabe München – GebrauchtWarenHaus', 'sozialkaufhaus',
 'GebrauchtWarenHäuser des Weißen Rabe München in Obersendling und Westend.',
 'Drygalski-Allee 33e', '81477', 'München', 'Bayern', 'DE',
 '089 7474680', 'gebrauchtwaren@weisser-rabe.org', 'https://www.weisser-rabe.org/soziale-betriebe/gebrauchtwarenhaeuser',
 'Mo–Sa 10–18 Uhr', ARRAY['Möbel','Kleidung','Haushalt','Bücher'], ARRAY['möbel','kaufhaus','münchen'], TRUE),

-- ============================================================
-- ORGANISATIONS-DATEN: Krisentelefone & Seelsorge
-- ============================================================

('TelefonSeelsorge Deutschland (0800 111 0 111)', 'krisentelefon',
 'Kostenlose, anonyme Telefonseelsorge – rund um die Uhr erreichbar. Auch Mail- und Chat-Beratung.',
 NULL, NULL, 'Berlin', 'Berlin', 'DE',
 '0800 111 0 111', NULL, 'https://www.telefonseelsorge.de',
 '24/7 kostenlos', ARRAY['Krisenberatung','Seelsorge','Chat','E-Mail-Beratung'], ARRAY['krisentelefon','seelsorge','deutschland','kostenlos'], TRUE),

('TelefonSeelsorge Deutschland (0800 111 0 222)', 'krisentelefon',
 'Zweite kostenlose Notfallleitung der TelefonSeelsorge Deutschland.',
 NULL, NULL, 'Berlin', 'Berlin', 'DE',
 '0800 111 0 222', NULL, 'https://www.telefonseelsorge.de',
 '24/7 kostenlos', ARRAY['Krisenberatung','Seelsorge'], ARRAY['krisentelefon','seelsorge','deutschland'], TRUE),

('TelefonSeelsorge Deutschland (116 123)', 'krisentelefon',
 'Europäische Notfallnummer für emotionale Unterstützung – kostenlos in Deutschland.',
 NULL, NULL, 'Berlin', 'Berlin', 'DE',
 '116 123', NULL, 'https://www.telefonseelsorge.de',
 '24/7 kostenlos', ARRAY['Krisenberatung','Seelsorge'], ARRAY['krisentelefon','notfall','deutschland'], TRUE),

('Telefonseelsorge Österreich (142)', 'krisentelefon',
 'Die österreichische Telefonseelsorge – kostenlos, anonym, rund um die Uhr.',
 NULL, NULL, 'Wien', 'Wien', 'AT',
 '142', NULL, 'https://www.telefonseelsorge.at',
 '24/7 kostenlos', ARRAY['Krisenberatung','Seelsorge','Anonym'], ARRAY['krisentelefon','seelsorge','österreich'], TRUE),

('Rat auf Draht (147) – Kinder- und Jugendtelefon Österreich', 'krisentelefon',
 'Kostenlose Krisenhotline für Kinder und Jugendliche in Österreich.',
 NULL, NULL, 'Wien', 'Wien', 'AT',
 '147', NULL, 'https://www.rataufdraht.at',
 '24/7 kostenlos', ARRAY['Kinder','Jugend','Krisenberatung','Anonym'], ARRAY['krisentelefon','kinder','jugend','österreich'], TRUE),

('Die Dargebotene Hand Schweiz (143)', 'krisentelefon',
 'Schweizer Krisentelefon – jederzeit, anonym und vertraulich. Auch Chat tägl. 10–22 Uhr.',
 NULL, NULL, 'Zürich', 'Zürich', 'CH',
 '143', NULL, 'https://www.143.ch',
 '24/7 kostenlos', ARRAY['Krisenberatung','Chat','E-Mail','Anonym'], ARRAY['krisentelefon','seelsorge','schweiz'], TRUE),

('PSD Wien – Sozialpsychiatrischer Notdienst', 'krisentelefon',
 'Psychiatrische Interventionen im Akut- und Krisenfall in Wien.',
 'Schottengasse 4', '1010', 'Wien', 'Wien', 'AT',
 '01 31330', NULL, 'https://psd-wien.at/information/sozialpsychiatrischer-notdienst',
 '24/7', ARRAY['Psychiatrie','Krisenintervention','Akuthilfe'], ARRAY['krisentelefon','psychiatrie','wien'], TRUE),

-- ============================================================
-- ORGANISATIONS-DATEN: Allgemeine & überregionale Hilfe
-- ============================================================

('Caritas Deutschland', 'allgemein',
 'Größter Wohlfahrtsverband Deutschlands – Nothilfe, Sozialberatung, Flüchtlingshilfe u.v.m.',
 'Karlstraße 40', '79104', 'Freiburg im Breisgau', 'Baden-Württemberg', 'DE',
 '0761 200-0', 'info@caritas.de', 'https://www.caritas.de',
 'Mo–Fr 9–17 Uhr', ARRAY['Sozialberatung','Nothilfe','Flüchtlingshilfe','Pflegehilfe'], ARRAY['caritas','sozialhilfe','deutschland'], TRUE),

('Caritas Österreich', 'allgemein',
 'Die Caritas Österreich hilft in Not – Armutsbekämpfung, Flüchtlingshilfe, Katastrophenhilfe.',
 'Albrechtskreithgasse 19-21', '1160', 'Wien', 'Wien', 'AT',
 '+43 1 878 12-0', 'office@caritas.at', 'https://www.caritas.at',
 'Mo–Fr 9–17 Uhr', ARRAY['Sozialberatung','Nothilfe','Obdachlosenhilfe','Flüchtlingshilfe'], ARRAY['caritas','sozialhilfe','österreich'], TRUE),

('Caritas der Erzdiözese Wien', 'allgemein',
 'Caritas Wien – Hilfe für Menschen in sozialen Notlagen in Wien und Niederösterreich.',
 'Albrechtskreithgasse 19-21', '1160', 'Wien', 'Wien', 'AT',
 '01 878 12-0', 'office@caritas-wien.at', 'https://www.caritas-wien.at',
 'Mo–Fr 9–17 Uhr', ARRAY['Sozialberatung','Obdachlosenhilfe','Kinder','Senioren'], ARRAY['caritas','sozialhilfe','wien'], TRUE),

('Diakonie Deutschland', 'allgemein',
 'Diakonisches Werk der EKD – Soziale Hilfe, Pflege, Beratung, Nothilfe.',
 'Reichensteiner Weg 24', '14195', 'Berlin', 'Berlin', 'DE',
 '030 65211-0', NULL, 'https://www.diakonie.de',
 'Mo–Fr 9–17 Uhr', ARRAY['Sozialberatung','Pflege','Nothilfe','Beratung'], ARRAY['diakonie','sozialhilfe','deutschland'], TRUE),

('Rotes Kreuz Österreich', 'allgemein',
 'Österreichisches Rotes Kreuz – Rettungsdienst, Katastrophenhilfe, Soziale Dienste.',
 'Wiedner Hauptstraße 32', '1040', 'Wien', 'Wien', 'AT',
 '+43 1 589 00-0', 'office@roteskreuz.at', 'https://www.roteskreuz.at',
 '24/7 Notruf 144', ARRAY['Rettungsdienst','Katastrophenhilfe','Sozialdienste','Blutspende'], ARRAY['roteskreuz','nothilfe','österreich'], TRUE),

('Schweizerisches Rotes Kreuz', 'allgemein',
 'Schweizerisches Rotes Kreuz – Humanitäre Hilfe, Gesundheit, Integration.',
 'Rainmattstrasse 10', '3001', 'Bern', 'Bern', 'CH',
 '+41 31 387 71 11', 'info@redcross.ch', 'https://www.redcross.ch',
 'Mo–Fr 8–17 Uhr', ARRAY['Humanitäre Hilfe','Gesundheit','Integration','Katastrophenhilfe'], ARRAY['roteskreuz','nothilfe','schweiz'], TRUE),

('Volkshilfe Wien', 'allgemein',
 'Volkshilfe Wien – Sozialberatung, Obdachlosenhilfe, Second-Hand-Shops (TAV).',
 'Großfeldsiedlung 8/2', '1210', 'Wien', 'Wien', 'AT',
 '+43 1 402 6002', 'info@volkshilfe-wien.at', 'https://www.volkshilfe-wien.at',
 'Mo–Fr 9–17 Uhr', ARRAY['Sozialberatung','Second-Hand','Obdachlosenhilfe'], ARRAY['volkshilfe','sozialhilfe','wien'], TRUE),

('AWO – Arbeiterwohlfahrt Deutschland', 'allgemein',
 'Einer der sechs Spitzenverbände der freien Wohlfahrtspflege in Deutschland.',
 'Blücherstraße 62-63', '10961', 'Berlin', 'Berlin', 'DE',
 '030 26309-0', 'info@awo.org', 'https://www.awo.org',
 'Mo–Fr 9–17 Uhr', ARRAY['Sozialberatung','Kinder','Senioren','Pflege'], ARRAY['awo','sozialhilfe','deutschland'], TRUE);

-- ============================================================
-- POSTS: Fehlende Spalten ergänzen (falls nicht vorhanden)
-- ============================================================

-- Tags-Array auf posts (bereits per App genutzt, aber evtl. nicht in Schema)
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

-- location_text (Freitext-Standort, für UI-Anzeige)
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS location_text TEXT;

-- ============================================================
-- POSTS: Type-Constraint aktualisieren (mehr gültige Typen)
-- ============================================================

-- Bestehenden Constraint entfernen und neu setzen mit mehr Typen
ALTER TABLE public.posts
  DROP CONSTRAINT IF EXISTS posts_type_check;

ALTER TABLE public.posts
  ADD CONSTRAINT posts_type_check CHECK (type IN (
    'rescue','animal','housing','supply','mobility',
    'sharing','community','crisis',
    'help_request','help_offer','skill','knowledge','mental'
  ));

-- ============================================================
-- INDEX-OPTIMIERUNGEN für bessere Performance
-- ============================================================

-- Volltext-Suche auf Posts
CREATE INDEX IF NOT EXISTS idx_posts_title_search
  ON public.posts USING gin(to_tsvector('german', title));

CREATE INDEX IF NOT EXISTS idx_posts_tags
  ON public.posts USING gin(tags);

-- Organizations Volltextsuche
CREATE INDEX IF NOT EXISTS idx_org_name_search
  ON public.organizations USING gin(to_tsvector('german', name));

CREATE INDEX IF NOT EXISTS idx_org_tags
  ON public.organizations USING gin(tags);
