-- Fix conversations_admin_update policy:
-- Remove the overly permissive 'OR auth.uid() IS NOT NULL' from USING,
-- and add WITH CHECK so the admin predicate is enforced on new row values too.

DROP POLICY IF EXISTS "conversations_admin_update" ON public.conversations;

CREATE POLICY "conversations_admin_update" ON public.conversations
  FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );
