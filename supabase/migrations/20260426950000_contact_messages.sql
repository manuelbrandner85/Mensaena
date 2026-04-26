-- contact_messages: stores inbound contact form submissions
-- Public INSERT is intentional (anon users can submit). Reads are admin-only.

CREATE TABLE IF NOT EXISTS contact_messages (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT        NOT NULL CHECK (char_length(name)    BETWEEN 1 AND 100),
  email       TEXT        NOT NULL CHECK (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  subject     TEXT        NOT NULL CHECK (char_length(subject)  BETWEEN 1 AND 200),
  message     TEXT        NOT NULL CHECK (char_length(message) BETWEEN 10 AND 5000),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  read        BOOLEAN     NOT NULL DEFAULT FALSE
);

-- Anons may insert, nobody may read/update/delete via API (admin only via service role)
ALTER TABLE contact_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "contact_messages_insert_anon"
  ON contact_messages FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Admins and moderators may read and update (mark as read)
CREATE POLICY "contact_messages_select_admin"
  ON contact_messages FOR SELECT
  USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid())
    IN ('admin', 'moderator')
  );

CREATE POLICY "contact_messages_update_admin"
  ON contact_messages FOR UPDATE
  USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid())
    IN ('admin', 'moderator')
  );

-- Index for admin "unread first" view
CREATE INDEX IF NOT EXISTS contact_messages_created_at_idx
  ON contact_messages (created_at DESC);
