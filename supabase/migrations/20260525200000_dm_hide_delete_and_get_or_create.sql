-- F1c/F2c: 3 RPCs fuer DM-Management
-- hide_dm_for_me(conv_id) — soft, nur fuer caller versteckt (hidden_at)
-- delete_dm_for_both(conv_id) — HARD DELETE der ganzen Konversation
-- get_or_create_dm(other_user_id) — startet/findet 1:1-Konversation

ALTER TABLE public.conversation_members
  ADD COLUMN IF NOT EXISTS hidden_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_cm_user_hidden
  ON public.conversation_members (user_id, hidden_at);

CREATE OR REPLACE FUNCTION public.hide_dm_for_me(p_conversation_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  conv_type text;
BEGIN
  IF auth.uid() IS NULL THEN RETURN false; END IF;
  SELECT type INTO conv_type FROM conversations WHERE id = p_conversation_id;
  IF conv_type NOT IN ('dm', 'direct') THEN
    RAISE EXCEPTION 'hide_dm_for_me only for direct conversations' USING ERRCODE = 'invalid_parameter_value';
  END IF;
  UPDATE conversation_members
  SET hidden_at = NOW()
  WHERE conversation_id = p_conversation_id AND user_id = auth.uid();
  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_dm_for_both(p_conversation_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  conv_type text;
  is_member boolean;
BEGIN
  IF auth.uid() IS NULL THEN RETURN false; END IF;
  SELECT type INTO conv_type FROM conversations WHERE id = p_conversation_id;
  IF conv_type NOT IN ('dm', 'direct') THEN
    RAISE EXCEPTION 'delete_dm_for_both only for direct conversations' USING ERRCODE = 'invalid_parameter_value';
  END IF;
  SELECT EXISTS(SELECT 1 FROM conversation_members
    WHERE conversation_id = p_conversation_id AND user_id = auth.uid())
  INTO is_member;
  IF NOT is_member THEN
    RAISE EXCEPTION 'caller not a member' USING ERRCODE = 'insufficient_privilege';
  END IF;
  DELETE FROM conversations WHERE id = p_conversation_id;
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_or_create_dm(p_other_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  me uuid;
  existing_conv_id uuid;
  new_conv_id uuid;
BEGIN
  me := auth.uid();
  IF me IS NULL THEN RAISE EXCEPTION 'auth required' USING ERRCODE='insufficient_privilege'; END IF;
  IF me = p_other_user_id THEN RAISE EXCEPTION 'cannot DM self' USING ERRCODE='invalid_parameter_value'; END IF;
  SELECT c.id INTO existing_conv_id
  FROM conversations c
  WHERE c.type IN ('dm','direct')
    AND EXISTS (SELECT 1 FROM conversation_members WHERE conversation_id=c.id AND user_id=me)
    AND EXISTS (SELECT 1 FROM conversation_members WHERE conversation_id=c.id AND user_id=p_other_user_id)
    AND (SELECT count(*) FROM conversation_members WHERE conversation_id=c.id) = 2
  LIMIT 1;
  IF existing_conv_id IS NOT NULL THEN
    UPDATE conversation_members
    SET hidden_at = NULL
    WHERE conversation_id = existing_conv_id AND user_id = me AND hidden_at IS NOT NULL;
    RETURN existing_conv_id;
  END IF;
  INSERT INTO conversations(type) VALUES ('direct') RETURNING id INTO new_conv_id;
  INSERT INTO conversation_members(conversation_id, user_id) VALUES
    (new_conv_id, me),
    (new_conv_id, p_other_user_id);
  RETURN new_conv_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.hide_dm_for_me(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_dm_for_both(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_dm(uuid) TO authenticated;
