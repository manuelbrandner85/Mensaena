-- ============================================================
-- Dashboard RPC Functions
-- ============================================================

-- get_nearby_posts: Returns posts within a radius of given coordinates
CREATE OR REPLACE FUNCTION get_nearby_posts(
  p_lat double precision,
  p_lng double precision,
  p_radius_km integer DEFAULT 10,
  p_limit integer DEFAULT 10
)
RETURNS SETOF json
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT row_to_json(t) FROM (
    SELECT
      p.id,
      p.title,
      p.description,
      p.type,
      p.category,
      p.status,
      p.urgency,
      p.latitude,
      p.longitude,
      p.location_text,
      p.created_at,
      p.user_id,
      pr.name AS author_name,
      pr.avatar_url AS author_avatar,
      ROUND(
        (6371 * acos(
          LEAST(1.0, GREATEST(-1.0,
            cos(radians(p_lat)) * cos(radians(p.latitude)) *
            cos(radians(p.longitude) - radians(p_lng)) +
            sin(radians(p_lat)) * sin(radians(p.latitude))
          ))
        ))::numeric, 1
      ) AS distance_km
    FROM posts p
    LEFT JOIN profiles pr ON pr.id = p.user_id
    WHERE p.status = 'active'
      AND p.latitude IS NOT NULL
      AND p.longitude IS NOT NULL
      AND (
        6371 * acos(
          LEAST(1.0, GREATEST(-1.0,
            cos(radians(p_lat)) * cos(radians(p.latitude)) *
            cos(radians(p.longitude) - radians(p_lng)) +
            sin(radians(p_lat)) * sin(radians(p.latitude))
          ))
        )
      ) <= p_radius_km
    ORDER BY p.created_at DESC
    LIMIT p_limit
  ) t;
$$;

-- get_community_pulse: Returns community activity statistics
CREATE OR REPLACE FUNCTION get_community_pulse()
RETURNS json
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT json_build_object(
    'active_users_today', (
      SELECT COUNT(DISTINCT id) FROM profiles
      WHERE updated_at >= CURRENT_DATE
    ),
    'new_posts_today', (
      SELECT COUNT(*) FROM posts
      WHERE created_at >= CURRENT_DATE AND status = 'active'
    ),
    'interactions_this_week', (
      SELECT COUNT(*) FROM interactions
      WHERE created_at >= NOW() - INTERVAL '7 days'
        AND status = 'completed'
    ),
    'newest_neighbor_name', (
      SELECT name FROM profiles
      WHERE id != '00000000-0000-0000-0000-000000000001'
      ORDER BY created_at DESC LIMIT 1
    ),
    'newest_neighbor_joined_at', (
      SELECT created_at FROM profiles
      WHERE id != '00000000-0000-0000-0000-000000000001'
      ORDER BY created_at DESC LIMIT 1
    )
  );
$$;
