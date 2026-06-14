-- Extend valid listing_type values for marketplace_listings to include
-- 'giveaway' (Verschenken) and 'swap' (Tauschen) in addition to the
-- existing German-locale values 'verschenken' and 'tauschen'.
-- The column is text (not a DB enum), so we formalise valid values via
-- a CHECK CONSTRAINT. NOT VALID ensures existing rows are not scanned.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'marketplace_listings_listing_type_check'
      AND conrelid = 'public.marketplace_listings'::regclass
  ) THEN
    ALTER TABLE public.marketplace_listings
      ADD CONSTRAINT marketplace_listings_listing_type_check
      CHECK (listing_type IS NULL OR listing_type IN (
        'verschenken', 'tauschen', 'giveaway', 'swap'
      )) NOT VALID;
  END IF;
END $$;

-- Index for efficient filtering by listing_type (used in listActive queries).
CREATE INDEX IF NOT EXISTS idx_marketplace_listing_type
  ON public.marketplace_listings (listing_type)
  WHERE listing_type IS NOT NULL;
