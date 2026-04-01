-- ============================================================
-- MENSAENA – KRITISCHER FIX: RLS Infinite Recursion
-- Datum: 2026-04-01
-- PROBLEM: conv_members_read policy verursacht infinite recursion
-- LÖSUNG: Security-Definer-Funktionen als recursion-breaker
-- ============================================================
-- ANLEITUNG:
-- 1. Öffne: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new
-- 2. Kompletten Inhalt kopieren und einfügen
-- 3. "Run" klicken
-- ============================================================

-- ── Schritt 1: Helper-Funktionen (SECURITY DEFINER = bypass RLS) ─────────────

-- Prüft ob ein User Mitglied einer Conversation ist (ohne RLS-Rekursion)
CREATE OR REPLACE FUNCTION public.is_conversation_member(conv_id UUID, uid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.conversation_members
    WHERE conversation_id = conv_id AND user_id = uid
  );
$$;

-- Gibt alle conversation_ids zurück, in denen ein User Mitglied ist
CREATE OR REPLACE FUNCTION public.get_user_conversation_ids(uid UUID)
RETURNS SETOF UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT conversation_id FROM public.conversation_members WHERE user_id = uid;
$$;

-- Gibt die Konversations-Typ zurück ohne RLS
CREATE OR REPLACE FUNCTION public.get_conversation_type(conv_id UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT type FROM public.conversations WHERE id = conv_id;
$$;

-- ── Schritt 2: conversation_members Policies komplett neu ────────────────────

-- Alle alten Policies entfernen
DROP POLICY IF EXISTS "conv_members_read"   ON public.conversation_members;
DROP POLICY IF EXISTS "conv_members_insert" ON public.conversation_members;
DROP POLICY IF EXISTS "conv_members_update" ON public.conversation_members;
DROP POLICY IF EXISTS "conv_members_delete" ON public.conversation_members;

-- Neue Policy: SELECT – nur eigene Mitgliedschaften ODER Mitglied der gleichen Conv
-- Kein Self-JOIN mehr → kein Infinite Loop
CREATE POLICY "conv_members_select" ON public.conversation_members
  FOR SELECT USING (
    auth.uid() IS NOT NULL AND (
      user_id = auth.uid()
      OR public.is_conversation_member(conversation_id, auth.uid())
    )
  );

CREATE POLICY "conv_members_insert" ON public.conversation_members
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "conv_members_update" ON public.conversation_members
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "conv_members_delete" ON public.conversation_members
  FOR DELETE USING (user_id = auth.uid());

-- ── Schritt 3: conversations Policies neu ────────────────────────────────────

DROP POLICY IF EXISTS "conversations_member_read"  ON public.conversations;
DROP POLICY IF EXISTS "conversations_system_read"  ON public.conversations;
DROP POLICY IF EXISTS "conversations_auth_insert"  ON public.conversations;
DROP POLICY IF EXISTS "conversations_auth_update"  ON public.conversations;
DROP POLICY IF EXISTS "conversations_lock_admin"   ON public.conversations;

-- System-Conversations (Channels) sind für alle eingeloggten User lesbar
-- DM-Conversations nur für Mitglieder
CREATE POLICY "conversations_read" ON public.conversations
  FOR SELECT USING (
    auth.uid() IS NOT NULL AND (
      type = 'system'
      OR public.is_conversation_member(id, auth.uid())
    )
  );

CREATE POLICY "conversations_insert" ON public.conversations
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "conversations_update" ON public.conversations
  FOR UPDATE USING (
    public.is_conversation_member(id, auth.uid())
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    OR auth.email() = ANY(ARRAY['brandy13062@gmail.com', 'uwevetter@gmx.at'])
  );

-- ── Schritt 4: messages Policies neu ─────────────────────────────────────────

DROP POLICY IF EXISTS "messages_conversation_read"       ON public.messages;
DROP POLICY IF EXISTS "messages_auth_insert"             ON public.messages;
DROP POLICY IF EXISTS "messages_auth_update"             ON public.messages;
DROP POLICY IF EXISTS "messages_auth_delete"             ON public.messages;
DROP POLICY IF EXISTS "community_room_messages_insert"   ON public.messages;
DROP POLICY IF EXISTS "messages_admin_delete"            ON public.messages;
DROP POLICY IF EXISTS "messages_admin_update"            ON public.messages;

-- READ: System-Conversations offen für alle, DM nur für Mitglieder
CREATE POLICY "messages_read" ON public.messages
  FOR SELECT USING (
    auth.uid() IS NOT NULL AND (
      public.get_conversation_type(conversation_id) = 'system'
      OR public.is_conversation_member(conversation_id, auth.uid())
    )
  );

-- INSERT: Jeder eingeloggte User kann in System-Conversations schreiben
--         In DMs nur Mitglieder
CREATE POLICY "messages_insert" ON public.messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id
    AND (
      public.get_conversation_type(conversation_id) = 'system'
      OR public.is_conversation_member(conversation_id, auth.uid())
    )
  );

