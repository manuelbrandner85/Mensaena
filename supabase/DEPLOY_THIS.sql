-- ============================================================
-- MENSAENA – Vollständiges Deployment SQL
-- Datum: 2026-03-31
-- Projekt: huaqldjkgyosefzfhjnf
-- ============================================================
-- Anleitung:
-- 1. Öffne: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new
-- 2. Kopiere diesen gesamten Inhalt
-- 3. Klicke 'Run' (▶)
-- ============================================================

-- ============================================================
-- MENSAENA – Supabase PostgreSQL Schema
-- Version: 1.0.0
-- ============================================================
-- Architektur-Entscheidung:
-- Supabase: Auth, Daten, Profile, Inhalte, Echtzeit-Chat
-- Cloudflare: CDN, WAF, Caching, DDoS-Schutz, Rate Limiting
-- ============================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- PostGIS: optional, nur wenn verfügbar
-- CREATE EXTENSION IF NOT EXISTS "postgis" SCHEMA public;

-- ============================================================
-- UPDATED_AT TRIGGER FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TABLE: profiles
-- Erweitert Supabase auth.users mit Profildaten
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name          TEXT,
  nickname      TEXT UNIQUE,
  email         TEXT,
  location      TEXT,
  skills        TEXT[],
  avatar_url    TEXT,
  bio           TEXT,
  trust_score   INTEGER DEFAULT 0 CHECK (trust_score >= 0),
  impact_score  INTEGER DEFAULT 0 CHECK (impact_score >= 0),
  created_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TRIGGER handle_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_profiles_nickname ON public.profiles(nickname);
CREATE INDEX IF NOT EXISTS idx_profiles_location  ON public.profiles(location);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, name, email)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.email
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- TABLE: posts
-- Zentrale Beiträge aller Kategorien
-- ============================================================
CREATE TABLE IF NOT EXISTS public.posts (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type              TEXT NOT NULL CHECK (type IN (
    'help_needed','help_offered','rescue','animal','housing',
    'supply','mobility','sharing','crisis','community'
  )),
  category          TEXT NOT NULL DEFAULT 'general' CHECK (category IN (
    'food','everyday','moving','animals','housing','knowledge',
    'skills','mental','mobility','sharing','emergency','general'
  )),
  title             TEXT NOT NULL CHECK (char_length(title) BETWEEN 5 AND 120),
  description       TEXT NOT NULL CHECK (char_length(description) >= 20),
  image_urls        TEXT[],
  latitude          DOUBLE PRECISION,
  longitude         DOUBLE PRECISION,
  urgency           TEXT NOT NULL DEFAULT 'medium' CHECK (urgency IN ('low','medium','high','critical')),
  contact_phone     TEXT,
  contact_whatsapp  TEXT,
  contact_email     TEXT,
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','fulfilled','archived','pending')),
  created_at        TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at        TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TRIGGER handle_posts_updated_at
  BEFORE UPDATE ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_posts_user_id    ON public.posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_type       ON public.posts(type);
CREATE INDEX IF NOT EXISTS idx_posts_status     ON public.posts(status);
CREATE INDEX IF NOT EXISTS idx_posts_urgency    ON public.posts(urgency);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON public.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_coords     ON public.posts(latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- ============================================================
-- TABLE: interactions
-- Helfer-Reaktionen auf Beiträge
-- ============================================================
CREATE TABLE IF NOT EXISTS public.interactions (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id     UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  helper_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','completed','cancelled')),
  message     TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(post_id, helper_id)
);

CREATE TRIGGER handle_interactions_updated_at
  BEFORE UPDATE ON public.interactions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_interactions_post_id   ON public.interactions(post_id);
CREATE INDEX IF NOT EXISTS idx_interactions_helper_id ON public.interactions(helper_id);

-- ============================================================
-- TABLE: conversations
-- Chat-Kanäle (Direkt, Gruppen, System)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.conversations (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type        TEXT NOT NULL DEFAULT 'direct' CHECK (type IN ('direct','group','system')),
  title       TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_conversations_type ON public.conversations(type);

-- ============================================================
-- TABLE: conversation_members
-- Mitglieder in Gesprächen
-- ============================================================
CREATE TABLE IF NOT EXISTS public.conversation_members (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_conv_members_conv_id  ON public.conversation_members(conversation_id);
CREATE INDEX IF NOT EXISTS idx_conv_members_user_id  ON public.conversation_members(user_id);

-- ============================================================
-- TABLE: messages
-- Nachrichten in Gesprächen
-- ============================================================
CREATE TABLE IF NOT EXISTS public.messages (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  content         TEXT NOT NULL CHECK (char_length(content) >= 1),
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  read_at         TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_messages_conv_id    ON public.messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id  ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);

-- ============================================================
-- TABLE: saved_posts
-- Gespeicherte / gemerknte Beiträge
-- ============================================================
CREATE TABLE IF NOT EXISTS public.saved_posts (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  post_id    UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_saved_posts_user_id ON public.saved_posts(user_id);

-- ============================================================
-- TABLE: notifications
-- Systembenachrichtigungen
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type       TEXT NOT NULL CHECK (type IN ('message','interaction','post_update','system','help_found')),
  title      TEXT NOT NULL,
  body       TEXT NOT NULL,
  link       TEXT,
  read_at    TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id   ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read_at   ON public.notifications(read_at) WHERE read_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);

-- ============================================================
-- TABLE: trust_ratings
-- Bewertungen zwischen Nutzern
-- ============================================================
CREATE TABLE IF NOT EXISTS public.trust_ratings (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rater_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rated_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  score       INTEGER NOT NULL CHECK (score BETWEEN 1 AND 5),
  comment     TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(rater_id, rated_id)
);

CREATE INDEX IF NOT EXISTS idx_trust_ratings_rated_id ON public.trust_ratings(rated_id);

-- Update trust score after new rating
CREATE OR REPLACE FUNCTION public.update_trust_score()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.profiles
  SET trust_score = (
    SELECT COALESCE(ROUND(AVG(score) * 20), 0)::INTEGER
    FROM public.trust_ratings
    WHERE rated_id = NEW.rated_id
  )
  WHERE id = NEW.rated_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER on_trust_rating_insert
  AFTER INSERT OR UPDATE ON public.trust_ratings
  FOR EACH ROW EXECUTE FUNCTION public.update_trust_score();

-- ============================================================
-- TABLE: regions
-- Regionale Gruppen für lokale Filterung
-- ============================================================
CREATE TABLE IF NOT EXISTS public.regions (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name       TEXT NOT NULL UNIQUE,
  slug       TEXT NOT NULL UNIQUE,
  lat        DOUBLE PRECISION,
  lng        DOUBLE PRECISION,
  radius_km  INTEGER DEFAULT 10,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================
-- RLS POLICIES – Row Level Security
-- ============================================================

-- Profiles: öffentlich lesbar, nur eigene schreiben
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_public_read" ON public.profiles
  FOR SELECT USING (true);

CREATE POLICY "profiles_own_insert" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_own_update" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Posts: aktive öffentlich lesbar, eigene bearbeiten
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "posts_public_read" ON public.posts
  FOR SELECT USING (status = 'active' OR auth.uid() = user_id);

CREATE POLICY "posts_auth_insert" ON public.posts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "posts_own_update" ON public.posts
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "posts_own_delete" ON public.posts
  FOR DELETE USING (auth.uid() = user_id);

-- Interactions
ALTER TABLE public.interactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "interactions_read" ON public.interactions
  FOR SELECT USING (
    auth.uid() = helper_id OR
    auth.uid() = (SELECT user_id FROM public.posts WHERE id = post_id)
  );

CREATE POLICY "interactions_insert" ON public.interactions
  FOR INSERT WITH CHECK (auth.uid() = helper_id);

CREATE POLICY "interactions_update" ON public.interactions
  FOR UPDATE USING (auth.uid() = helper_id);

-- Conversations
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "conversations_member_read" ON public.conversations
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.conversation_members
      WHERE conversation_id = id AND user_id = auth.uid()
    )
  );

CREATE POLICY "conversations_auth_insert" ON public.conversations
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Conversation Members
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "conv_members_read" ON public.conversation_members
  FOR SELECT USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = conversation_id AND cm.user_id = auth.uid()
    )
  );

CREATE POLICY "conv_members_insert" ON public.conversation_members
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Messages
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "messages_conversation_read" ON public.messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.conversation_members
      WHERE conversation_id = messages.conversation_id AND user_id = auth.uid()
    )
  );

