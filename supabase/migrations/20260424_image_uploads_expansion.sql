-- ── Bild-Upload-Erweiterungen 2026-04-24 ──────────────────────────────────────
-- Fügt fehlende Bild-Spalten für alle Module hinzu, die Foto-Uploads erhalten.

-- 1. Profil Cover-Foto (Headerbanner wie LinkedIn/Facebook)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS cover_url TEXT;

-- 2. Erfolgsgeschichten: optionales Foto zur Geschichte
ALTER TABLE public.success_stories
  ADD COLUMN IF NOT EXISTS image_url TEXT;

-- 3. Schwarzes Brett: mehrere Bilder (bisher nur ein image_url)
ALTER TABLE public.board_posts
  ADD COLUMN IF NOT EXISTS media_urls TEXT[] DEFAULT '{}';

-- 4. Hofladen/Farm-Listings: Galerie statt Einzelbild
ALTER TABLE public.farm_listings
  ADD COLUMN IF NOT EXISTS media_urls TEXT[] DEFAULT '{}';

-- 5. Chat-Kanäle: Avatar + Banner für Gruppenidentität
ALTER TABLE public.chat_channels
  ADD COLUMN IF NOT EXISTS avatar_url  TEXT,
  ADD COLUMN IF NOT EXISTS banner_url  TEXT;

-- 6. Gruppen: Avatar + Banner
ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS avatar_url  TEXT,
  ADD COLUMN IF NOT EXISTS banner_url  TEXT;

-- 7. Krisenberichte: optionales Abschluss-Foto ("Problem gelöst"-Bild)
ALTER TABLE public.crisis_posts
  ADD COLUMN IF NOT EXISTS resolved_image_url TEXT;

-- Storage-Buckets für neue Felder sicherstellen
-- (Buckets werden via Supabase-Dashboard oder seed.sql angelegt;
--  hier nur Policy-Grants für bestehende Buckets erweitern)

-- Profil-Cover kann in den avatars-Bucket (bereits öffentlich lesbar)
-- Farm-Galerie in post-images-Bucket (bereits öffentlich lesbar)
-- Crisis resolved in crisis-images-Bucket (bereits öffentlich lesbar)
-- Groups/Channels in chat-images-Bucket (bereits öffentlich lesbar)
