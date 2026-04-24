-- ============================================================================
-- MENSAENA – Organizations System Migration
-- Tables: organizations (ALTER), organization_reviews, organization_review_helpful,
--         organization_suggestions
-- RPCs: search_organizations, get_organization_stats, update_organization_rating
-- Storage: organization-images bucket
-- ============================================================================

-- Ensure extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. ALTER organizations – add new columns (table already exists from 008)
-- ============================================================================

ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS slug TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS short_description TEXT,
  ADD COLUMN IF NOT EXISTS logo_url TEXT,
  ADD COLUMN IF NOT EXISTS cover_image_url TEXT,
  ADD COLUMN IF NOT EXISTS fax TEXT,
  ADD COLUMN IF NOT EXISTS opening_hours_json JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS accessibility JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS target_groups TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS languages TEXT[] DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS is_emergency BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS rating_avg NUMERIC(2,1) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Create slug from name for existing rows
UPDATE public.organizations
  SET slug = LOWER(REGEXP_REPLACE(REGEXP_REPLACE(name, '[^a-zA-Z0-9\- ]', '', 'g'), '\s+', '-', 'g'))
  || '-' || SUBSTRING(id::text, 1, 8)
  WHERE slug IS NULL;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_org_slug ON public.organizations(slug);
CREATE INDEX IF NOT EXISTS idx_org_name_trgm ON public.organizations USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_org_rating ON public.organizations(rating_avg DESC);
CREATE INDEX IF NOT EXISTS idx_org_emergency ON public.organizations(is_emergency) WHERE is_emergency = TRUE;
CREATE INDEX IF NOT EXISTS idx_org_coords ON public.organizations(latitude, longitude) WHERE latitude IS NOT NULL;

-- Full-text search column
ALTER TABLE public.organizations ADD COLUMN IF NOT EXISTS fts tsvector;

-- Populate fts
UPDATE public.organizations SET fts = to_tsvector('german',
  COALESCE(name, '') || ' ' || COALESCE(description, '') || ' ' ||
  COALESCE(city, '') || ' ' || COALESCE(address, '')
);

CREATE INDEX IF NOT EXISTS idx_org_fts ON public.organizations USING gin(fts);

-- Trigger to keep fts up to date
CREATE OR REPLACE FUNCTION public.organizations_fts_update()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.fts := to_tsvector('german',
    COALESCE(NEW.name, '') || ' ' || COALESCE(NEW.description, '') || ' ' ||
    COALESCE(NEW.city, '') || ' ' || COALESCE(NEW.address, '')
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_organizations_fts ON public.organizations;
CREATE TRIGGER trg_organizations_fts
  BEFORE INSERT OR UPDATE ON public.organizations
  FOR EACH ROW EXECUTE FUNCTION public.organizations_fts_update();

-- ============================================================================
-- 2. TABLE: organization_reviews
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.organization_reviews (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id  UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating           SMALLINT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  title            TEXT,
  content          TEXT NOT NULL CHECK (LENGTH(content) >= 10),
  is_reported      BOOLEAN DEFAULT FALSE,
  report_reason    TEXT,
  admin_response   TEXT,
  admin_response_at TIMESTAMPTZ,
  helpful_count    INTEGER DEFAULT 0,
  created_at       TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at       TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(organization_id, user_id)
);

DROP TRIGGER IF EXISTS handle_org_reviews_updated_at ON public.organization_reviews;
CREATE TRIGGER handle_org_reviews_updated_at
  BEFORE UPDATE ON public.organization_reviews
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_org_reviews_org ON public.organization_reviews(organization_id);
CREATE INDEX IF NOT EXISTS idx_org_reviews_user ON public.organization_reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_org_reviews_rating ON public.organization_reviews(rating);

ALTER TABLE public.organization_reviews ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 3. TABLE: organization_review_helpful
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.organization_review_helpful (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  review_id  UUID NOT NULL REFERENCES public.organization_reviews(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(review_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_review_helpful_review ON public.organization_review_helpful(review_id);

ALTER TABLE public.organization_review_helpful ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 4. TABLE: organization_suggestions
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.organization_suggestions (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL CHECK (LENGTH(name) >= 3),
  description TEXT,
  category    TEXT NOT NULL DEFAULT 'allgemein',
  address     TEXT,
  city        TEXT,
  country     TEXT NOT NULL DEFAULT 'DE',
  phone       TEXT,
  email       TEXT,
  website     TEXT,
  status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_notes TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_org_suggestions_status ON public.organization_suggestions(status);
CREATE INDEX IF NOT EXISTS idx_org_suggestions_user ON public.organization_suggestions(user_id);

ALTER TABLE public.organization_suggestions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 5. RLS Policies
-- ============================================================================

-- Organizations: public read active, admin write
DO $$ BEGIN
  -- already exists from 008: organizations_public_read
  -- Add admin write policy
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='organizations' AND policyname='organizations_admin_write') THEN
    CREATE POLICY "organizations_admin_write"
      ON public.organizations FOR ALL USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
      );
  END IF;
END $$;

-- Reviews: authenticated read, own insert/update/delete
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='organization_reviews' AND policyname='org_reviews_read') THEN
    CREATE POLICY "org_reviews_read"
      ON public.organization_reviews FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='organization_reviews' AND policyname='org_reviews_insert') THEN
    CREATE POLICY "org_reviews_insert"
      ON public.organization_reviews FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='organization_reviews' AND policyname='org_reviews_update') THEN
    CREATE POLICY "org_reviews_update"
      ON public.organization_reviews FOR UPDATE USING (
        auth.uid() = user_id
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
      );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='organization_reviews' AND policyname='org_reviews_delete') THEN
    CREATE POLICY "org_reviews_delete"
      ON public.organization_reviews FOR DELETE USING (
        auth.uid() = user_id
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
      );
  END IF;
