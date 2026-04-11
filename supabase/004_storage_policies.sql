-- =========================================
-- MENSAENA Storage RLS Policies (v2.1)
-- BEREITS AUSGEFUEHRT via Management API (2026-04-10)
-- 9 Buckets, 31 Policies
-- Updated: 2026-04-11 (added organization-images)
-- =========================================

-- Buckets: avatars, post-images, event-images, board-images,
--          chat-images, crisis-images, group-images, marketplace-images,
--          organization-images

-- avatars: SELECT(public), INSERT(auth), UPDATE(auth), DELETE(auth) = 4
-- post-images: SELECT(public), INSERT(auth), DELETE(auth) = 3
-- event-images: SELECT(public), INSERT(auth), DELETE(auth) = 3
-- board-images: SELECT(public), INSERT(auth), DELETE(auth) = 3
-- chat-images: SELECT(auth), INSERT(auth), UPDATE(auth), DELETE(auth) = 4
-- crisis-images: SELECT(public), INSERT(auth), DELETE(auth) = 3
-- group-images: SELECT(public), INSERT(auth), DELETE(auth) + 2 legacy = 5
-- marketplace-images: SELECT(public), INSERT(auth), DELETE(auth) = 3
-- organization-images: SELECT(public), INSERT(auth), DELETE(auth) = 3
-- Total: 31 policies

-- ── Create organization-images bucket if missing ──
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('organization-images', 'organization-images', true, 5242880, ARRAY['image/jpeg','image/png','image/webp','image/gif'])
ON CONFLICT (id) DO NOTHING;

-- ── Policies for organization-images ──
CREATE POLICY "organization-images_public_select"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'organization-images');

CREATE POLICY "organization-images_auth_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'organization-images' AND auth.role() = 'authenticated');

CREATE POLICY "organization-images_auth_delete"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'organization-images' AND auth.role() = 'authenticated');
