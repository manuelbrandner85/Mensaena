-- carpool_routes: Fahrgemeinschafts-Routen mit PostGIS-Punkten
CREATE EXTENSION IF NOT EXISTS postgis;

DO $$ BEGIN
  CREATE TYPE day_of_week_enum AS ENUM (
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS carpool_routes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  start_lat     DOUBLE PRECISION NOT NULL,
  start_lng     DOUBLE PRECISION NOT NULL,
  end_lat       DOUBLE PRECISION NOT NULL,
  end_lng       DOUBLE PRECISION NOT NULL,
  -- PostGIS geography columns (auto-computed from lat/lng)
  start_point   GEOGRAPHY(POINT, 4326)
                  GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(start_lng, start_lat), 4326)::geography) STORED,
  end_point     GEOGRAPHY(POINT, 4326)
                  GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(end_lng, end_lat), 4326)::geography) STORED,
  day_of_week   day_of_week_enum NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Spatial index für Nähe-Suchen
CREATE INDEX IF NOT EXISTS carpool_routes_start_point_idx
  ON carpool_routes USING GIST (start_point);
CREATE INDEX IF NOT EXISTS carpool_routes_end_point_idx
  ON carpool_routes USING GIST (end_point);
CREATE INDEX IF NOT EXISTS carpool_routes_user_id_idx
  ON carpool_routes (user_id);

-- RLS
ALTER TABLE carpool_routes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "carpool_routes_select_own"
  ON carpool_routes FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "carpool_routes_insert_own"
  ON carpool_routes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "carpool_routes_update_own"
  ON carpool_routes FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "carpool_routes_delete_own"
  ON carpool_routes FOR DELETE
  USING (auth.uid() = user_id);

-- updated_at trigger (nutzt bestehende public.set_updated_at Funktion)
CREATE TRIGGER carpool_routes_updated_at
  BEFORE UPDATE ON carpool_routes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
