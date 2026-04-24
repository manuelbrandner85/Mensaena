CREATE OR REPLACE FUNCTION get_user_stats(p_user_id UUID)
RETURNS JSON LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE v_result JSON;
BEGIN
  SELECT json_build_object(
    'posts_created',           (SELECT COUNT(*) FROM posts        WHERE user_id  = p_user_id AND status = 'active'),
    'interactions_completed',  (SELECT COUNT(*) FROM interactions WHERE helper_id = p_user_id AND status = 'completed'),
    'people_helped',           (SELECT COUNT(DISTINCT post_id) FROM interactions WHERE helper_id = p_user_id AND status = 'completed'),
    'saved_posts_count',       (SELECT COUNT(*) FROM saved_posts  WHERE user_id  = p_user_id)
  ) INTO v_result;
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION get_platform_stats()
RETURNS JSON LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE v_result JSON;
BEGIN
  SELECT json_build_object(
    'users',        (SELECT COUNT(*) FROM profiles),
    'posts',        (SELECT COUNT(*) FROM posts        WHERE status = 'active'),
    'interactions', (SELECT COUNT(*) FROM interactions WHERE status = 'completed'),
    'regions',      (SELECT COUNT(*) FROM regions)
  ) INTO v_result;
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION get_community_pulse()
RETURNS JSON LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE v_result JSON;
BEGIN
  SELECT json_build_object(
    'active_users_today',       (SELECT COUNT(DISTINCT user_id) FROM posts WHERE created_at >= CURRENT_DATE),
    'new_posts_today',          (SELECT COUNT(*) FROM posts WHERE created_at >= CURRENT_DATE AND status = 'active'),
    'interactions_this_week',   (SELECT COUNT(*) FROM interactions WHERE created_at >= CURRENT_DATE - INTERVAL '7 days' AND status = 'completed'),
    'newest_neighbor_name',     (SELECT COALESCE(name, nickname, 'Nachbar:in') FROM profiles ORDER BY created_at DESC LIMIT 1),
    'newest_neighbor_joined_at',(SELECT created_at FROM profiles ORDER BY created_at DESC LIMIT 1)
  ) INTO v_result;
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION get_nearby_posts(
  p_lat       FLOAT,
  p_lng       FLOAT,
  p_radius_km FLOAT DEFAULT 10,
  p_limit     INT   DEFAULT 10
)
RETURNS JSON LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE v_result JSON;
BEGIN
  SELECT json_agg(sub) INTO v_result FROM (
    SELECT
      p.id, p.title, p.description, p.type, p.category, p.status, p.urgency,
      p.latitude, p.longitude, p.location, p.created_at,
      pr.name        AS author_name,
      pr.avatar_url  AS author_avatar,
      ROUND((6371 * acos(
        cos(radians(p_lat)) * cos(radians(p.latitude)) *
        cos(radians(p.longitude) - radians(p_lng)) +
        sin(radians(p_lat)) * sin(radians(p.latitude))
      ))::numeric, 1) AS distance_km
    FROM posts p
    JOIN profiles pr ON p.user_id = pr.id
    WHERE p.status = 'active'
      AND p.latitude  IS NOT NULL
      AND p.longitude IS NOT NULL
      -- Bounding-box pre-filter (avoids full table scan before Haversine)
      AND p.latitude  BETWEEN p_lat - (p_radius_km / 111.0)
                          AND p_lat + (p_radius_km / 111.0)
      AND p.longitude BETWEEN p_lng - (p_radius_km / (111.0 * cos(radians(p_lat))))
                          AND p_lng + (p_radius_km / (111.0 * cos(radians(p_lat))))
    ORDER BY distance_km ASC
    LIMIT p_limit
  ) sub;
  RETURN COALESCE(v_result, '[]'::json);
END;
$$;
