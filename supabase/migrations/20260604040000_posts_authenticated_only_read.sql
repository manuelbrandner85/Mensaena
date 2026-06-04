-- ═══════════════════════════════════════════════════════════════════════════
-- FIX H3 (Teil 1): Posts nur für eingeloggte User lesbar
--
-- Bisher galt posts_public_read für `public` = ALLE Rollen, inkl. `anon`
-- (nicht eingeloggt). Damit konnte ein anonymer Scraper ohne Account alle
-- aktiven Beiträge inkl. contact_phone, contact_email und exakter
-- latitude/longitude massenhaft abgreifen (Doxxing-/PII-Risiko).
--
-- FIX: SELECT nur noch `TO authenticated`. Die Flutter-App ist ohnehin
-- login-gated; das Web-Dashboard liest Posts ebenfalls nur im eingeloggten
-- Kontext. Ein Account ist damit Pflicht — und Accounts sind rate-limitbar
-- und sperrbar, anonyme Massen-Scrapes nicht.
--
-- HINWEIS: Eine feinere Per-Spalten-Privacy (contact_* nur für Freunde,
-- Koordinaten-Rundung) bleibt als separates Feature offen — dieser Fix
-- schließt den anonymen Scraping-Vektor sofort.
-- ═══════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "posts_public_read" ON public.posts;
CREATE POLICY "posts_authenticated_read" ON public.posts
  FOR SELECT TO authenticated
  USING (status = 'active' OR auth.uid() = user_id);

-- board_posts analog (gleicher anonymer Scraping-Vektor).
DROP POLICY IF EXISTS "board_posts_select" ON public.board_posts;
CREATE POLICY "board_posts_select" ON public.board_posts
  FOR SELECT TO authenticated
  USING (status = 'active' OR author_id = auth.uid());