END $$;

-- Review helpful: authenticated
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='organization_review_helpful' AND policyname='org_helpful_read') THEN
    CREATE POLICY "org_helpful_read"
      ON public.organization_review_helpful FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='organization_review_helpful' AND policyname='org_helpful_insert') THEN
    CREATE POLICY "org_helpful_insert"
      ON public.organization_review_helpful FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='organization_review_helpful' AND policyname='org_helpful_delete') THEN
    CREATE POLICY "org_helpful_delete"
      ON public.organization_review_helpful FOR DELETE USING (auth.uid() = user_id);
  END IF;
END $$;

-- Suggestions: own read + insert, admin all
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='organization_suggestions' AND policyname='org_suggestions_read') THEN
    CREATE POLICY "org_suggestions_read"
      ON public.organization_suggestions FOR SELECT USING (
        auth.uid() = user_id
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
      );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='organization_suggestions' AND policyname='org_suggestions_insert') THEN
    CREATE POLICY "org_suggestions_insert"
      ON public.organization_suggestions FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='organization_suggestions' AND policyname='org_suggestions_admin_update') THEN
    CREATE POLICY "org_suggestions_admin_update"
      ON public.organization_suggestions FOR UPDATE USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
      );
  END IF;
END $$;

-- ============================================================================
-- 6. Trigger: update_organization_rating (auto on review change)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_organization_rating()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_org_id UUID;
  v_avg NUMERIC(2,1);
  v_count INTEGER;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_org_id := OLD.organization_id;
  ELSE
    v_org_id := NEW.organization_id;
  END IF;

  SELECT COALESCE(AVG(rating)::NUMERIC(2,1), 0), COUNT(*)
    INTO v_avg, v_count
    FROM public.organization_reviews
    WHERE organization_id = v_org_id;

  UPDATE public.organizations
    SET rating_avg = v_avg, rating_count = v_count
    WHERE id = v_org_id;

  IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_org_rating ON public.organization_reviews;
CREATE TRIGGER trg_update_org_rating
  AFTER INSERT OR UPDATE OR DELETE ON public.organization_reviews
  FOR EACH ROW EXECUTE FUNCTION public.update_organization_rating();

-- ============================================================================
-- 7. RPC: search_organizations
-- ============================================================================

CREATE OR REPLACE FUNCTION public.search_organizations(
  p_search TEXT DEFAULT '',
  p_category TEXT DEFAULT 'all',
  p_country TEXT DEFAULT 'all',
  p_verified_only BOOLEAN DEFAULT FALSE,
  p_is_emergency BOOLEAN DEFAULT FALSE,
  p_min_rating NUMERIC DEFAULT 0,
  p_sort_by TEXT DEFAULT 'name',
  p_lat DOUBLE PRECISION DEFAULT NULL,
  p_lng DOUBLE PRECISION DEFAULT NULL,
  p_radius_km DOUBLE PRECISION DEFAULT 50,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
  id UUID, slug TEXT, name TEXT, short_description TEXT, description TEXT,
  category TEXT, logo_url TEXT, cover_image_url TEXT,
  address TEXT, zip_code TEXT, city TEXT, state TEXT, country TEXT,
  latitude DOUBLE PRECISION, longitude DOUBLE PRECISION,
  phone TEXT, fax TEXT, email TEXT, website TEXT,
  opening_hours_text TEXT, opening_hours_json JSONB, accessibility JSONB,
  services TEXT[], target_groups TEXT[], languages TEXT[], tags TEXT[],
  is_verified BOOLEAN, is_active BOOLEAN, is_emergency BOOLEAN,
  rating_avg NUMERIC, rating_count INTEGER, source_url TEXT,
  created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ,
  distance_km DOUBLE PRECISION
)
LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT
    o.id, o.slug, o.name, o.short_description, o.description,
    o.category, o.logo_url, o.cover_image_url,
    o.address, o.zip_code, o.city, o.state, o.country,
    o.latitude, o.longitude,
    o.phone, o.fax, o.email, o.website,
    o.opening_hours AS opening_hours_text,
    o.opening_hours_json, o.accessibility,
    o.services, o.target_groups, o.languages, o.tags,
    o.is_verified, o.is_active, o.is_emergency,
    o.rating_avg, o.rating_count, o.source_url,
    o.created_at, o.updated_at,
    CASE
      WHEN p_lat IS NOT NULL AND p_lng IS NOT NULL AND o.latitude IS NOT NULL AND o.longitude IS NOT NULL THEN
        ROUND((111.045 * acos(
          LEAST(1.0, cos(radians(p_lat)) * cos(radians(o.latitude))
            * cos(radians(o.longitude) - radians(p_lng))
            + sin(radians(p_lat)) * sin(radians(o.latitude)))
        ))::numeric, 1)::double precision
      ELSE NULL
    END AS distance_km
  FROM public.organizations o
  WHERE o.is_active = TRUE
    AND (p_category = 'all' OR o.category = p_category)
    AND (p_country = 'all' OR o.country = p_country)
    AND (NOT p_verified_only OR o.is_verified = TRUE)
    AND (NOT p_is_emergency OR o.is_emergency = TRUE)
    AND (o.rating_avg >= p_min_rating)
    AND (
      p_search = '' OR p_search IS NULL
      OR o.fts @@ plainto_tsquery('german', p_search)
      OR o.name ILIKE '%' || p_search || '%'
      OR o.city ILIKE '%' || p_search || '%'
    )
    AND (
      p_lat IS NULL OR p_lng IS NULL
      OR o.latitude IS NULL OR o.longitude IS NULL
      OR (111.045 * acos(
          LEAST(1.0, cos(radians(p_lat)) * cos(radians(o.latitude))
            * cos(radians(o.longitude) - radians(p_lng))
            + sin(radians(p_lat)) * sin(radians(o.latitude)))
        )) <= p_radius_km
    )
  ORDER BY
    CASE WHEN p_sort_by = 'name' THEN o.name END ASC,
    CASE WHEN p_sort_by = 'rating' THEN o.rating_avg END DESC,
    CASE WHEN p_sort_by = 'newest' THEN o.created_at END DESC,
    CASE WHEN p_sort_by = 'distance' AND p_lat IS NOT NULL THEN
      (111.045 * acos(
        LEAST(1.0, cos(radians(p_lat)) * cos(radians(o.latitude))
          * cos(radians(o.longitude) - radians(p_lng))
          + sin(radians(p_lat)) * sin(radians(o.latitude)))
      ))
    END ASC NULLS LAST,
    o.name ASC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- ============================================================================
