-- Favoriten / Merkliste für Marktplatz-Anzeigen.
-- marketplace_listings hat bereits favorite_count, aber keine echte Merkliste.

CREATE TABLE IF NOT EXISTS public.marketplace_favorites (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES public.marketplace_listings(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, listing_id)
);

ALTER TABLE public.marketplace_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mf_select ON public.marketplace_favorites;
CREATE POLICY mf_select ON public.marketplace_favorites FOR SELECT
  USING (user_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS mf_insert ON public.marketplace_favorites;
CREATE POLICY mf_insert ON public.marketplace_favorites FOR INSERT
  WITH CHECK (user_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS mf_delete ON public.marketplace_favorites;
CREATE POLICY mf_delete ON public.marketplace_favorites FOR DELETE
  USING (user_id = (SELECT auth.uid()));

CREATE INDEX IF NOT EXISTS idx_mf_user ON public.marketplace_favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_mf_listing ON public.marketplace_favorites(listing_id);

-- favorite_count auf dem Listing automatisch pflegen.
CREATE OR REPLACE FUNCTION public.mf_count_trg() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE marketplace_listings
      SET favorite_count = COALESCE(favorite_count, 0) + 1
      WHERE id = NEW.listing_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE marketplace_listings
      SET favorite_count = GREATEST(COALESCE(favorite_count, 0) - 1, 0)
      WHERE id = OLD.listing_id;
  END IF;
  RETURN NULL;
END; $$;

DROP TRIGGER IF EXISTS trg_mf_count ON public.marketplace_favorites;
CREATE TRIGGER trg_mf_count
  AFTER INSERT OR DELETE ON public.marketplace_favorites
  FOR EACH ROW EXECUTE FUNCTION public.mf_count_trg();
