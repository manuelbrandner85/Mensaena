-- ═══════════════════════════════════════════════════════════════════════
-- NOTIFY_PUSH DEFAULT = TRUE
--
-- Push notifications should be opt-out, not opt-in. New profiles now
-- default to notify_push = true, and existing rows are backfilled so
-- the UI reflects the new default immediately.
--
-- A user still has to grant the browser push permission and create a
-- PushSubscription for anything to actually be delivered; this flag
-- just gates the server-side check in shouldNotifyPush().
-- ═══════════════════════════════════════════════════════════════════════

ALTER TABLE public.profiles
  ALTER COLUMN notify_push SET DEFAULT true;

UPDATE public.profiles
  SET notify_push = true
  WHERE notify_push IS DISTINCT FROM true;
