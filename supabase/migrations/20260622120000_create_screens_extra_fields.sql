-- Mehrwert-Felder für die Erstellen-Screens (Batch B — neue Spalten).
-- Alle ADD COLUMN IF NOT EXISTS → idempotent, gefahrlos mehrfach ausführbar.

-- Marktplatz: Menge + Versand-Option (Radius + expires_at existieren bereits)
ALTER TABLE public.marketplace_listings
  ADD COLUMN IF NOT EXISTS quantity integer,
  ADD COLUMN IF NOT EXISTS shipping_available boolean DEFAULT false;

-- Organisations-Vorschläge: zusätzliche Profil-Infos, die admin → organizations
-- übernimmt (organizations hat diese Spalten bereits).
ALTER TABLE public.organization_suggestions
  ADD COLUMN IF NOT EXISTS zip_code text,
  ADD COLUMN IF NOT EXISTS opening_hours text,
  ADD COLUMN IF NOT EXISTS services text[],
  ADD COLUMN IF NOT EXISTS languages text[],
  ADD COLUMN IF NOT EXISTS accessibility text[];

-- Events: Anmeldeschluss + Co-Veranstalter
ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS registration_deadline timestamptz,
  ADD COLUMN IF NOT EXISTS cohost_name text;

-- Challenges: Cover-Bild + Belohnungs-Badge
ALTER TABLE public.challenges
  ADD COLUMN IF NOT EXISTS cover_url text,
  ADD COLUMN IF NOT EXISTS reward_badge text;

-- Gruppen: Gruppenregeln (avatar_url/banner_url existieren bereits)
ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS rules text;
