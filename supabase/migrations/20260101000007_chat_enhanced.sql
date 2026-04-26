-- ============================================================
-- MENSAENA – Migration 007: Chat Erweiterungen (Enhanced)
-- - chat_channels: Mehrere Kanäle (Allgemein, Hilfe, Tiere, ...)
-- - message_pins: Angepinnte Nachrichten pro Kanal
-- - chat_announcements: Admin-Ankündigungen im Chat
-- - message_attachments: Dateianhänge an Nachrichten
-- - user_status: Online/Away/Busy Status
-- - read_receipts verbessert (schon in 005 last_read_at)
-- - Nutzer-Rollen in Konversationen (owner, admin, member)
-- ============================================================

-- ── 1. chat_channels: Mehrere öffentliche Kanäle ──────────────────────────────
CREATE TABLE IF NOT EXISTS public.chat_channels (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          TEXT NOT NULL,             -- z.B. "allgemein", "hilfe", "tiere"
  description   TEXT,
  emoji         TEXT DEFAULT '💬',
  slug          TEXT UNIQUE NOT NULL,      -- z.B. "allgemein"
  is_default    BOOLEAN DEFAULT FALSE,
  is_locked     BOOLEAN DEFAULT FALSE,
  locked_by     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  locked_at     TIMESTAMPTZ,
  locked_reason TEXT,
  sort_order    INTEGER DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  -- Verknüpfung mit conversations (jeder Kanal = 1 System-Konversation)
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_chat_channels_slug ON public.chat_channels(slug);
CREATE INDEX IF NOT EXISTS idx_chat_channels_conv  ON public.chat_channels(conversation_id);

ALTER TABLE public.chat_channels ENABLE ROW LEVEL SECURITY;
CREATE POLICY "channels_read"   ON public.chat_channels FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "channels_admin"  ON public.chat_channels FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  OR auth.email() = ANY(ARRAY['brandy13062@gmail.com', 'uwevetter@gmx.at'])
);

-- ── 2. Standard-Kanäle anlegen ────────────────────────────────────────────────
DO $$
DECLARE
  v_conv_id UUID;
  v_channel_id UUID;
BEGIN
  -- "Allgemein" Kanal (nutzt den bestehenden Community Chat)
  SELECT id INTO v_conv_id FROM public.conversations WHERE type = 'system' AND title = 'Community Chat' LIMIT 1;
  IF v_conv_id IS NOT NULL THEN
    INSERT INTO public.chat_channels (name, description, emoji, slug, is_default, sort_order, conversation_id)
    VALUES ('Allgemein', 'Allgemeine Diskussion für alle', '💬', 'allgemein', TRUE, 1, v_conv_id)
    ON CONFLICT (slug) DO NOTHING;
  END IF;

  -- "Hilfe gesucht" Kanal
  INSERT INTO public.conversations (type, title) VALUES ('system', 'Kanal: Hilfe gesucht')
  ON CONFLICT DO NOTHING RETURNING id INTO v_conv_id;
  IF v_conv_id IS NULL THEN
    SELECT id INTO v_conv_id FROM public.conversations WHERE title = 'Kanal: Hilfe gesucht' LIMIT 1;
  END IF;
  IF v_conv_id IS NOT NULL THEN
    INSERT INTO public.chat_channels (name, description, emoji, slug, sort_order, conversation_id)
    VALUES ('Hilfe gesucht', 'Hier kannst du Hilfe anfragen', '🆘', 'hilfe-gesucht', 2, v_conv_id)
    ON CONFLICT (slug) DO NOTHING;
  END IF;

  -- "Hilfe anbieten" Kanal
  INSERT INTO public.conversations (type, title) VALUES ('system', 'Kanal: Hilfe anbieten')
  ON CONFLICT DO NOTHING RETURNING id INTO v_conv_id;
  IF v_conv_id IS NULL THEN
    SELECT id INTO v_conv_id FROM public.conversations WHERE title = 'Kanal: Hilfe anbieten' LIMIT 1;
  END IF;
  IF v_conv_id IS NOT NULL THEN
    INSERT INTO public.chat_channels (name, description, emoji, slug, sort_order, conversation_id)
    VALUES ('Hilfe anbieten', 'Biete deine Hilfe anderen an', '🤝', 'hilfe-anbieten', 3, v_conv_id)
    ON CONFLICT (slug) DO NOTHING;
  END IF;

  -- "Tiere & Natur" Kanal
  INSERT INTO public.conversations (type, title) VALUES ('system', 'Kanal: Tiere & Natur')
  ON CONFLICT DO NOTHING RETURNING id INTO v_conv_id;
  IF v_conv_id IS NULL THEN
    SELECT id INTO v_conv_id FROM public.conversations WHERE title = 'Kanal: Tiere & Natur' LIMIT 1;
  END IF;
  IF v_conv_id IS NOT NULL THEN
    INSERT INTO public.chat_channels (name, description, emoji, slug, sort_order, conversation_id)
    VALUES ('Tiere & Natur', 'Austausch über Tiere und Natur', '🐾', 'tiere-natur', 4, v_conv_id)
    ON CONFLICT (slug) DO NOTHING;
  END IF;

  -- "Krisen & Notfall" Kanal
  INSERT INTO public.conversations (type, title) VALUES ('system', 'Kanal: Krisen & Notfall')
  ON CONFLICT DO NOTHING RETURNING id INTO v_conv_id;
  IF v_conv_id IS NULL THEN
    SELECT id INTO v_conv_id FROM public.conversations WHERE title = 'Kanal: Krisen & Notfall' LIMIT 1;
  END IF;
  IF v_conv_id IS NOT NULL THEN
    INSERT INTO public.chat_channels (name, description, emoji, slug, sort_order, conversation_id)
    VALUES ('Krisen & Notfall', 'Dringende Hilfe und Notfallsituationen', '🚨', 'krisen-notfall', 5, v_conv_id)
    ON CONFLICT (slug) DO NOTHING;
  END IF;
