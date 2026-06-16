-- ════════════════════════════════════════════════════════════════════════
-- Security-Fix (Supabase-Advisor-Audit 2026-06-16)
--
-- #1 KRITISCH — Datenleck admin_users_view:
--   Die View exponiert E-Mail, letzte Anmeldung, Standort (lat/lng, PLZ, Stadt),
--   Rolle, Bann-Status & Bio ALLER Nutzer und war für anon + authenticated
--   lesbar (SECURITY DEFINER → umgeht RLS). Mit dem öffentlichen anon-Key
--   konnte jeder alle E-Mails + Wohnorte abziehen (DSGVO). Die App nutzt die
--   View nicht (nur ein Kommentar erwähnt sie) → Zugriff entziehen.
--   Admin-Auswertungen laufen weiterhin über service_role/Edge.
--
-- #2 MITTEL — unbeschränkte INSERTs:
--   post_shares + chat_channels hatten eine INSERT-Policy mit WITH CHECK true
--   OHNE Rollen-Beschränkung → auch anon konnte Zeilen einfügen. Auf
--   eingeloggte Nutzer beschränken (authenticated-Flows bleiben unberührt).
-- ════════════════════════════════════════════════════════════════════════

-- #1 — Zugriff auf die View für die öffentlichen Rollen entziehen.
revoke all on public.admin_users_view from anon;
revoke all on public.admin_users_view from authenticated;

-- #2 — anon-INSERT schließen (nur eingeloggte Nutzer dürfen einfügen).
drop policy if exists post_shares_insert on public.post_shares;
create policy post_shares_insert on public.post_shares
  for insert to authenticated
  with check (auth.uid() is not null);

drop policy if exists chat_channels_insert on public.chat_channels;
create policy chat_channels_insert on public.chat_channels
  for insert to authenticated
  with check (auth.uid() is not null);
