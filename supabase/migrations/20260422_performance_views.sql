-- conversation_members hat last_read_at (005_chat_improvements) und created_at (join-Zeitpunkt)
CREATE OR REPLACE VIEW v_unread_counts AS
SELECT
  cm.user_id,
  cm.conversation_id,
  (SELECT COUNT(*) FROM messages m
   WHERE m.conversation_id = cm.conversation_id
     AND m.sender_id != cm.user_id
     AND m.created_at > COALESCE(cm.last_read_at, cm.created_at, '1970-01-01')) AS unread_count,
  lm.content     AS last_message_text,
  lm.created_at  AS last_message_at,
  sp.name        AS sender_name,
  sp.avatar_url  AS sender_avatar
FROM conversation_members cm
LEFT JOIN LATERAL (
  SELECT content, created_at, sender_id
  FROM messages
  WHERE conversation_id = cm.conversation_id
  ORDER BY created_at DESC
  LIMIT 1
) lm ON true
LEFT JOIN profiles sp ON lm.sender_id = sp.id;

CREATE OR REPLACE VIEW v_active_posts AS
SELECT
  p.*,
  pr.name      AS author_name,
  pr.avatar_url AS author_avatar,
  pr.nickname  AS author_nickname
FROM posts p
JOIN profiles pr ON p.user_id = pr.id
WHERE p.status = 'active';
