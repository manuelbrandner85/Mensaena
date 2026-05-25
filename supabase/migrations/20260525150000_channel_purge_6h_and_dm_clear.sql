-- A) Channel-Auto-Delete alle 6h via pg_cron.
-- Loescht nur Messages in conversations, die ein chat_channels-Eintrag haben
-- (= echte Community-Rooms, NICHT DMs/Groups). Hard DELETE.

CREATE OR REPLACE FUNCTION public.purge_channel_messages_6h()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count integer;
BEGIN
  WITH deleted AS (
    DELETE FROM messages m
    WHERE m.conversation_id IN (
      SELECT conversation_id FROM chat_channels
      WHERE conversation_id IS NOT NULL
    )
    AND m.created_at < NOW() - INTERVAL '6 hours'
    RETURNING m.id
  )
  SELECT count(*) INTO deleted_count FROM deleted;

  INSERT INTO admin_audit_log (actor_id, action, table_name, details)
  SELECT
    (SELECT id FROM profiles WHERE role = 'admin' LIMIT 1),
    'channel_purge_6h',
    'messages',
    jsonb_build_object('deleted_count', deleted_count, 'at', NOW())
  WHERE deleted_count > 0;

  RETURN deleted_count;
END;
$$;

SELECT cron.unschedule('purge_channel_messages_6h')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'purge_channel_messages_6h');

SELECT cron.schedule(
  'purge_channel_messages_6h',
  '0 */6 * * *',
  $$SELECT public.purge_channel_messages_6h();$$
);

-- B) Clear-DM-History RPC.
-- User-callable; loescht ALLE messages in einer Conversation HART aus der DB.
-- Beide Teilnehmer sehen danach leeren Chat. Nur fuer DMs (type='dm').

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
  IF conv_type <> 'dm' THEN
    RAISE EXCEPTION 'clear_dm_history only works for DM conversations'
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

GRANT EXECUTE ON FUNCTION public.clear_dm_history(uuid) TO authenticated;
