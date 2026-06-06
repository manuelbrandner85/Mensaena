-- ============================================================
-- DSGVO-Datensparsamkeit: search_posts gibt nur noch GROBE Koordinaten
-- (~1,1 km, 2 Nachkommastellen) zurück — analog zu get_nearby_posts. Die
-- Distanzberechnung nutzt weiterhin die EXAKTEN Werte (haversine_km mit
-- p.latitude/p.longitude); nur die zurückgegebenen Output-Koordinaten werden
-- gerundet, damit aus Suchergebnissen nicht die genaue Wohnadresse ablesbar ist.
--
-- 1:1-Reproduktion der bestehenden Funktion (9 Params, RETURNS TABLE mit
-- fts/ts_rank), einzige inhaltliche Änderung: die Ausgabe-Koordinaten sind
-- gerundet. Signatur bleibt identisch → CREATE OR REPLACE ist sicher.
-- ============================================================
CREATE OR REPLACE FUNCTION public.search_posts(
  p_query     text,
  p_category  text DEFAULT NULL,
  p_type      text DEFAULT NULL,
  p_urgency   text DEFAULT NULL,
  p_lat       double precision DEFAULT NULL,
  p_lng       double precision DEFAULT NULL,
  p_radius_km double precision DEFAULT 50,
  p_limit     integer DEFAULT 20,
  p_offset    integer DEFAULT 0
)
RETURNS TABLE(
  id uuid,
  user_id uuid,
  type text,
  category text,
  title text,
  description text,
  image_urls text[],
  latitude double precision,
  longitude double precision,
  urgency text,
  status text,
  created_at timestamp with time zone,
  author_name text,
  author_avatar text,
  distance_km double precision,
  rank real
)
LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
    SELECT
      p.id, p.user_id, p.type, p.category, p.title,
      p.description, p.image_urls,
      ROUND(p.latitude::numeric, 2)::double precision  AS latitude,
      ROUND(p.longitude::numeric, 2)::double precision AS longitude,
      p.urgency, p.status, p.created_at,
      pr.name, pr.avatar_url,
      CASE
        WHEN p_lat IS NOT NULL AND p_lng IS NOT NULL AND p.latitude IS NOT NULL
          THEN haversine_km(p_lat, p_lng, p.latitude, p.longitude)
        ELSE NULL
      END AS distance_km,
      CASE
        WHEN p_query IS NOT NULL AND p_query != ''
          THEN ts_rank(p.fts, plainto_tsquery('german', p_query))
        ELSE 1.0::real
      END AS rank
    FROM public.posts p
    LEFT JOIN public.profiles pr ON pr.id = p.user_id
    WHERE p.status = 'active'
      AND (p_query IS NULL OR p_query = '' OR p.fts @@ plainto_tsquery('german', p_query))
      AND (p_category IS NULL OR p.category = p_category)
      AND (p_type IS NULL OR p.type = p_type)
      AND (p_urgency IS NULL OR p.urgency = p_urgency)
      AND (p_lat IS NULL OR p_lng IS NULL OR p.latitude IS NULL
           OR haversine_km(p_lat, p_lng, p.latitude, p.longitude) <= p_radius_km)
    ORDER BY
      CASE p.urgency
        WHEN 'critical' THEN 0
        WHEN 'high'     THEN 1
        WHEN 'medium'   THEN 2
        ELSE 3
      END,
      rank DESC,
      p.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;
