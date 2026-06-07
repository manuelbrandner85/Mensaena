-- Admins und Moderatoren dürfen beliebige Posts löschen und bearbeiten.
-- Bisher gab es nur posts_own_delete/update (Besitzer-only).
-- Analoges Muster bereits vorhanden für groups, challenges, timebank.

DROP POLICY IF EXISTS "posts_admin_delete" ON public.posts;
CREATE POLICY "posts_admin_delete" ON public.posts
  FOR DELETE TO authenticated
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'moderator')
    )
  );

DROP POLICY IF EXISTS "posts_admin_update" ON public.posts;
CREATE POLICY "posts_admin_update" ON public.posts
  FOR UPDATE TO authenticated
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'moderator')
    )
  );
