-- ═══════════════════════════════════════════════════════════════════════════
-- SECURITY-FIX B1: events + event_attendees RLS-Loch schließen
--
-- BUG: Die Policies "service_role full access events/event_attendees" waren
-- mit FOR ALL USING(true) WITH CHECK(true) angelegt, ABER OHNE `TO service_role`.
-- In Postgres gilt eine Policy ohne TO-Klausel für `public` = ALLE Rollen
-- (auch `authenticated`). Da permissive Policies mit OR kombiniert werden,
-- hebelte diese eine Policy die korrekten owner-only Update/Delete-Policies
-- komplett aus → JEDER eingeloggte User konnte JEDES Event und JEDE
-- Teilnahme editieren oder löschen.
--
-- FIX: Die zwei schädlichen Policies droppen. Der service_role-Key umgeht
-- RLS ohnehin vollständig — diese Policies waren nutzlos und gefährlich.
-- Die verbleibenden Policies (Anyone read active, owner insert/update/delete)
-- sind korrekt und ausreichend.
-- ═══════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "service_role full access events" ON public.events;
DROP POLICY IF EXISTS "service_role full access event_attendees" ON public.event_attendees;

-- Sicherstellen, dass die korrekten owner-Policies existieren (idempotent).
DO $$ BEGIN
  CREATE POLICY "Users can update own events" ON public.events
    FOR UPDATE USING (auth.uid() = author_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Users can delete own events" ON public.events
    FOR DELETE USING (auth.uid() = author_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
