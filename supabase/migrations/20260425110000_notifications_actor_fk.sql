-- ═══════════════════════════════════════════════════════════════════════════
-- Fix: notifications.actor_id fehlender FK-Constraint
--
-- Bug: Migration 20260407020000_notification_center.sql hat:
--   ALTER TABLE notifications ADD COLUMN IF NOT EXISTS actor_id UUID
--     REFERENCES profiles(id) ON DELETE SET NULL;
-- Wenn die Spalte schon ohne FK existierte, hat IF NOT EXISTS den ALTER
-- übersprungen → FK wurde nie angelegt.
--
-- Resultat: Die App-Query in useNotificationStore nutzt
--   .select('*, profiles!notifications_actor_id_fkey(name, avatar_url)')
-- PostgREST kann den named relationship nicht auflösen → silent error,
-- Notifications-Liste bleibt LEER obwohl die Glocke korrekt eine Zahl zeigt.
-- ═══════════════════════════════════════════════════════════════════════════

-- Orphan actor_ids aufräumen (FK würde sonst fail)
UPDATE public.notifications
   SET actor_id = NULL
 WHERE actor_id IS NOT NULL
   AND actor_id NOT IN (SELECT id FROM public.profiles);

-- FK mit dem Namen den die App-Query erwartet
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'notifications_actor_id_fkey'
       AND conrelid = 'public.notifications'::regclass
  ) THEN
    ALTER TABLE public.notifications
      ADD CONSTRAINT notifications_actor_id_fkey
      FOREIGN KEY (actor_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
  END IF;
END $$;

-- PostgREST Schema-Cache reloaden damit der neue Constraint sofort greift
NOTIFY pgrst, 'reload schema';

-- Verify
SELECT
  EXISTS(SELECT 1 FROM pg_constraint
          WHERE conname = 'notifications_actor_id_fkey'
            AND conrelid = 'public.notifications'::regclass) AS fk_installed;
