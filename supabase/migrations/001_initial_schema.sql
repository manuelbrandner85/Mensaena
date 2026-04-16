
-- ============================================================
-- UPDATED_AT TRIGGER FUNCTION
-- (Idempotent: auch in 001_schema.sql definiert, hier aber nötig
--  weil 001_initial_schema.sql alphabetisch davor läuft und die
--  Funktion für den farm_listings-Trigger bereits existieren muss.)
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TABLE: farm_listings
-- Bauernhöfe, Hofläden, Direktvermarkter
-- Version: 2.0.0 - Regionale Versorgung Modul
-- ============================================================
CREATE TABLE IF NOT EXISTS public.farm_listings (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name              TEXT NOT NULL,
  slug              TEXT UNIQUE NOT NULL,
  category          TEXT NOT NULL DEFAULT 'Bauernhof' CHECK (category IN (
    'Bauernhof','Hofladen','Direktvermarktung','Wochenmarkt',
    'Solidarische Landwirtschaft','Biohof','Selbsternte','Lieferdienst'
  )),
  subcategories     TEXT[] DEFAULT '{}',
  description       TEXT,
  address           TEXT,
  postal_code       TEXT,
  city              TEXT NOT NULL,
  region            TEXT,
  state             TEXT,
  country           TEXT NOT NULL DEFAULT 'AT',
  latitude          DOUBLE PRECISION,
  longitude         DOUBLE PRECISION,
  phone             TEXT,
  email             TEXT,
  website           TEXT,
  opening_hours     JSONB DEFAULT '{}',
  products          TEXT[] DEFAULT '{}',
  services          TEXT[] DEFAULT '{}',
  delivery_options  TEXT[] DEFAULT '{}',
  image_url         TEXT,
  source_url        TEXT,
  source_name       TEXT,
  imported_at       TIMESTAMPTZ DEFAULT NOW(),
  last_verified_at  TIMESTAMPTZ,
  is_public         BOOLEAN DEFAULT TRUE,
  is_verified       BOOLEAN DEFAULT FALSE,
  is_bio            BOOLEAN DEFAULT FALSE,
  is_seasonal       BOOLEAN DEFAULT FALSE,
  created_at        TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at        TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TRIGGER handle_farm_listings_updated_at
  BEFORE UPDATE ON public.farm_listings
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_farms_city       ON public.farm_listings(city);
CREATE INDEX IF NOT EXISTS idx_farms_state      ON public.farm_listings(state);
CREATE INDEX IF NOT EXISTS idx_farms_category   ON public.farm_listings(category);
CREATE INDEX IF NOT EXISTS idx_farms_coords     ON public.farm_listings(latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_farms_is_public  ON public.farm_listings(is_public);
CREATE INDEX IF NOT EXISTS idx_farms_country    ON public.farm_listings(country);

-- RLS
ALTER TABLE public.farm_listings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Farm listings sind öffentlich lesbar"
  ON public.farm_listings FOR SELECT USING (is_public = TRUE);
CREATE POLICY "Admins können alles"
  ON public.farm_listings FOR ALL USING (auth.role() = 'service_role');
