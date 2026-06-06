-- ============================================================
-- DSGVO-Datensparsamkeit: search_posts gibt nur noch GROBE Koordinaten
-- (~1,1 km, 2 Nachkommastellen) aus — analog zu get_nearby_posts. Die
-- Distanzberechnung und der Radius-Filter nutzen weiterhin die EXAKTEN
-- Werte (COALESCE(p.latitude, p.lat)); nur die zurückgegebenen Koordinaten
-- werden gerundet, damit aus Suchergebnissen nicht die genaue Wohnadresse
-- ablesbar ist.
--
-- 1:1-Reproduktion der bestehenden Funktion (20260411000000), einzige
-- Änderung: die vier Koordinaten-Ausgabespalten sind gerundet.
-- ============================================================
CREATE OR REPLACE FUNCTION public.search_posts(
  p_query      TEXT     DEFAULT NULL,
  p_type       TEXT     DEFAULT NULL,
  p_category   TEXT     DEFAULT NULL,
  p_lat        DOUBLE PRECISION DEFAULT NULL,
  p_lng        DOUBLE PRECISION DEFAULT NULL,
  p_radius_km  INT     DEFAULT 50,
  p_limit      INT     DEFAULT 20,
  p_offset     INT     DEFAULT 0
)
RETURNS SETOF JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT
      p.id, p.title, p.description, p.type, p.category, p.status, p.urgency,
      p.user_id, p.location_text,
      ROUND(p.latitude::numeric, 2)::double precision  AS latitude,
      ROUND(p.longitude::numeric, 2)::double precision AS longitude,
      ROUND(p.lat::numeric, 2)::double precision       AS lat,
      ROUND(p.lng::numeric, 2)::double precision       AS lng,
      p.media_urls, p.tags, p.is_anonymous, p.contact_phone, p.contact_email,
      p.contact_whatsapp, p.privacy_phone, p.privacy_email,
      p.availability_days, p.availability_start, p.availability_end,
      p.created_at, p.updated_at,
      pr.name AS author_name, pr.avatar_url AS author_avatar,
      CASE
        WHEN p_lat IS NOT NULL AND p_lng IS NOT NULL
             AND COALESCE(p.latitude, p.lat) IS NOT NULL
             AND COALESCE(p.longitude, p.lng) IS NOT NULL
        THEN round((
          6371 * acos(
            LEAST(1.0, GREATEST(-1.0,
              cos(radians(p_lat)) * cos(radians(COALESCE(p.latitude, p.lat)))
              * cos(radians(COALESCE(p.longitude, p.lng)) - radians(p_lng))
              + sin(radians(p_lat)) * sin(radians(COALESCE(p.latitude, p.lat)))
            ))
          )
        )::numeric, 1)
        ELSE NULL
      END AS distance_km
    FROM public.posts p
    LEFT JOIN public.profiles pr ON pr.id = p.user_id
    WHERE p.status = 'active'
      AND (p_type IS NULL OR p.type = p_type)
      AND (p_category IS NULL OR p.category = p_category)
      AND (p_query IS NULL OR p_query = ''
           OR p.title ILIKE '%' || p_query || '%'
           OR p.description ILIKE '%' || p_query || '%'
           OR p.location_text ILIKE '%' || p_query || '%'
           OR p_query = ANY(p.tags))
      AND (p_lat IS NULL OR p_lng IS NULL
           OR COALESCE(p.latitude, p.lat) IS NULL
           OR COALESCE(p.longitude, p.lng) IS NULL
           OR (
             6371 * acos(
               LEAST(1.0, GREATEST(-1.0,
                 cos(radians(p_lat)) * cos(radians(COALESCE(p.latitude, p.lat)))
                 * cos(radians(COALESCE(p.longitude, p.lng)) - radians(p_lng))
                 + sin(radians(p_lat)) * sin(radians(COALESCE(p.latitude, p.lat)))
               ))
             ) <= p_radius_km
           ))
    ORDER BY
      CASE WHEN p.urgency IN ('critical','high') THEN 0 ELSE 1 END,
      p.created_at DESC
    LIMIT p_limit OFFSET p_offset
  LOOP
    RETURN NEXT to_jsonb(rec);
  END LOOP;
END;
$$;
