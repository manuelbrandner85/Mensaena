-- Community-Raum erstellen: robust + mit Optionen (öffentlich/privat).
-- Problem vorher: Client-seitiges insert(conversations).select() scheiterte am
-- conv_select-RLS (Ersteller noch kein Mitglied) → Raum-Erstellung schlug fehl.
-- Lösung: atomare SECURITY-DEFINER-RPC + neue Spalten is_private/created_by.

ALTER TABLE public.chat_channels
  ADD COLUMN IF NOT EXISTS is_private boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id);

CREATE OR REPLACE FUNCTION public.create_community_channel(
  p_name text,
  p_emoji text DEFAULT '💬',
  p_description text DEFAULT NULL,
  p_category text DEFAULT 'Community',
  p_is_private boolean DEFAULT false
) RETURNS public.chat_channels
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_is_admin boolean;
  v_tier int;
  v_conv uuid;
  v_slug text;
  v_ch public.chat_channels;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT (role = 'admin'), COALESCE(donor_tier, 0)
    INTO v_is_admin, v_tier FROM profiles WHERE id = v_uid;
  -- Gate: Admins ODER Förderer (donor_tier >= 2) dürfen Räume erstellen.
  IF NOT COALESCE(v_is_admin, false) AND COALESCE(v_tier, 0) < 2 THEN
    RAISE EXCEPTION 'not_allowed';
  END IF;
  IF COALESCE(trim(p_name), '') = '' THEN RAISE EXCEPTION 'name_required'; END IF;

  INSERT INTO conversations(type, title) VALUES ('group', trim(p_name))
    RETURNING id INTO v_conv;

  -- Ersteller als owner-Mitglied → Conversation sofort sichtbar/nutzbar.
  INSERT INTO conversation_members(conversation_id, user_id, role)
    VALUES (v_conv, v_uid, 'owner');

  v_slug := regexp_replace(lower(trim(p_name)), '[^a-z0-9]+', '-', 'g');
  v_slug := regexp_replace(v_slug, '(^-+|-+$)', '', 'g');
  IF v_slug = '' THEN v_slug := 'kanal'; END IF;
  IF length(v_slug) > 36 THEN v_slug := substring(v_slug, 1, 36); END IF;
  v_slug := v_slug || '-' || substr(md5(random()::text || clock_timestamp()::text), 1, 6);

  INSERT INTO chat_channels(name, slug, emoji, description, category,
                            conversation_id, is_private, created_by)
    VALUES (trim(p_name), v_slug, COALESCE(NULLIF(trim(COALESCE(p_emoji,'')),''),'💬'),
            NULLIF(trim(COALESCE(p_description, '')), ''),
            COALESCE(NULLIF(trim(COALESCE(p_category,'')),''), 'Community'),
            v_conv, COALESCE(p_is_private, false), v_uid)
    RETURNING * INTO v_ch;

  RETURN v_ch;
END;
$$;

GRANT EXECUTE ON FUNCTION
  public.create_community_channel(text, text, text, text, boolean) TO authenticated;

-- Sichtbarkeit: öffentliche Kanäle für alle; private nur für Ersteller,
-- Mitglieder oder Admin (Admin „kommt immer rein" — zusätzlich via channels_admin).
DROP POLICY IF EXISTS chat_channels_select ON public.chat_channels;
CREATE POLICY chat_channels_select ON public.chat_channels FOR SELECT
USING (
  COALESCE(is_private, false) = false
  OR created_by = auth.uid()
  OR is_conversation_member(conversation_id, auth.uid())
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
