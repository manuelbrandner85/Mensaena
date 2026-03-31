-- =========================================
-- MENSAENA Storage RLS Policies (v1.0)
-- Ausführen in: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new
-- =========================================

-- Avatars Bucket Policies
CREATE POLICY IF NOT EXISTS "Avatare öffentlich lesbar"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');

CREATE POLICY IF NOT EXISTS "Eigene Avatare hochladen"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY IF NOT EXISTS "Eigene Avatare aktualisieren"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY IF NOT EXISTS "Eigene Avatare löschen"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Post-Images Bucket Policies
CREATE POLICY IF NOT EXISTS "Post-Bilder öffentlich lesbar"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'post-images');

CREATE POLICY IF NOT EXISTS "Post-Bilder hochladen"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'post-images' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY IF NOT EXISTS "Eigene Post-Bilder löschen"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'post-images' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Bestätigung
SELECT 'Storage Policies erfolgreich gesetzt ✅' AS status;
