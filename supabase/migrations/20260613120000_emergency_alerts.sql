-- emergency_alerts: SOS-Notfallmeldungen mit Geo-Filter (PostGIS)
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS public.emergency_alerts (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  alert_type      text NOT NULL CHECK (alert_type IN ('medical','fire','accident','other')),
  latitude        float8 NOT NULL,
  longitude       float8 NOT NULL,
  location_point  geometry(Point, 4326) GENERATED ALWAYS AS (
                    ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
                  ) STORED,
  description     text,
  status          text NOT NULL DEFAULT 'active',
  respondents     uuid[] NOT NULL DEFAULT '{}',
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS emergency_alerts_location_idx
  ON public.emergency_alerts USING GIST (location_point);

CREATE INDEX IF NOT EXISTS emergency_alerts_user_id_idx
  ON public.emergency_alerts (user_id);

CREATE INDEX IF NOT EXISTS emergency_alerts_status_idx
  ON public.emergency_alerts (status);

ALTER TABLE public.emergency_alerts ENABLE ROW LEVEL SECURITY;

-- Jeder eingeloggte User darf eigene Alerts anlegen
CREATE POLICY "alert_insert" ON public.emergency_alerts
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- SELECT nur wenn eigener Alert ODER innerhalb 500 m des Alert-Punkts
-- (User-Koordinaten aus dem Request kommen via RPC-Helper)
CREATE POLICY "alert_select_nearby" ON public.emergency_alerts
  FOR SELECT TO authenticated
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.latitude IS NOT NULL
        AND p.longitude IS NOT NULL
        AND ST_DWithin(
          location_point::geography,
          ST_SetSRID(ST_MakePoint(p.longitude, p.latitude), 4326)::geography,
          500
        )
    )
  );

-- Update: nur Creator darf Status/Respondents ändern
CREATE POLICY "alert_update_own" ON public.emergency_alerts
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Responder darf sich selbst eintragen (array_append, RLS erlaubt beide Parteien)
CREATE POLICY "alert_respond" ON public.emergency_alerts
  FOR UPDATE TO authenticated
  USING (
    auth.uid() = user_id
    OR status = 'active'
  )
  WITH CHECK (
    auth.uid() = user_id
    OR auth.uid() = ANY(respondents)
  );

-- RPC: User-IDs im Umkreis x Meter (für emergency-notify Edge Function).
-- Nutzt profiles.latitude/longitude (float8).
CREATE OR REPLACE FUNCTION public.users_within_meters(
  lat float8,
  lng float8,
  meters float8 DEFAULT 500
)
RETURNS TABLE (user_id uuid)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT p.id AS user_id
  FROM public.profiles p
  WHERE p.latitude IS NOT NULL
    AND p.longitude IS NOT NULL
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(p.longitude, p.latitude), 4326)::geography,
      ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography,
      meters
    );
$$;
