-- =========================================
-- MENSAENA Storage RLS Policies (v2.0)
-- BEREITS AUSGEFUEHRT via Management API (2026-04-10)
-- 8 Buckets, 28 Policies
-- =========================================

-- Buckets: avatars, post-images, event-images, board-images,
--          chat-images, crisis-images, group-images, marketplace-images

-- avatars: SELECT(public), INSERT(auth), UPDATE(auth), DELETE(auth) = 4
-- post-images: SELECT(public), INSERT(auth), DELETE(auth) = 3
-- event-images: SELECT(public), INSERT(auth), DELETE(auth) = 3
-- board-images: SELECT(public), INSERT(auth), DELETE(auth) = 3
-- chat-images: SELECT(auth), INSERT(auth), UPDATE(auth), DELETE(auth) = 4
-- crisis-images: SELECT(public), INSERT(auth), DELETE(auth) = 3
-- group-images: SELECT(public), INSERT(auth), DELETE(auth) + 2 legacy = 5
-- marketplace-images: SELECT(public), INSERT(auth), DELETE(auth) = 3
-- Total: 28 policies
