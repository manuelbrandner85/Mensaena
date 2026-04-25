-- ── Gruppen-Post-Bilder + fehlende Bild-Spalten 2026-04-25 ────────────────────
-- Wendet image_upload_expansion-Spalten nach, falls noch nicht geschehen,
-- und fügt group_posts.image_url hinzu.

-- 1. Profil-Cover (war in 20260424_image_uploads_expansion.sql, sicherstellen)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS cover_url TEXT;

-- 2. Gruppen: Avatar + Banner (ebenfalls sicherstellen)
ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS banner_url TEXT;

-- 3. Gruppen-Posts: optionales Bild pro Beitrag (NEU)
ALTER TABLE public.group_posts
  ADD COLUMN IF NOT EXISTS image_url TEXT;
