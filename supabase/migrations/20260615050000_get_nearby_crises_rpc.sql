-- RPC: get_nearby_crises
-- Gibt aktive Krisen innerhalb eines Radius zurück, sortiert nach Entfernung.
-- Analogon zu get_nearby_posts (20260422020000_performance_rpcs.sql).
CREATE OR REPLACE FUNCTION get_nearby_crises(
  p_lat       FLOAT,
  p_lng       FLOAT,
  p_radius_km FLOAT DEFAULT 150,
  p_limit     INT   DEFAULT 200
)
RETURNS JSON LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE v_result JSON;
BEGIN
  SELECT json_agg(sub) INTO v_result FROM (
    SELECT
      c.id,
      c.title,
      c.description,
      c.category,
      c.urgency,
      c.status,
      c.latitude,
      c.longitude,
      c.location_text,
      c.radius_km,
      c.affected_count,
      c.helper_count,
      c.needed_helpers,
      c.needed_skills,
      c.needed_resources,
      c.is_anonymous,
      c.is_verified,
      c.image_urls,
      c.created_at,
      ROUND((6371 * acos(
        cos(radians(p_lat)) * cos(radians(c.latitude)) *
        cos(radians(c.longitude) - radians(p_lng)) +
        sin(radians(p_lat)) * sin(radians(c.latitude))
      ))::numeric, 1) AS distance_km
    FROM crises c
    WHERE c.status != 'resolved'
      AND c.resolved_at IS NULL
      AND c.latitude  IS NOT NULL
      AND c.longitude IS NOT NULL
      -- Bounding-box pre-filter (avoids full table scan before Haversine)
      AND c.latitude  BETWEEN p_lat - (p_radius_km / 111.0)
                          AND p_lat + (p_radius_km / 111.0)
      AND c.longitude BETWEEN p_lng - (p_radius_km / (111.0 * cos(radians(p_lat))))
                          AND p_lng + (p_radius_km / (111.0 * cos(radians(p_lat))))
    ORDER BY distance_km ASC
    LIMIT p_limit
  ) sub;
  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

-- Index auf (latitude, longitude) für die Bounding-Box-Abfrage falls noch nicht vorhanden.
CREATE INDEX IF NOT EXISTS idx_crises_geo ON crises (latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
