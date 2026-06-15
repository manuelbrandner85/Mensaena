-- ============================================================================
-- Safety-Reports (Nachbarschafts-Sicherheitsmeldungen)
-- Tabellen: safety_reports + safety_report_upvotes
-- RPC: get_nearby_safety_reports (Geo-Filter + Auto-Hide + Anonymisierung)
-- ============================================================================

-- ── 1. Haupttabelle ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.safety_reports (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title            TEXT NOT NULL,
  description      TEXT,
  incident_type    TEXT NOT NULL DEFAULT 'other'
                     CHECK (incident_type IN (
                       'einbruch','diebstahl','vandalismus','verdaechtig',
                       'unfall','fundgegenstand','other')),
  anonymous        BOOLEAN NOT NULL DEFAULT false,
  location_address TEXT,
  location_lat     DOUBLE PRECISION,
  location_lng     DOUBLE PRECISION,
  happened_at      TIMESTAMPTZ,
  image_urls       TEXT[] NOT NULL DEFAULT '{}',
  status           TEXT NOT NULL DEFAULT 'active'
                     CHECK (status IN ('active','resolved','removed')),
  upvote_count     INTEGER NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_safety_reports_status  ON public.safety_reports(status);
CREATE INDEX IF NOT EXISTS idx_safety_reports_created ON public.safety_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_safety_reports_geo
  ON public.safety_reports(location_lat, location_lng)
  WHERE location_lat IS NOT NULL AND location_lng IS NOT NULL;

-- ── 2. Upvotes (eine Stimme pro User & Meldung) ─────────────────────────────
CREATE TABLE IF NOT EXISTS public.safety_report_upvotes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id   UUID NOT NULL REFERENCES public.safety_reports(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (report_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_safety_report_upvotes_report ON public.safety_report_upvotes(report_id);

-- ── 3. upvote_count konsistent halten (Trigger) ─────────────────────────────
CREATE OR REPLACE FUNCTION public.safety_report_sync_upvotes()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE public.safety_reports
       SET upvote_count = upvote_count + 1
     WHERE id = NEW.report_id;
    RETURN NEW;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE public.safety_reports
       SET upvote_count = GREATEST(0, upvote_count - 1)
     WHERE id = OLD.report_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_safety_report_upvotes ON public.safety_report_upvotes;
CREATE TRIGGER trg_safety_report_upvotes
  AFTER INSERT OR DELETE ON public.safety_report_upvotes
  FOR EACH ROW EXECUTE FUNCTION public.safety_report_sync_upvotes();

-- ── 4. Content-Reports: 'safety_report' als content_type erlauben ───────────
-- Auto-Hide (>3 Meldungen) zählt aus public.reports (kanonische Melde-Tabelle).
ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_content_type_check;
ALTER TABLE public.reports ADD CONSTRAINT reports_content_type_check
  CHECK (content_type = ANY (ARRAY[
    'post','message','review','profile','marketplace','board',
    'comment','user','event','organization','board_post','crisis',
    'safety_report'
  ]));

-- ── 5. RLS ──────────────────────────────────────────────────────────────────
ALTER TABLE public.safety_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.safety_report_upvotes ENABLE ROW LEVEL SECURITY;

-- SELECT: jeder Eingeloggte sieht aktive/erledigte Meldungen (für Karte/Liste
-- + Realtime). 'removed' nur für Owner/Moderator. Die reporter_id ist zwar in
-- der Zeile vorhanden, wird aber bei anonym=true NIRGENDS aufgelöst:
--   * Anzeige-Pfad listNearby() nutzt die RPC get_nearby_safety_reports, die
--     reporter_id bei anonymous=true serverseitig auf NULL setzt.
--   * Profil-Joins auf reporter_id finden bei anonymen Meldungen nicht statt.
DROP POLICY IF EXISTS "safety_reports_select" ON public.safety_reports;
CREATE POLICY "safety_reports_select" ON public.safety_reports FOR SELECT
  USING (
    status IN ('active','resolved')
    OR auth.uid() = reporter_id
    OR EXISTS (SELECT 1 FROM public.profiles
               WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

DROP POLICY IF EXISTS "safety_reports_insert" ON public.safety_reports;
CREATE POLICY "safety_reports_insert" ON public.safety_reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

-- UPDATE: Owner darf eigene Meldung pflegen (z.B. markResolved), Moderation alles.
DROP POLICY IF EXISTS "safety_reports_update" ON public.safety_reports;
CREATE POLICY "safety_reports_update" ON public.safety_reports FOR UPDATE
  USING (
    auth.uid() = reporter_id
    OR EXISTS (SELECT 1 FROM public.profiles
               WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

DROP POLICY IF EXISTS "safety_reports_delete" ON public.safety_reports;
CREATE POLICY "safety_reports_delete" ON public.safety_reports FOR DELETE
  USING (
    auth.uid() = reporter_id
    OR EXISTS (SELECT 1 FROM public.profiles
               WHERE id = auth.uid() AND role IN ('admin','moderator'))
  );

-- Upvotes: lesen alle (für upvote_count-Konsistenz/eigene Stimme), schreiben/
-- löschen nur die eigene Stimme.
DROP POLICY IF EXISTS "safety_upvotes_select" ON public.safety_report_upvotes;
CREATE POLICY "safety_upvotes_select" ON public.safety_report_upvotes FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "safety_upvotes_insert" ON public.safety_report_upvotes;
CREATE POLICY "safety_upvotes_insert" ON public.safety_report_upvotes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "safety_upvotes_delete" ON public.safety_report_upvotes;
CREATE POLICY "safety_upvotes_delete" ON public.safety_report_upvotes FOR DELETE
  USING (auth.uid() = user_id);

-- ── 6. RPC: Meldungen in der Nähe ───────────────────────────────────────────
-- Geo-Filter (Bounding-Box + Haversine), Auto-Hide bei >3 Content-Reports und
-- serverseitige Anonymisierung (reporter_id = NULL wenn anonymous = true).
CREATE OR REPLACE FUNCTION public.get_nearby_safety_reports(
  p_lat       FLOAT,
  p_lng       FLOAT,
  p_radius_km FLOAT DEFAULT 5,
  p_limit     INT   DEFAULT 100
)
RETURNS JSON LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE v_result JSON;
BEGIN
  SELECT json_agg(sub) INTO v_result FROM (
    SELECT
      sr.id,
      CASE WHEN sr.anonymous THEN NULL ELSE sr.reporter_id END AS reporter_id,
      sr.title,
      sr.description,
      sr.incident_type,
      sr.anonymous,
      sr.location_address,
      sr.location_lat,
      sr.location_lng,
      sr.happened_at,
      sr.image_urls,
      sr.status,
      sr.upvote_count,
      sr.created_at,
      CASE
        WHEN sr.location_lat IS NULL OR sr.location_lng IS NULL THEN NULL
        ELSE ROUND((6371 * acos(LEAST(1, GREATEST(-1,
          cos(radians(p_lat)) * cos(radians(sr.location_lat)) *
          cos(radians(sr.location_lng) - radians(p_lng)) +
          sin(radians(p_lat)) * sin(radians(sr.location_lat))
        ))))::numeric, 1)
      END AS distance_km
    FROM public.safety_reports sr
    WHERE sr.status = 'active'
      AND sr.location_lat  IS NOT NULL
      AND sr.location_lng  IS NOT NULL
      AND sr.location_lat  BETWEEN p_lat - (p_radius_km / 111.0)
                               AND p_lat + (p_radius_km / 111.0)
      AND sr.location_lng  BETWEEN p_lng - (p_radius_km / (111.0 * cos(radians(p_lat))))
                               AND p_lng + (p_radius_km / (111.0 * cos(radians(p_lat))))
      -- Auto-Hide: mehr als 3 Content-Reports → ausblenden.
      AND (
        SELECT count(*) FROM public.reports r
         WHERE r.content_type = 'safety_report'
           AND r.content_id = sr.id
      ) <= 3
    ORDER BY distance_km ASC NULLS LAST, sr.created_at DESC
    LIMIT p_limit
  ) sub;
  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_nearby_safety_reports(FLOAT, FLOAT, FLOAT, INT) TO authenticated;

-- Realtime aktivieren (für watchNearby-Stream).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'safety_reports'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.safety_reports;
  END IF;
EXCEPTION WHEN undefined_object THEN
  -- Publication existiert in lokalen Setups evtl. nicht — dann überspringen.
  NULL;
END $$;
