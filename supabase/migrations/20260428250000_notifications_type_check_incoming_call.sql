-- ═══════════════════════════════════════════════════════════════════════════
-- KRITISCHER FIX: notifications.type CHECK constraint erlaubt 'incoming_call'
--
-- Vorher: CHECK constraint enthielt nicht 'incoming_call' und 'live_room_started'
--   → Trigger notify_on_dm_call versuchte INSERT mit type='incoming_call'
--   → DB rejectete mit 23514 (check constraint violation)
--   → EXCEPTION WHEN OTHERS schluckte den Fehler silently
--   → KEINE Notification wurde erstellt → KEIN Push → KEIN Anruf-Screen
--
-- Nachher: 'incoming_call' und 'live_room_started' sind valide types.
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check CHECK (
  type = ANY (ARRAY[
    'message'::text,
    'interaction'::text,
    'post_update'::text,
    'system'::text,
    'help_found'::text,
    'crisis_alert'::text,
    'new_match'::text,
    'match_both_accepted'::text,
    'match_partner_accepted'::text,
    'interaction_created'::text,
    'post_nearby'::text,
    'comment'::text,
    'rating'::text,
    'incoming_call'::text,
    'live_room_started'::text
  ])
);
