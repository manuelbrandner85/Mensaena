-- ═══════════════════════════════════════════════════════════════════════════
-- message_pins: Konversations-Mitglieder dürfen pinnen
--
-- Die existierende `pins_admin`-Policy auf message_pins erlaubt FOR ALL nur
-- Admins (role='admin' oder zwei hartcodierte E-Mails). Normale User
-- können daher in ihren EIGENEN DMs/Gruppen nicht pinnen — der INSERT wird
-- vom RLS silent geblockt. Der Client-Code (chat_screen.dart, Kommentar
-- "jeder Conversation-Member kann pinnen") setzt voraus, dass eine
-- pins_insert_member-Policy existiert — tut sie aber nicht. Diese
-- Migration legt sie an.
--
-- Regel: Ein User darf eine Nachricht pinnen/entpinnen, wenn er Mitglied
-- der Konversation ist UND nicht gerade jemand anderes Nachricht pinnt,
-- für die er nicht zuständig ist. Wir lassen das Mod-Recht (pins_admin)
-- unberührt — Admins bleiben überall berechtigt.
-- ═══════════════════════════════════════════════════════════════════════════

-- INSERT: jedes Mitglied der Konversation darf pinnen, sofern es sich
-- selbst als pinned_by einträgt.
DROP POLICY IF EXISTS pins_insert_member ON public.message_pins;
CREATE POLICY pins_insert_member ON public.message_pins
  FOR INSERT TO authenticated
  WITH CHECK (
    pinned_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = message_pins.conversation_id
        AND cm.user_id = auth.uid()
    )
  );

-- DELETE: jedes Mitglied der Konversation darf entpinnen (auch fremde
-- Pins entfernen — DMs/Gruppen sind klein, Mod-Konflikte unwahrscheinlich).
DROP POLICY IF EXISTS pins_delete_member ON public.message_pins;
CREATE POLICY pins_delete_member ON public.message_pins
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = message_pins.conversation_id
        AND cm.user_id = auth.uid()
    )
  );
