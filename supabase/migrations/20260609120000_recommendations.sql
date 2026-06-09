-- Tabelle für Nachbarschafts-Empfehlungen
-- Felder: Ziel-Person/Betrieb, Kategorie, Freitext, Sterne 1-5, optionale Fotos

CREATE TABLE IF NOT EXISTS public.recommendations (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Ziel: Entweder ein Nutzer-Profil oder eine Organisation
  target_user_id   UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  target_org_id    UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  target_name      TEXT,                          -- Freitext-Name falls kein Account

  category         TEXT NOT NULL DEFAULT 'general',
  -- Mögliche Werte: general, handcraft, garden, cleaning, cooking, care,
  --                 transport, tech, pets, shopping, tutoring, other

  text             TEXT NOT NULL CHECK (char_length(text) BETWEEN 10 AND 2000),
  stars            SMALLINT NOT NULL CHECK (stars BETWEEN 1 AND 5),

  -- Optionale Fotos (bis zu 5 URLs im Supabase-Storage)
  photo_urls       TEXT[] NOT NULL DEFAULT '{}',

  is_public        BOOLEAN NOT NULL DEFAULT true,
  is_flagged       BOOLEAN NOT NULL DEFAULT false,

  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT one_target CHECK (
    (target_user_id IS NOT NULL)::int +
    (target_org_id  IS NOT NULL)::int +
    (target_name    IS NOT NULL)::int = 1
  )
);

-- Trigger: updated_at automatisch aktualisieren
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS recommendations_updated_at ON public.recommendations;
CREATE TRIGGER recommendations_updated_at
  BEFORE UPDATE ON public.recommendations
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Indizes
CREATE INDEX IF NOT EXISTS recommendations_author_idx    ON public.recommendations(author_id);
CREATE INDEX IF NOT EXISTS recommendations_target_user_idx ON public.recommendations(target_user_id) WHERE target_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS recommendations_target_org_idx  ON public.recommendations(target_org_id)  WHERE target_org_id  IS NOT NULL;
CREATE INDEX IF NOT EXISTS recommendations_category_idx  ON public.recommendations(category);
CREATE INDEX IF NOT EXISTS recommendations_created_idx   ON public.recommendations(created_at DESC);

-- RLS aktivieren
ALTER TABLE public.recommendations ENABLE ROW LEVEL SECURITY;

-- Öffentliche Empfehlungen sind für alle sichtbar
CREATE POLICY "recommendations_select_public"
  ON public.recommendations FOR SELECT
  USING (is_public = true AND is_flagged = false);

-- Eigene Empfehlungen immer sichtbar
CREATE POLICY "recommendations_select_own"
  ON public.recommendations FOR SELECT
  USING (author_id = auth.uid());

-- Einfügen: nur eingeloggte Nutzer
CREATE POLICY "recommendations_insert"
  ON public.recommendations FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL AND author_id = auth.uid());

-- Aktualisieren / Löschen: nur eigene
CREATE POLICY "recommendations_update"
  ON public.recommendations FOR UPDATE
  USING (author_id = auth.uid());

CREATE POLICY "recommendations_delete"
  ON public.recommendations FOR DELETE
  USING (author_id = auth.uid());

-- Admins: vollen Zugriff
CREATE POLICY "recommendations_admin"
  ON public.recommendations FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Storage-Bucket für Empfehlungs-Fotos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'recommendation-photos',
  'recommendation-photos',
  true,
  5242880,    -- 5 MB
  ARRAY['image/jpeg','image/png','image/webp']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "recommendation_photos_select"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'recommendation-photos');

CREATE POLICY "recommendation_photos_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'recommendation-photos'
    AND auth.uid() IS NOT NULL
  );

CREATE POLICY "recommendation_photos_delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'recommendation-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
