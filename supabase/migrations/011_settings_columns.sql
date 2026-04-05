-- Migration: 011_settings_columns
-- Add all settings-related columns to profiles table

-- Profil & Standort
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS homepage TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS radius_km INTEGER DEFAULT 5;

-- Benachrichtigungen
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_new_messages BOOLEAN DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_new_interactions BOOLEAN DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_nearby_posts BOOLEAN DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_trust_ratings BOOLEAN DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_system BOOLEAN DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_email BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_push BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notification_radius_km INTEGER DEFAULT 10;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_inactivity_reminder BOOLEAN DEFAULT true;

-- Privatsphäre
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS show_online_status BOOLEAN DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS show_location BOOLEAN DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS show_trust_score BOOLEAN DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS show_activity BOOLEAN DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS show_phone BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS allow_messages_from TEXT DEFAULT 'everyone';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS read_receipts BOOLEAN DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS allow_matching BOOLEAN DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS profile_visibility TEXT DEFAULT 'public';

-- Rollen & Features
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_mentor BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS mentor_topics TEXT[] DEFAULT '{}';

-- Notfall-Kontakte (JSONB Array)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS emergency_contacts JSONB DEFAULT '[]'::jsonb;

-- Account-Status
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deletion_confirmed BOOLEAN DEFAULT false;

-- Add CHECK constraints (only if they don't exist)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'profiles_allow_messages_from_check'
  ) THEN
    ALTER TABLE profiles ADD CONSTRAINT profiles_allow_messages_from_check
      CHECK (allow_messages_from IN ('everyone', 'trusted', 'nobody'));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'profiles_profile_visibility_check'
  ) THEN
    ALTER TABLE profiles ADD CONSTRAINT profiles_profile_visibility_check
      CHECK (profile_visibility IN ('public', 'neighbors', 'private'));
  END IF;
END $$;
