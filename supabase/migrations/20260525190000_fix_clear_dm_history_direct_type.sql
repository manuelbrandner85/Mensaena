-- DB-Schema verwendet type='direct' fuer DM-Konversationen (nicht 'dm').
-- clear_dm_history rejected 'direct' → User bekam Fehler beim Trash-Tap
-- im DM-Chat-Header. Fix: beide Typen akzeptieren.

CREATE OR REPLACE FUNCTION public.clear_dm_history(p_conversation_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  conv_type text;
  is_member boolean;
  deleted_count integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT type INTO conv_type FROM conversations WHERE id = p_conversation_id;
  IF conv_type IS NULL THEN
    RAISE EXCEPTION 'conversation not found' USING ERRCODE = 'no_data_found';
  END IF;
  IF conv_type NOT IN ('dm', 'direct') THEN
    RAISE EXCEPTION 'clear_dm_history only works for direct conversations'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM conversation_members
    WHERE conversation_id = p_conversation_id AND user_id = auth.uid()
  ) INTO is_member;

  IF NOT is_member THEN
    RAISE EXCEPTION 'caller not a member of this conversation'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  WITH deleted AS (
    DELETE FROM messages WHERE conversation_id = p_conversation_id
    RETURNING id
  )
  SELECT count(*) INTO deleted_count FROM deleted;

  RETURN deleted_count;
END;
$$;