CREATE POLICY "messages_auth_insert" ON public.messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Saved Posts
ALTER TABLE public.saved_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "saved_posts_own" ON public.saved_posts
  USING (auth.uid() = user_id);

CREATE POLICY "saved_posts_insert" ON public.saved_posts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_own" ON public.notifications
  USING (auth.uid() = user_id);

-- Trust Ratings
ALTER TABLE public.trust_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "trust_ratings_read" ON public.trust_ratings
  FOR SELECT USING (true);

CREATE POLICY "trust_ratings_insert" ON public.trust_ratings
  FOR INSERT WITH CHECK (
    auth.uid() = rater_id AND rater_id != rated_id
  );

-- Regions: öffentlich lesbar
ALTER TABLE public.regions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "regions_public_read" ON public.regions
  FOR SELECT USING (true);


-- ============================================================
-- SEED DATA
-- ============================================================
-- ============================================================
-- MENSAENA – Seed Data für Entwicklung und Demo
-- ============================================================

-- Test-Nutzer werden über Supabase Auth erstellt,
-- Profile werden automatisch via Trigger angelegt.
-- Diese Seed-Daten setzen vorhandene Profile voraus.

-- Temporäre Test-Profile (UUID manuell eintragen nach Auth-Registrierung)
-- Für Demo-Zwecke: Direkt einfügen mit bekannten IDs

-- Demo Regions
INSERT INTO public.regions (name, slug, lat, lng, radius_km) VALUES
  ('München Mitte',      'muenchen-mitte',     48.1351, 11.5820, 5),
  ('München Schwabing',  'muenchen-schwabing',  48.1590, 11.5880, 4),
  ('München Maxvorstadt','muenchen-maxvorstadt',48.1490, 11.5720, 3),
  ('Berlin Mitte',       'berlin-mitte',        52.5200, 13.4050, 5),
  ('Hamburg Altona',     'hamburg-altona',      53.5500, 9.9350,  4),
  ('Köln Innenstadt',    'koeln-innenstadt',    50.9333, 6.9500,  5)
ON CONFLICT (slug) DO NOTHING;

-- Demo Posts (werden nach Nutzer-Registrierung über UI erstellt)
-- Beispiel-SQL für manuelles Seeding nach Nutzeranmeldung:
-- Demo Posts: Werden über die App erstellt


-- ============================================================
-- REALTIME KONFIGURATION
-- ============================================================
-- ============================================================
-- MENSAENA – Supabase Realtime Konfiguration
-- Realtime nur für sinnvolle Tabellen aktivieren
-- ============================================================

-- Realtime für Nachrichten (Chat)
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;

-- Realtime für Benachrichtigungen
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- Realtime für Posts (Live-Updates auf Karte)
ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;


-- ============================================================
-- DEPLOYMENT ABGESCHLOSSEN
-- ============================================================
SELECT 'Mensaena Schema erfolgreich deployed!' as status,
       NOW() as timestamp;