-- UPDATE: Eigene Nachrichten bearbeiten (soft-delete, edit)
CREATE POLICY "messages_update_own" ON public.messages
  FOR UPDATE USING (
    sender_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    OR auth.email() = ANY(ARRAY['brandy13062@gmail.com', 'uwevetter@gmx.at'])
  );

-- DELETE: Nur Admins
CREATE POLICY "messages_delete" ON public.messages
  FOR DELETE USING (
    sender_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    OR auth.email() = ANY(ARRAY['brandy13062@gmail.com', 'uwevetter@gmx.at'])
  );

-- ── Schritt 5: chat_banned_users Policies ────────────────────────────────────

DROP POLICY IF EXISTS "banned_read"  ON public.chat_banned_users;
DROP POLICY IF EXISTS "banned_admin" ON public.chat_banned_users;

CREATE POLICY "banned_read_own" ON public.chat_banned_users
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "banned_admin_all" ON public.chat_banned_users
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    OR auth.email() = ANY(ARRAY['brandy13062@gmail.com', 'uwevetter@gmx.at'])
  );

-- ── Schritt 6: message_reactions Policies ────────────────────────────────────

DROP POLICY IF EXISTS "reactions_read"    ON public.message_reactions;
DROP POLICY IF EXISTS "reactions_insert"  ON public.message_reactions;
DROP POLICY IF EXISTS "reactions_delete"  ON public.message_reactions;

CREATE POLICY "reactions_read" ON public.message_reactions
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "reactions_insert" ON public.message_reactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "reactions_delete" ON public.message_reactions
  FOR DELETE USING (auth.uid() = user_id);

-- ── Schritt 7: message_pins Policies ─────────────────────────────────────────

DROP POLICY IF EXISTS "pins_read"  ON public.message_pins;
DROP POLICY IF EXISTS "pins_admin" ON public.message_pins;

CREATE POLICY "pins_read" ON public.message_pins
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "pins_admin" ON public.message_pins
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    OR auth.email() = ANY(ARRAY['brandy13062@gmail.com', 'uwevetter@gmx.at'])
  );

-- ── Schritt 8: chat_announcements Policies ───────────────────────────────────

DROP POLICY IF EXISTS "announcements_read"  ON public.chat_announcements;
DROP POLICY IF EXISTS "announcements_admin" ON public.chat_announcements;

CREATE POLICY "announcements_read" ON public.chat_announcements
  FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = true);

CREATE POLICY "announcements_admin" ON public.chat_announcements
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    OR auth.email() = ANY(ARRAY['brandy13062@gmail.com', 'uwevetter@gmx.at'])
  );

-- ── Schritt 9: user_status Policies ──────────────────────────────────────────

DROP POLICY IF EXISTS "status_read"   ON public.user_status;
DROP POLICY IF EXISTS "status_own"    ON public.user_status;

CREATE POLICY "status_read" ON public.user_status
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "status_own" ON public.user_status
  FOR ALL USING (user_id = auth.uid());

-- ── Schritt 10: Admin-User setzen ────────────────────────────────────────────

UPDATE public.profiles
SET role = 'admin'
WHERE email IN ('brandy13062@gmail.com', 'uwevetter@gmx.at');

-- ── Schritt 11: Tags-Spalte für posts ────────────────────────────────────────

ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

-- ── Schritt 12: push_subscriptions Tabelle ───────────────────────────────────

CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint   TEXT NOT NULL,
  p256dh     TEXT,
  auth       TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "push_own" ON public.push_subscriptions;
CREATE POLICY "push_own" ON public.push_subscriptions
  FOR ALL USING (auth.uid() = user_id);

-- ── Schritt 13: notifications Tabelle prüfen/anlegen ─────────────────────────

CREATE TABLE IF NOT EXISTS public.notifications (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type       TEXT DEFAULT 'system',
  title      TEXT,
  message    TEXT,
  url        TEXT DEFAULT '/dashboard',
  read       BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id, created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_own" ON public.notifications;
CREATE POLICY "notifications_own" ON public.notifications
  FOR ALL USING (auth.uid() = user_id);

-- Realtime für notifications
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

-- ── Schritt 14: Testmeldung dass alles OK ist ─────────────────────────────────

SELECT 'RLS FIX ERFOLGREICH ANGEWENDET' AS status,
       (SELECT COUNT(*) FROM public.chat_channels) AS channels,
       (SELECT COUNT(*) FROM public.conversations WHERE type = 'system') AS system_convs,
       (SELECT COUNT(*) FROM public.profiles) AS profiles;
