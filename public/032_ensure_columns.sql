-- ================================================================
-- Migration 032: Sicherstellen, dass alle benoetigten Spalten
-- und Tabellen existieren (profiles, marketplace_listings, groups)
-- AUTOMATISCH AUSGEFUEHRT am 2026-04-11 via Supabase Management API
-- ================================================================

-- =============================================
-- 1) profiles: Alle Settings-Felder sicherstellen
-- =============================================
DO $$ BEGIN
  -- Identitaet
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS display_name text;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS username text;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bio text DEFAULT '';
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone text;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS homepage text;

  -- Standort
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS address text;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS latitude double precision;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS longitude double precision;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS radius_km integer DEFAULT 5;

  -- Benachrichtigungen
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_new_messages boolean DEFAULT true;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_new_interactions boolean DEFAULT true;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_nearby_posts boolean DEFAULT true;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_trust_ratings boolean DEFAULT true;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_system boolean DEFAULT true;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_email boolean DEFAULT false;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_push boolean DEFAULT false;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notification_radius_km integer DEFAULT 10;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_inactivity_reminder boolean DEFAULT true;

  -- Privatsphaere
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS show_online_status boolean DEFAULT true;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS show_location boolean DEFAULT true;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS show_trust_score boolean DEFAULT true;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS show_activity boolean DEFAULT true;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS show_phone boolean DEFAULT false;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS allow_messages_from text DEFAULT 'everyone';
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS read_receipts boolean DEFAULT true;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS allow_matching boolean DEFAULT true;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS profile_visibility text DEFAULT 'public';

  -- Mentor
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_mentor boolean DEFAULT false;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS mentor_topics text[] DEFAULT '{}';

  -- Notfall
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS emergency_contacts jsonb DEFAULT '[]';

  -- Verifizierung
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS verified_email boolean DEFAULT false;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS verified_phone boolean DEFAULT false;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS verified_community boolean DEFAULT false;

  -- Account-Loeschung
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deletion_requested_at timestamptz;
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deletion_confirmed boolean DEFAULT false;

EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'profiles column migration partially failed: %', SQLERRM;
END $$;

-- username unique index
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_username
  ON profiles (username)
  WHERE username IS NOT NULL;

-- =============================================
-- 2) marketplace_listings: Bridge-Spalten fuer Code-Kompatibilitaet
-- DB hat: user_id, condition, listing_type, images
-- Code erwartet auch: seller_id, condition_state, price_type, image_urls, price
-- =============================================
DO $$ BEGIN
  ALTER TABLE marketplace_listings ADD COLUMN IF NOT EXISTS price numeric(10,2) DEFAULT 0;
  ALTER TABLE marketplace_listings ADD COLUMN IF NOT EXISTS price_type text DEFAULT 'negotiable';
  ALTER TABLE marketplace_listings ADD COLUMN IF NOT EXISTS condition_state text DEFAULT 'gut';
  ALTER TABLE marketplace_listings ADD COLUMN IF NOT EXISTS seller_id uuid REFERENCES profiles(id) ON DELETE CASCADE;
  ALTER TABLE marketplace_listings ADD COLUMN IF NOT EXISTS image_urls text[] DEFAULT '{}';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'marketplace bridge columns: %', SQLERRM;
END $$;

-- Sync seller_id from user_id for existing rows
UPDATE marketplace_listings SET seller_id = user_id WHERE seller_id IS NULL AND user_id IS NOT NULL;
UPDATE marketplace_listings SET condition_state = condition WHERE condition_state IS NULL AND condition IS NOT NULL;
UPDATE marketplace_listings SET image_urls = images WHERE image_urls = '{}' AND images != '{}';

ALTER TABLE marketplace_listings ENABLE ROW LEVEL SECURITY;
-- RLS: user_id based (original schema)
DO $$ BEGIN
  CREATE POLICY ml_sel ON marketplace_listings FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY ml_ins_uid ON marketplace_listings FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY ml_upd_uid ON marketplace_listings FOR UPDATE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY ml_del_uid ON marketplace_listings FOR DELETE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_ml_status ON marketplace_listings(status);
CREATE INDEX IF NOT EXISTS idx_ml_cat ON marketplace_listings(category);

-- =============================================
-- 3) groups: Bridge-Spalten fuer Code-Kompatibilitaet
-- DB hat: created_by, is_public
-- Code erwartet auch: creator_id, is_private, image_url, post_count
-- =============================================
DO $$ BEGIN
  ALTER TABLE groups ADD COLUMN IF NOT EXISTS creator_id uuid REFERENCES profiles(id) ON DELETE CASCADE;
  ALTER TABLE groups ADD COLUMN IF NOT EXISTS is_private boolean DEFAULT false;
  ALTER TABLE groups ADD COLUMN IF NOT EXISTS image_url text;
  ALTER TABLE groups ADD COLUMN IF NOT EXISTS post_count integer DEFAULT 0;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'groups bridge columns: %', SQLERRM;
END $$;

-- Sync creator_id from created_by, is_private from is_public
UPDATE groups SET creator_id = created_by WHERE creator_id IS NULL AND created_by IS NOT NULL;
UPDATE groups SET is_private = NOT is_public WHERE is_private IS NULL AND is_public IS NOT NULL;

ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY grp_sel ON groups FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY grp_ins_cb ON groups FOR INSERT WITH CHECK (auth.uid() = created_by);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY grp_upd_cb ON groups FOR UPDATE USING (auth.uid() = created_by);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY grp_del_cb ON groups FOR DELETE USING (auth.uid() = created_by);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- =============================================
-- 4) group_members: Tabelle sicherstellen
-- =============================================
CREATE TABLE IF NOT EXISTS group_members (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member',
  joined_at timestamptz DEFAULT now(),
  CONSTRAINT uq_gm UNIQUE (group_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_gm_group ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_gm_user ON group_members(user_id);

ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

-- =============================================
-- 5) Admin-freundliche RLS: Admins + Mods koennen alles
-- =============================================
CREATE OR REPLACE FUNCTION is_admin_or_mod() RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role IN ('admin', 'moderator')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Admin policies fuer marketplace_listings
DO $$ BEGIN
  CREATE POLICY ml_admin_all ON marketplace_listings
    FOR ALL USING (is_admin_or_mod());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Admin policies fuer groups
DO $$ BEGIN
  CREATE POLICY grp_admin_all ON groups
    FOR ALL USING (is_admin_or_mod());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Admin policies fuer group_members
DO $$ BEGIN
  CREATE POLICY gm_admin_all ON group_members
    FOR ALL USING (is_admin_or_mod());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Done!
SELECT 'Migration 032 abgeschlossen – automatisch ausgefuehrt am 2026-04-11' AS status;
