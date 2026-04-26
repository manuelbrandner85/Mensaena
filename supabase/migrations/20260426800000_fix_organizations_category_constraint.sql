-- Fix organizations category CHECK constraint to include 'jugendhilfe'
-- The original constraint in 20260101000008 only included 'jugend', but
-- migration 20260101000015 inserts rows with category 'jugendhilfe'.

ALTER TABLE public.organizations
  DROP CONSTRAINT IF EXISTS organizations_category_check;

ALTER TABLE public.organizations
  ADD CONSTRAINT organizations_category_check CHECK (category IN (
    'tierheim','tierschutz','suppenkueche','obdachlosenhilfe',
    'tafel','kleiderkammer','sozialkaufhaus','krisentelefon',
    'notschlafstelle','jugend','jugendhilfe','senioren','seniorenhilfe',
    'behinderung','sucht','fluechtlingshilfe','allgemein'
  ));
