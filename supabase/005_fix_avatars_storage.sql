-- =========================================
-- MENSAENA: Fix avatars bucket + all storage policies
-- Run in: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new
-- Date: 2026-04-11
-- Purpose: Ensure avatars bucket exists with correct RLS
-- =========================================

-- ── 1. Create avatars bucket if missing ──
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,                          -- public read
  5242880,                       -- 5MB limit
  ARRAY['image/jpeg','image/png','image/webp','image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp','image/gif'];

-- ── 2. Drop existing avatar policies (safe re-run) ──
DO $$
BEGIN
  -- Drop all existing avatars policies to avoid duplicates
  DROP POLICY IF EXISTS "avatars_public_select" ON storage.objects;
  DROP POLICY IF EXISTS "avatars_auth_insert" ON storage.objects;
  DROP POLICY IF EXISTS "avatars_auth_update" ON storage.objects;
  DROP POLICY IF EXISTS "avatars_auth_delete" ON storage.objects;
  -- Also drop any legacy policy names
  DROP POLICY IF EXISTS "Avatar images are publicly accessible." ON storage.objects;
  DROP POLICY IF EXISTS "Anyone can upload an avatar." ON storage.objects;
  DROP POLICY IF EXISTS "Authenticated users can upload avatars" ON storage.objects;
  DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
  DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
END
$$;

-- ── 3. Create correct RLS policies for avatars ──

-- Public read (anyone can see avatars)
CREATE POLICY "avatars_public_select"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- Authenticated users can upload (INSERT) to avatars
CREATE POLICY "avatars_auth_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
  );

-- Authenticated users can update (for upsert) their own files
CREATE POLICY "avatars_auth_update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
  );

-- Authenticated users can delete their own files
CREATE POLICY "avatars_auth_delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
  );

-- ── 4. Ensure post-images bucket also exists ──
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'post-images',
  'post-images',
  true,
  10485760,  -- 10MB
  ARRAY['image/jpeg','image/png','image/webp','image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- ── 5. Verify: check buckets exist ──
-- After running, verify with:
-- SELECT id, name, public, file_size_limit FROM storage.buckets ORDER BY name;
-- SELECT policyname, tablename FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' ORDER BY policyname;

-- ── 6. Also ensure profiles RLS allows users to update their own profile ──
-- (avatar_url is stored in profiles table)
DO $$
BEGIN
  -- Check if update policy exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'profiles' 
    AND policyname = 'Users can update own profile'
  ) THEN
    CREATE POLICY "Users can update own profile"
      ON public.profiles FOR UPDATE
      USING (auth.uid() = id)
      WITH CHECK (auth.uid() = id);
  END IF;
END
$$;