-- 8. RPC: get_organization_stats
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_organization_stats()
RETURNS JSON LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'total_organizations', (SELECT COUNT(*) FROM public.organizations WHERE is_active = TRUE),
    'verified_count', (SELECT COUNT(*) FROM public.organizations WHERE is_active = TRUE AND is_verified = TRUE),
    'total_reviews', (SELECT COUNT(*) FROM public.organization_reviews),
    'avg_rating', (SELECT COALESCE(ROUND(AVG(rating)::numeric, 1), 0) FROM public.organization_reviews),
    'categories', (
      SELECT COALESCE(json_agg(row_to_json(cats)), '[]'::json)
      FROM (
        SELECT category, COUNT(*) as count
        FROM public.organizations
        WHERE is_active = TRUE
        GROUP BY category
        ORDER BY count DESC
      ) cats
    )
  ) INTO result;
  RETURN result;
END;
$$;

-- ============================================================================
-- 9. Storage bucket: organization-images
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'organization-images',
  'organization-images',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='objects' AND policyname='org_images_public_read') THEN
    CREATE POLICY "org_images_public_read"
      ON storage.objects FOR SELECT USING (bucket_id = 'organization-images');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='objects' AND policyname='org_images_auth_upload') THEN
    CREATE POLICY "org_images_auth_upload"
      ON storage.objects FOR INSERT WITH CHECK (
        bucket_id = 'organization-images' AND auth.role() = 'authenticated'
      );
  END IF;
END $$;

-- ============================================================================
-- 10. SEED: 18 realistic organizations with new columns
-- ============================================================================

-- Update existing rows with slug, short_description, target_groups, languages, etc.
-- Then insert any missing ones

