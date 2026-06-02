-- Fix Race-Condition: get_or_create_dm machte SELECT-dann-INSERT ohne Lock.
-- Bei gleichzeitigen Aufrufen (Doppeltap / beide Nutzer öffnen DM zeitgleich)
-- fanden beide keine Konversation und legten beide eine an → doppelte DMs.
-- Lösung: Transaction-Advisory-Lock auf das (sortierte) Nutzer-Paar — damit
-- serialisieren konkurrierende Aufrufe, der zweite sieht die frisch angelegte.
create or replace function public.get_or_create_dm(p_other_user_id uuid, p_post_id uuid default null::uuid)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE me uuid; existing_conv_id uuid; new_conv_id uuid; a uuid; b uuid;
BEGIN
  me := auth.uid();
  IF me IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE='insufficient_privilege';
  END IF;
  IF me = p_other_user_id THEN
    RAISE EXCEPTION 'cannot DM self' USING ERRCODE='invalid_parameter_value';
  END IF;

  a := least(me, p_other_user_id);
  b := greatest(me, p_other_user_id);
  PERFORM pg_advisory_xact_lock(hashtextextended(a::text || ':' || b::text, 0));

  SELECT c.id INTO existing_conv_id
  FROM conversations c
  WHERE c.type IN ('dm','direct')
    AND EXISTS (SELECT 1 FROM conversation_members
                WHERE conversation_id=c.id AND user_id=me)
    AND EXISTS (SELECT 1 FROM conversation_members
                WHERE conversation_id=c.id AND user_id=p_other_user_id)
    AND (SELECT count(*) FROM conversation_members
         WHERE conversation_id=c.id) = 2
  LIMIT 1;

  IF existing_conv_id IS NOT NULL THEN
    UPDATE conversation_members SET hidden_at = NULL
      WHERE conversation_id = existing_conv_id
        AND user_id = me AND hidden_at IS NOT NULL;
    IF p_post_id IS NOT NULL THEN
      UPDATE conversations SET post_id = p_post_id
        WHERE id = existing_conv_id AND post_id IS NULL;
    END IF;
    RETURN existing_conv_id;
  END IF;

  INSERT INTO conversations(type, post_id)
    VALUES ('direct', p_post_id)
    RETURNING id INTO new_conv_id;
  INSERT INTO conversation_members(conversation_id, user_id) VALUES
    (new_conv_id, me),
    (new_conv_id, p_other_user_id);
  RETURN new_conv_id;
END;
$function$;
