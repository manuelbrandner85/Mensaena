-- KRITISCH: farm_listings hatte RLS enabled aber 0 Policies → niemand konnte
-- SELECT machen (anon + authenticated). Versorgung-Screen war leer.
-- Web war eventuell ueber service-role-Bypass nicht betroffen.

-- Idempotent: DROP IF EXISTS, dann CREATE — sicher fuer Re-Apply via CI.
DROP POLICY IF EXISTS farm_listings_public_select ON public.farm_listings;
CREATE POLICY farm_listings_public_select ON public.farm_listings
  FOR SELECT
  USING (is_public = true);

DROP POLICY IF EXISTS farm_listings_admin_select ON public.farm_listings;
CREATE POLICY farm_listings_admin_select ON public.farm_listings
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
            AND role IN ('admin','moderator'))
  );

DROP POLICY IF EXISTS farm_listings_admin_all ON public.farm_listings;
CREATE POLICY farm_listings_admin_all ON public.farm_listings
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
            AND role IN ('admin','moderator'))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
            AND role IN ('admin','moderator'))
  );