-- Helper to generate slug
CREATE OR REPLACE FUNCTION public.generate_org_slug(p_name TEXT, p_city TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN
  RETURN LOWER(
    REGEXP_REPLACE(
      REGEXP_REPLACE(
        REGEXP_REPLACE(p_name || '-' || p_city, '[^a-zA-Z0-9 -]', '', 'g'),
        '\s+', '-', 'g'
      ),
      '-+', '-', 'g'
    )
  );
END;
$$;

-- Insert seed organizations (ON CONFLICT DO NOTHING using name+city uniqueness via slug)
INSERT INTO public.organizations (
  id, slug, name, short_description, description, category,
  address, zip_code, city, state, country,
  latitude, longitude, phone, email, website,
  opening_hours, opening_hours_json,
  services, target_groups, languages, tags,
  is_verified, is_active, is_emergency, accessibility
) VALUES
-- 1. Caritas Berlin
(
  uuid_generate_v4(),
  'caritas-berlin',
  'Caritas Berlin',
  'Soziale Dienste und Beratung fuer Menschen in Not',
  'Der Caritasverband fuer das Erzbistum Berlin e.V. bietet umfassende soziale Dienste, Beratung und Unterstuetzung fuer Menschen in schwierigen Lebenssituationen. Angebote umfassen Schuldnerberatung, Familienhilfe, Suchtberatung und Wohnungslosenhilfe.',
  'allgemein',
  'Residenzstrasse 90', '13409', 'Berlin', 'Berlin', 'DE',
  52.5645, 13.3732, '+49 30 66633-0', 'info@caritas-berlin.de', 'https://www.caritas-berlin.de',
  'Mo-Fr 08:00-17:00',
  '{"monday":{"open":"08:00","close":"17:00"},"tuesday":{"open":"08:00","close":"17:00"},"wednesday":{"open":"08:00","close":"17:00"},"thursday":{"open":"08:00","close":"17:00"},"friday":{"open":"08:00","close":"17:00"},"saturday":{"closed":true},"sunday":{"closed":true}}'::jsonb,
  ARRAY['beratung', 'finanziell', 'psychologisch', 'rechtlich', 'sachspenden'],
  ARRAY['alle', 'familien', 'senioren', 'obdachlose'],
  ARRAY['Deutsch', 'Englisch', 'Arabisch', 'Tuerkisch'],
  ARRAY['Wohlfahrt', 'Sozialberatung', 'Schuldnerberatung'],
  true, true, false,
  '{"wheelchair":true,"elevator":true,"public_transport":true,"barrier_free_entrance":true,"accessible_toilet":true}'::jsonb
),
-- 2. Diakonie Hamburg
(
  uuid_generate_v4(),
  'diakonie-hamburg',
  'Diakonie Hamburg',
  'Evangelische Hilfsorganisation mit vielfaeltigen Angeboten',
  'Das Diakonische Werk Hamburg bietet Unterstuetzung in den Bereichen Wohnungslosenhilfe, Suchthilfe, Pflege, Kinder- und Jugendhilfe sowie Fluechtlingsarbeit.',
  'allgemein',
  'Koenigstrasse 54', '22767', 'Hamburg', 'Hamburg', 'DE',
  53.5544, 9.9453, '+49 40 30620-0', 'info@diakonie-hamburg.de', 'https://www.diakonie-hamburg.de',
  'Mo-Fr 09:00-16:00',
  '{"monday":{"open":"09:00","close":"16:00"},"tuesday":{"open":"09:00","close":"16:00"},"wednesday":{"open":"09:00","close":"16:00"},"thursday":{"open":"09:00","close":"16:00"},"friday":{"open":"09:00","close":"16:00"},"saturday":{"closed":true},"sunday":{"closed":true}}'::jsonb,
  ARRAY['beratung', 'unterkunft', 'psychologisch', 'arbeit', 'kinderbetreuung'],
  ARRAY['alle', 'familien', 'gefluechtete', 'suchtkranke'],
  ARRAY['Deutsch', 'Englisch'],
  ARRAY['Diakonie', 'Evangelisch', 'Sozialarbeit'],
  true, true, false,
  '{"wheelchair":true,"public_transport":true}'::jsonb
),
-- 3. DRK Muenchen
(
  uuid_generate_v4(),
  'drk-muenchen',
  'DRK Kreisverband Muenchen',
  'Deutsches Rotes Kreuz mit Rettungsdienst und Sozialarbeit',
  'Der DRK Kreisverband Muenchen bietet Rettungsdienst, Erste-Hilfe-Kurse, Katastrophenschutz, Seniorenhilfe, Kleiderkammern und Sozialberatung.',
  'allgemein',
  'Seebauerstrasse 14', '81377', 'Muenchen', 'Bayern', 'DE',
  48.1249, 11.5118, '+49 89 2373-0', 'info@brk-muenchen.de', 'https://www.brk-muenchen.de',
  'Mo-Fr 08:00-18:00, Sa 09:00-13:00',
  '{"monday":{"open":"08:00","close":"18:00"},"tuesday":{"open":"08:00","close":"18:00"},"wednesday":{"open":"08:00","close":"18:00"},"thursday":{"open":"08:00","close":"18:00"},"friday":{"open":"08:00","close":"18:00"},"saturday":{"open":"09:00","close":"13:00"},"sunday":{"closed":true}}'::jsonb,
  ARRAY['notfallhilfe', 'beratung', 'kleidung', 'medizin'],
  ARRAY['alle', 'senioren'],
  ARRAY['Deutsch', 'Englisch'],
  ARRAY['Rotes Kreuz', 'Rettungsdienst', 'Erste Hilfe'],
  true, true, true,
  '{"wheelchair":true,"elevator":true,"public_transport":true,"parking":true}'::jsonb
),
-- 4. Berliner Tafel
(
  uuid_generate_v4(),
  'berliner-tafel',
  'Berliner Tafel e.V.',
  'Groesste Tafel Deutschlands – Lebensmittel fuer Beduerftige',
  'Die Berliner Tafel sammelt ueberschuessige Lebensmittel und verteilt sie an soziale Einrichtungen und Beduerftige. Ueber 300 Ausgabestellen in Berlin.',
  'tafel',
  'Beusselstrasse 44n', '10553', 'Berlin', 'Berlin', 'DE',
  52.5335, 13.3413, '+49 30 782 55 11', 'info@berliner-tafel.de', 'https://www.berliner-tafel.de',
  'Mo-Fr 07:00-16:00',
  '{"monday":{"open":"07:00","close":"16:00"},"tuesday":{"open":"07:00","close":"16:00"},"wednesday":{"open":"07:00","close":"16:00"},"thursday":{"open":"07:00","close":"16:00"},"friday":{"open":"07:00","close":"16:00"},"saturday":{"closed":true},"sunday":{"closed":true}}'::jsonb,
  ARRAY['essen', 'sachspenden'],
  ARRAY['alle', 'familien', 'senioren', 'obdachlose'],
  ARRAY['Deutsch'],
  ARRAY['Tafel', 'Lebensmittel', 'Spenden'],
  true, true, false,
  '{"wheelchair":true,"public_transport":true}'::jsonb
),
-- 5. Muenchner Tafel
(
  uuid_generate_v4(),
  'muenchner-tafel',
  'Muenchner Tafel e.V.',
  'Lebensmittelverteilung fuer sozial Beduerftige',
  'Die Muenchner Tafel versorgt woechentlich tausende Beduerftige mit Lebensmitteln an ueber 27 Ausgabestellen.',
  'tafel',
  'Am Schwarzen Graben 2', '80634', 'Muenchen', 'Bayern', 'DE',
  48.1557, 11.5358, '+49 89 130050-0', 'info@muenchner-tafel.de', 'https://www.muenchner-tafel.de',
  'Mo-Fr 08:00-15:00',
  '{"monday":{"open":"08:00","close":"15:00"},"tuesday":{"open":"08:00","close":"15:00"},"wednesday":{"open":"08:00","close":"15:00"},"thursday":{"open":"08:00","close":"15:00"},"friday":{"open":"08:00","close":"15:00"},"saturday":{"closed":true},"sunday":{"closed":true}}'::jsonb,
  ARRAY['essen', 'sachspenden'],
  ARRAY['alle', 'familien', 'obdachlose'],
  ARRAY['Deutsch'],
  ARRAY['Tafel', 'Lebensmittel'],
  true, true, false,
  '{"wheelchair":true,"public_transport":true}'::jsonb
),
-- 6. Bahnhofsmission Frankfurt
(
  uuid_generate_v4(),
  'bahnhofsmission-frankfurt',
  'Bahnhofsmission Frankfurt am Main',
  'Sofortige Hilfe fuer Reisende und Menschen in Not',
  'Die Bahnhofsmission bietet kostenlose Soforthilfe: Getraenke, Essen, Gespraech, Reisehilfe und Vermittlung an weitergehende Hilfsangebote.',
  'obdachlosenhilfe',
  'Mannheimer Strasse 6', '60329', 'Frankfurt am Main', 'Hessen', 'DE',
  50.1067, 8.6636, '+49 69 23 77 19', 'frankfurt@bahnhofsmission.de', 'https://www.bahnhofsmission-frankfurt.de',
  'Taeglich 08:00-20:00',
  '{"monday":{"open":"08:00","close":"20:00"},"tuesday":{"open":"08:00","close":"20:00"},"wednesday":{"open":"08:00","close":"20:00"},"thursday":{"open":"08:00","close":"20:00"},"friday":{"open":"08:00","close":"20:00"},"saturday":{"open":"08:00","close":"20:00"},"sunday":{"open":"08:00","close":"20:00"}}'::jsonb,
  ARRAY['essen', 'beratung', 'transport', 'seelsorge'],
  ARRAY['alle', 'obdachlose'],
  ARRAY['Deutsch', 'Englisch'],
  ARRAY['Bahnhofsmission', 'Soforthilfe', 'Reisehilfe'],
  true, true, false,
  '{"wheelchair":true,"public_transport":true,"barrier_free_entrance":true}'::jsonb
),
-- 7. AWO Koeln
(
  uuid_generate_v4(),
  'awo-koeln',
  'AWO Kreisverband Koeln e.V.',
  'Arbeiterwohlfahrt mit breitem Hilfsangebot',
  'Die AWO Koeln bietet Kinderbetreuung, Seniorenhilfe, Beratung, Schuldnerberatung, Migrationshilfe und vieles mehr.',
  'allgemein',
  'Rubensstrasse 7-13', '50676', 'Koeln', 'Nordrhein-Westfalen', 'DE',
  50.9245, 6.9427, '+49 221 204 07-0', 'info@awo-koeln.de', 'https://www.awo-koeln.de',
  'Mo-Do 08:00-17:00, Fr 08:00-14:00',
  '{"monday":{"open":"08:00","close":"17:00"},"tuesday":{"open":"08:00","close":"17:00"},"wednesday":{"open":"08:00","close":"17:00"},"thursday":{"open":"08:00","close":"17:00"},"friday":{"open":"08:00","close":"14:00"},"saturday":{"closed":true},"sunday":{"closed":true}}'::jsonb,
  ARRAY['beratung', 'kinderbetreuung', 'finanziell', 'sprache'],
  ARRAY['alle', 'familien', 'senioren', 'gefluechtete'],
  ARRAY['Deutsch', 'Englisch', 'Tuerkisch'],
  ARRAY['AWO', 'Arbeiterwohlfahrt', 'Kinderbetreuung'],
  true, true, false,
  '{"wheelchair":true,"elevator":true,"public_transport":true}'::jsonb
),
-- 8. Berliner Stadtmission
(
  uuid_generate_v4(),
  'berliner-stadtmission',
  'Berliner Stadtmission',
  'Kaeltebus und Nachtcafe fuer Obdachlose',
  'Die Berliner Stadtmission betreibt Notunterkuenfte, den Kaeltebus, Nachtcafes und bietet umfassende Hilfe fuer obdachlose Menschen.',
  'notschlafstelle',
  'Lehrter Strasse 68', '10557', 'Berlin', 'Berlin', 'DE',
  52.5275, 13.3665, '+49 30 690 33 33', 'info@berliner-stadtmission.de', 'https://www.berliner-stadtmission.de',
  'Notunterkunft: 20:00-08:00, Buero: Mo-Fr 09:00-16:00',
  '{"monday":{"open":"09:00","close":"16:00"},"tuesday":{"open":"09:00","close":"16:00"},"wednesday":{"open":"09:00","close":"16:00"},"thursday":{"open":"09:00","close":"16:00"},"friday":{"open":"09:00","close":"16:00"},"saturday":{"closed":true},"sunday":{"closed":true}}'::jsonb,
  ARRAY['unterkunft', 'essen', 'beratung', 'kleidung', 'medizin'],
  ARRAY['obdachlose'],
  ARRAY['Deutsch', 'Englisch', 'Polnisch'],
  ARRAY['Notunterkunft', 'Kaeltebus', 'Obdachlosenhilfe'],
  true, true, true,
  '{"wheelchair":true,"public_transport":true}'::jsonb
),
-- 9. Tierschutzverein Muenchen
(
  uuid_generate_v4(),
  'tierschutzverein-muenchen',
  'Tierschutzverein Muenchen e.V.',
  'Tierschutz, Tierheim und Tierrettung',
  'Der Tierschutzverein Muenchen betreibt das Tierheim Muenchen-Riem und kuemmert sich um herrenloseund verletzte Tiere.',
  'tierheim',
  'Riemer Strasse 270', '81829', 'Muenchen', 'Bayern', 'DE',
  48.1356, 11.6827, '+49 89 921 000-0', 'info@tierschutzverein-muenchen.de', 'https://www.tierschutzverein-muenchen.de',
  'Di-So 13:00-17:00, Mo geschlossen',
  '{"monday":{"closed":true},"tuesday":{"open":"13:00","close":"17:00"},"wednesday":{"open":"13:00","close":"17:00"},"thursday":{"open":"13:00","close":"17:00"},"friday":{"open":"13:00","close":"17:00"},"saturday":{"open":"13:00","close":"17:00"},"sunday":{"open":"13:00","close":"17:00"}}'::jsonb,
  ARRAY['tierrettung', 'tiervermittlung', 'beratung'],
  ARRAY['tiere'],
  ARRAY['Deutsch'],
  ARRAY['Tierheim', 'Tierschutz', 'Adoption'],
  true, true, false,
  '{"wheelchair":true,"parking":true,"public_transport":true}'::jsonb
),
-- 10. TelefonSeelsorge Berlin
(
  uuid_generate_v4(),
  'telefonseelsorge-berlin',
  'TelefonSeelsorge Berlin',
  'Kostenlose Krisenberatung rund um die Uhr',
  'Die TelefonSeelsorge bietet anonyme, kostenlose Beratung per Telefon, Chat und E-Mail bei Krisen, seelischer Not und Suizidgedanken. 24/7 erreichbar.',
  'krisentelefon',
  NULL, NULL, 'Berlin', 'Berlin', 'DE',
  52.5200, 13.4050, '0800 111 0 111', 'online@telefonseelsorge.de', 'https://www.telefonseelsorge.de',
  '24 Stunden, 7 Tage die Woche',
  '{"monday":{"open":"00:00","close":"23:59"},"tuesday":{"open":"00:00","close":"23:59"},"wednesday":{"open":"00:00","close":"23:59"},"thursday":{"open":"00:00","close":"23:59"},"friday":{"open":"00:00","close":"23:59"},"saturday":{"open":"00:00","close":"23:59"},"sunday":{"open":"00:00","close":"23:59"}}'::jsonb,
  ARRAY['seelsorge', 'psychologisch', 'beratung'],
  ARRAY['alle'],
  ARRAY['Deutsch'],
  ARRAY['Krisentelefon', 'Seelsorge', 'Suizidpraevention', '24/7'],
  true, true, true,
  '{}'::jsonb
),
-- 11. Pro Asyl Frankfurt
(
  uuid_generate_v4(),
  'pro-asyl-frankfurt',
  'PRO ASYL e.V.',
  'Fluechtlingshilfe und Rechtsberatung',
  'PRO ASYL setzt sich fuer die Rechte von Gefluechteten ein und bietet Rechtsberatung, Informationen und politische Arbeit.',
  'fluechtlingshilfe',
  'Postfach 160624', '60069', 'Frankfurt am Main', 'Hessen', 'DE',
  50.1109, 8.6821, '+49 69 24231-0', 'proasyl@proasyl.de', 'https://www.proasyl.de',
  'Mo-Fr 10:00-17:00',
  '{"monday":{"open":"10:00","close":"17:00"},"tuesday":{"open":"10:00","close":"17:00"},"wednesday":{"open":"10:00","close":"17:00"},"thursday":{"open":"10:00","close":"17:00"},"friday":{"open":"10:00","close":"17:00"},"saturday":{"closed":true},"sunday":{"closed":true}}'::jsonb,
  ARRAY['beratung', 'rechtlich'],
  ARRAY['gefluechtete'],
  ARRAY['Deutsch', 'Englisch', 'Franzoesisch', 'Arabisch'],
  ARRAY['Asyl', 'Fluechtlingshilfe', 'Rechtsberatung'],
  true, true, false,
  '{"wheelchair":true,"public_transport":true}'::jsonb
),
-- 12. Hamburger Kleiderkammer
(
  uuid_generate_v4(),
  'hanseatic-help-hamburg',
  'Hanseatic Help e.V.',
  'Kleiderkammer und Sachspenden fuer Beduerftige',
  'Hanseatic Help sammelt, sortiert und verteilt Kleidung und Sachspenden an beduerftige Menschen in Hamburg.',
  'kleiderkammer',
  'Grosse Elbstrasse 264', '22767', 'Hamburg', 'Hamburg', 'DE',
  53.5438, 9.9426, '+49 40 31808930', 'info@hanseatic-help.org', 'https://www.hanseatic-help.org',
  'Mo, Mi, Fr 10:00-16:00',
  '{"monday":{"open":"10:00","close":"16:00"},"tuesday":{"closed":true},"wednesday":{"open":"10:00","close":"16:00"},"thursday":{"closed":true},"friday":{"open":"10:00","close":"16:00"},"saturday":{"closed":true},"sunday":{"closed":true}}'::jsonb,
  ARRAY['kleidung', 'sachspenden'],
  ARRAY['alle', 'gefluechtete', 'obdachlose'],
  ARRAY['Deutsch', 'Englisch'],
  ARRAY['Kleiderkammer', 'Spenden', 'Sachspenden'],
  true, true, false,
  '{"wheelchair":true,"public_transport":true}'::jsonb
),
-- 13. Kinder- und Jugendtelefon
(
  uuid_generate_v4(),
  'nummer-gegen-kummer',
  'Nummer gegen Kummer e.V.',
  'Beratungstelefon fuer Kinder, Jugendliche und Eltern',
  'Kostenloses, anonymes Beratungstelefon fuer Kinder (116 111), Jugendliche und Eltern (0800 111 0 550).',
  'jugend',
  'Hofkamp 108', '42103', 'Wuppertal', 'Nordrhein-Westfalen', 'DE',
  51.2576, 7.1506, '116 111', 'info@nummergegenkummer.de', 'https://www.nummergegenkummer.de',
  'Mo-Sa 14:00-20:00',
  '{"monday":{"open":"14:00","close":"20:00"},"tuesday":{"open":"14:00","close":"20:00"},"wednesday":{"open":"14:00","close":"20:00"},"thursday":{"open":"14:00","close":"20:00"},"friday":{"open":"14:00","close":"20:00"},"saturday":{"open":"14:00","close":"20:00"},"sunday":{"closed":true}}'::jsonb,
  ARRAY['beratung', 'psychologisch', 'seelsorge'],
  ARRAY['kinder', 'jugendliche', 'familien'],
  ARRAY['Deutsch'],
  ARRAY['Kindertelefon', 'Jugendberatung', 'Elterntelefon'],
  true, true, true,
  '{}'::jsonb
),
-- 14. Caritas Wien
(
  uuid_generate_v4(),
  'caritas-wien',
  'Caritas der Erzdiozese Wien',
  'Soziale Hilfsorganisation in Wien',
  'Die Caritas Wien bietet Wohnungslosenhilfe, Sozialberatung, Fluechtlingshilfe und weitere soziale Dienste.',
  'allgemein',
  'Albrechtskreithgasse 19-21', '1160', 'Wien', 'Wien', 'AT',
  48.2123, 16.3293, '+43 1 878 12-0', 'office@caritas-wien.at', 'https://www.caritas-wien.at',
  'Mo-Do 08:00-16:30, Fr 08:00-14:00',
  '{"monday":{"open":"08:00","close":"16:30"},"tuesday":{"open":"08:00","close":"16:30"},"wednesday":{"open":"08:00","close":"16:30"},"thursday":{"open":"08:00","close":"16:30"},"friday":{"open":"08:00","close":"14:00"},"saturday":{"closed":true},"sunday":{"closed":true}}'::jsonb,
  ARRAY['beratung', 'unterkunft', 'essen', 'finanziell', 'arbeit'],
  ARRAY['alle', 'obdachlose', 'gefluechtete', 'familien'],
  ARRAY['Deutsch', 'Englisch', 'Arabisch'],
  ARRAY['Caritas', 'Wien', 'Sozialberatung'],
  true, true, false,
  '{"wheelchair":true,"elevator":true,"public_transport":true}'::jsonb
),
-- 15. Schweizerisches Rotes Kreuz Zuerich
(
  uuid_generate_v4(),
  'srk-zuerich',
  'Schweizerisches Rotes Kreuz Kanton Zuerich',
  'Rotkreuz-Hilfe im Kanton Zuerich',
  'Das SRK Kanton Zuerich bietet Rotkreuz-Notruf, Entlastungsdienst, Kinderbetreuung, Fahrdienst und Integrationskurse.',
  'allgemein',
  'Kronenstrasse 10', '8006', 'Zuerich', 'Zuerich', 'CH',
  47.3819, 8.5398, '+41 44 360 28 28', 'info@srk-zuerich.ch', 'https://www.srk-zuerich.ch',
  'Mo-Fr 08:30-12:00, 13:30-17:00',
  '{"monday":{"open":"08:30","close":"17:00"},"tuesday":{"open":"08:30","close":"17:00"},"wednesday":{"open":"08:30","close":"17:00"},"thursday":{"open":"08:30","close":"17:00"},"friday":{"open":"08:30","close":"17:00"},"saturday":{"closed":true},"sunday":{"closed":true}}'::jsonb,
  ARRAY['beratung', 'transport', 'kinderbetreuung', 'sprache', 'notfallhilfe'],
  ARRAY['alle', 'senioren', 'familien', 'gefluechtete'],
  ARRAY['Deutsch', 'Englisch', 'Franzoesisch'],
  ARRAY['Rotes Kreuz', 'SRK', 'Fahrdienst'],
  true, true, false,
  '{"wheelchair":true,"elevator":true,"public_transport":true,"parking":true}'::jsonb
),
-- 16. Suppenkueche Franziskanerkloster Berlin
(
  uuid_generate_v4(),
  'suppenkueche-franziskaner-berlin',
  'Franziskaner-Suppenkueche Berlin',
  'Taeglich warme Mahlzeiten fuer Beduerftige',
  'Die Franziskaner-Suppenkueche am Mehringdamm bietet taeglich kostenlose warme Mahlzeiten fuer alle Beduerftige an.',
  'suppenkueche',
  'Wollankstrasse 19', '13187', 'Berlin', 'Berlin', 'DE',
  52.5607, 13.4042, '+49 30 490 15 27', NULL, NULL,
  'Mo-Fr 11:30-14:00',
  '{"monday":{"open":"11:30","close":"14:00"},"tuesday":{"open":"11:30","close":"14:00"},"wednesday":{"open":"11:30","close":"14:00"},"thursday":{"open":"11:30","close":"14:00"},"friday":{"open":"11:30","close":"14:00"},"saturday":{"closed":true},"sunday":{"closed":true}}'::jsonb,
  ARRAY['essen'],
  ARRAY['alle', 'obdachlose'],
  ARRAY['Deutsch'],
  ARRAY['Suppenkueche', 'Mahlzeiten', 'Franziskaner'],
  true, true, false,
  '{"wheelchair":true,"public_transport":true}'::jsonb
),
-- 17. Sozialkaufhaus Stuttgart
(
  uuid_generate_v4(),
  'sozialkaufhaus-stuttgart',
  'Sozialkaufhaus Stuttgart-Ost',
  'Guenstige Waren fuer Menschen mit kleinem Geldbeutel',
  'Das Sozialkaufhaus bietet gebrauchte Moebel, Kleidung, Haushaltsgeraete und mehr zu stark reduzierten Preisen.',
  'sozialkaufhaus',
  'Wagenburgstrasse 145', '70186', 'Stuttgart', 'Baden-Wuerttemberg', 'DE',
  48.7795, 9.2067, '+49 711 24869-0', 'info@sozialkaufhaus-stuttgart.de', NULL,
  'Mo-Fr 10:00-18:00, Sa 10:00-14:00',
  '{"monday":{"open":"10:00","close":"18:00"},"tuesday":{"open":"10:00","close":"18:00"},"wednesday":{"open":"10:00","close":"18:00"},"thursday":{"open":"10:00","close":"18:00"},"friday":{"open":"10:00","close":"18:00"},"saturday":{"open":"10:00","close":"14:00"},"sunday":{"closed":true}}'::jsonb,
  ARRAY['kleidung', 'sachspenden'],
  ARRAY['alle'],
  ARRAY['Deutsch'],
  ARRAY['Sozialkaufhaus', 'Moebel', 'Secondhand'],
  true, true, false,
  '{"wheelchair":true,"parking":true,"public_transport":true}'::jsonb
),
-- 18. Wiener Tafel
(
  uuid_generate_v4(),
  'wiener-tafel',
  'Wiener Tafel',
  'Lebensmittelrettung und -verteilung in Wien',
  'Die Wiener Tafel rettet genusstaugliche Lebensmittel und verteilt sie an soziale Einrichtungen in Wien.',
  'tafel',
  'Simmeringer Hauptstrasse 2a', '1110', 'Wien', 'Wien', 'AT',
  48.1852, 16.4048, '+43 1 236 56 87', 'info@wienertafel.at', 'https://www.wienertafel.at',
  'Mo-Fr 08:00-16:00',
  '{"monday":{"open":"08:00","close":"16:00"},"tuesday":{"open":"08:00","close":"16:00"},"wednesday":{"open":"08:00","close":"16:00"},"thursday":{"open":"08:00","close":"16:00"},"friday":{"open":"08:00","close":"16:00"},"saturday":{"closed":true},"sunday":{"closed":true}}'::jsonb,
  ARRAY['essen', 'sachspenden'],
  ARRAY['alle'],
  ARRAY['Deutsch'],
  ARRAY['Tafel', 'Wien', 'Lebensmittelrettung'],
  true, true, false,
  '{"wheelchair":true,"public_transport":true}'::jsonb
)
ON CONFLICT DO NOTHING;

-- Clean up helper function
DROP FUNCTION IF EXISTS public.generate_org_slug(TEXT, TEXT);
