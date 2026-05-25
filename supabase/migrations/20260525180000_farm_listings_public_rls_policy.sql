-- KRITISCH: farm_listings hatte RLS enabled aber 0 Policies → niemand konnte
-- SELECT machen (anon + authenticated). Versorgung-Screen war leer.
-- Web war eventuell ueber service-role-Bypass nicht betroffen.

CREATE POLICY farm_listings_public_select ON public.farm_listings
  FOR SELECT
  USING (is_public = true);

CREATE POLICY farm_listings_admin_select ON public.farm_listings
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
            AND role IN ('admin','moderator'))
  );

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