END $$;

-- ── 3. message_pins: Angepinnte Nachrichten ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.message_pins (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  message_id      UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  pinned_by       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  pinned_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(message_id)
);

CREATE INDEX IF NOT EXISTS idx_message_pins_conv ON public.message_pins(conversation_id);

ALTER TABLE public.message_pins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "pins_read"   ON public.message_pins FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "pins_admin"  ON public.message_pins FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  OR auth.email() = ANY(ARRAY['brandy13062@gmail.com', 'uwevetter@gmx.at'])
);

-- ── 4. chat_announcements: Admin-Ankündigungen ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.chat_announcements (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title           TEXT NOT NULL,
  content         TEXT NOT NULL,
  type            TEXT DEFAULT 'info'  CHECK (type IN ('info', 'warning', 'success', 'error')),
  is_active       BOOLEAN DEFAULT TRUE,
  created_by      UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  expires_at      TIMESTAMPTZ
);

ALTER TABLE public.chat_announcements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "announcements_read"  ON public.chat_announcements FOR SELECT USING (is_active = TRUE OR auth.email() = ANY(ARRAY['brandy13062@gmail.com', 'uwevetter@gmx.at']));
CREATE POLICY "announcements_admin" ON public.chat_announcements FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  OR auth.email() = ANY(ARRAY['brandy13062@gmail.com', 'uwevetter@gmx.at'])
);

-- ── 5. user_status: Online-Status der Nutzer ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_status (
  user_id     UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  status      TEXT DEFAULT 'offline'  CHECK (status IN ('online', 'away', 'busy', 'offline')),
  status_text TEXT,                    -- z.B. "Bin gleich zurück"
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_status ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_status_read"   ON public.user_status FOR SELECT USING (TRUE);
CREATE POLICY "user_status_update" ON public.user_status FOR ALL USING (user_id = auth.uid());

-- ── 6. conversation_roles: Rollen in Gruppenkonversationen ───────────────────
ALTER TABLE public.conversation_members
  ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member'));

-- ── 7. messages: Bearbeitung ermöglichen ─────────────────────────────────────
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE;

-- ── 8. RLS: Nachrichten in allen System-Kanälen lesbar/schreibbar ─────────────
-- Aktualisierung der bestehenden Policies um neue Kanäle einzuschließen
DROP POLICY IF EXISTS "community_room_messages_read" ON public.messages;
CREATE POLICY "community_room_messages_read" ON public.messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = messages.conversation_id
      AND (
        c.type = 'system'
        OR EXISTS (
          SELECT 1 FROM public.conversation_members cm
          WHERE cm.conversation_id = c.id AND cm.user_id = auth.uid()
        )
      )
    )
  );

DROP POLICY IF EXISTS "community_room_messages_insert" ON public.messages;
CREATE POLICY "community_room_messages_insert" ON public.messages
  FOR INSERT WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = messages.conversation_id
      AND (
        c.type = 'system'
        OR EXISTS (
          SELECT 1 FROM public.conversation_members cm
          WHERE cm.conversation_id = c.id AND cm.user_id = auth.uid()
        )
      )
    )
  );

-- ── 9. Realtime für neue Tabellen ─────────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_channels;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_announcements;
ALTER PUBLICATION supabase_realtime ADD TABLE public.message_pins;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_status;
