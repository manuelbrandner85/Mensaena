-- Adds optional logo_url column to organization_suggestions so users can
-- attach a logo/photo when submitting an organization suggestion.
-- Additiv + idempotent: ADD COLUMN IF NOT EXISTS.

DO $$
BEGIN
  IF to_regclass('public.organization_suggestions') IS NOT NULL THEN
    ALTER TABLE public.organization_suggestions
      ADD COLUMN IF NOT EXISTS logo_url text;
  END IF;
END $$;
