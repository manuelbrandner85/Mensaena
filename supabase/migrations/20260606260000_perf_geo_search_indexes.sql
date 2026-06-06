-- ============================================================
-- Performance-Audit Fixes (Ziel 1000+ Nutzer)
-- Rein additiv & idempotent: CREATE ... IF NOT EXISTS, ADD COLUMN IF NOT
-- EXISTS, CREATE OR REPLACE FUNCTION. Spaltenabhängige Indizes sind via
-- information_schema-Guards gegen fehlende Spalten abgesichert.
--
--  P2  Geo/Karte    → PostGIS geography-Spalte + GiST-Index, get_nearby_posts
--                     via ST_DWithin (vorher O(n)-Haversine ohne Index)
--  P3  Suche        → pg_trgm GIN-Indizes beschleunigen die ILIKE-'%…%'-
--                     Filter in search_posts (vorher nicht index-fähig)
--  P4  Dashboard    → profiles(updated_at/created_at)-Indizes für
--                     get_community_pulse + get_admin_dashboard_stats
-- ============================================================

-- ─────────────────────────────────────────────────────────────────────────
-- P2: Räumlicher Index für posts (Karte / Nearby)
-- ─────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS postgis;

-- Generierte geography-Spalte (immutable Ausdruck → STORED erlaubt). Wird aus
-- latitude/longitude automatisch gepflegt, kein App-Code nötig.
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS geog geography(Point, 4326)
  GENERATED ALWAYS AS (
    CASE
      WHEN latitude IS NOT NULL AND longitude IS NOT NULL
      THEN ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
      ELSE NULL
    END
  ) STORED;

-- GiST-Index nur über aktive Posts mit Geo (deckt sowohl ST_DWithin-Filter
-- als auch KNN-Sortierung `<->` ab).
CREATE INDEX IF NOT EXISTS idx_posts_geog
  ON public.posts USING gist (geog)
  WHERE status = 'active';

-- get_nearby_posts: index-gestützt via ST_DWithin + KNN-Nearest-First.
-- Die alte Funktion (20260405000000) gab `SETOF posts` zurück — wir wollen
-- `SETOF json` mit kontrolliertem Output. Postgres erlaubt keinen Return-Type-
-- Wechsel via CREATE OR REPLACE (42P13), darum vorher ALLE Overloads droppen.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT oid::regprocedure AS sig
      FROM pg_proc
     WHERE proname = 'get_nearby_posts'
       AND pronamespace = 'public'::regnamespace
  LOOP
    EXECUTE 'DROP FUNCTION ' || r.sig || ' CASCADE';
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION get_nearby_posts(
  p_lat double precision,
  p_lng double precision,
  p_radius_km integer DEFAULT 10,
  p_limit integer DEFAULT 10
)
RETURNS SETOF json
LANGUAGE sql
STABLE
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
      pr.name       AS author_name,
      pr.avatar_url AS author_avatar,
      ROUND(
        (ST_Distance(
           p.geog,
           ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
         ) / 1000.0)::numeric, 1
      ) AS distance_km
    FROM posts p
    LEFT JOIN profiles pr ON pr.id = p.user_id
    WHERE p.status = 'active'
      AND p.geog IS NOT NULL
      AND ST_DWithin(
            p.geog,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
            p_radius_km * 1000.0
          )
    ORDER BY p.geog <-> ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
    LIMIT p_limit
  ) t;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- P3: Volltext-Suche — Trigram-GIN beschleunigt die bestehenden ILIKE-Filter
--     in search_posts (title/description/location_text). Kein RPC-Rewrite
--     nötig: der Planner nutzt die GIN-Indizes automatisch für '%…%'.
-- ─────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_posts_title_trgm
  ON public.posts USING gin (title gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_posts_description_trgm
  ON public.posts USING gin (description gin_trgm_ops);

-- location_text existiert (wird in search_posts/get_nearby_posts referenziert),
-- zur Sicherheit dennoch geguardet.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'posts'
      AND column_name = 'location_text'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_posts_location_text_trgm
      ON public.posts USING gin (location_text gin_trgm_ops);
  END IF;
END $$;

-- tags-Array-Suche (p_query = ANY(p.tags)) → GIN, falls Spalte existiert.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'posts'
      AND column_name = 'tags'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_posts_tags_gin
      ON public.posts USING gin (tags);
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────
-- P4: profiles-Indizes für Dashboard-/Pulse-Zeitfenster-Zählungen
-- ─────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_profiles_updated_at
  ON public.profiles(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_profiles_created_at
  ON public.profiles(created_at DESC);

-- last_seen_at wird im Admin-Fallback für active_users_30d genutzt.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles'
      AND column_name = 'last_seen_at'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_profiles_last_seen_at
      ON public.profiles(last_seen_at DESC);
  END IF;
END $$;

-- get_community_pulse: COUNT(DISTINCT id) → COUNT(*) (id ist PK, identisch),
-- nutzt jetzt idx_profiles_updated_at statt Full-Scan + Distinct.
CREATE OR REPLACE FUNCTION get_community_pulse()
RETURNS json
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT json_build_object(
    'active_users_today', (
      SELECT COUNT(*) FROM profiles
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
