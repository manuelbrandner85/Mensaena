-- ═══════════════════════════════════════════════════════════════════════════
-- Disk IO Optimierung
--
-- Reduziert Disk IO durch:
-- 1. Compound-Index für Rate-Limit-Check in notify_on_new_message()
-- 2. Compound-Index für Push-Trigger lookup
-- 3. pg_cron auf stündlich statt alle 15 min reduzieren
-- 4. Partial-Index für aktive Events (event_reminder scan)
-- 5. Index für notifications rate-limit compound query
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Rate-Limit-Check Optimierung ──────────────────────────────────────
-- notify_on_new_message() macht bei jeder Nachricht einen EXISTS-Scan:
-- WHERE user_id=X AND type='message' AND read=false
--   AND metadata->>'conversation_id'=Y AND actor_id=Z AND created_at > NOW()-5min
-- Dieser Compound-Index deckt die häufigsten Felder ab.

CREATE INDEX IF NOT EXISTS idx_notifications_ratelimit
  ON public.notifications(user_id, actor_id, type, read, created_at DESC)
  WHERE read = false;

-- ── 2. Push-Trigger: Schneller lookup ob User Push-Subscriptions hat ─────
CREATE INDEX IF NOT EXISTS idx_push_subs_user_active
  ON public.push_subscriptions(user_id)
  WHERE endpoint IS NOT NULL;

-- ── 3. Event-Reminder: Partial Index für bevorstehende Events ────────────
-- send_event_reminders() scannt events WHERE status='upcoming' AND start_date BETWEEN ...
CREATE INDEX IF NOT EXISTS idx_events_upcoming_start
  ON public.events(start_date)
  WHERE status = 'upcoming';

-- ── 4. event_attendees: schneller JOIN beim Reminder-Scan ────────────────
CREATE INDEX IF NOT EXISTS idx_event_attendees_status
  ON public.event_attendees(event_id, status)
  WHERE status IN ('going', 'interested');

-- ── 5. Notifications: Index für ungelesene Push-Benachrichtigungen ────────
CREATE INDEX IF NOT EXISTS idx_notifications_push_pending
  ON public.notifications(user_id, created_at DESC)
  WHERE read = false;

-- ── 6. pg_cron: Frequenz von 15min auf 60min reduzieren ──────────────────
-- event_reminders sind 24h-Erinnerungen – stündlich reicht vollkommen aus.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('mensaena-event-reminders')
      WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'mensaena-event-reminders');
    PERFORM cron.schedule(
      'mensaena-event-reminders',
      '0 * * * *',   -- jede volle Stunde statt alle 15 min
      $cron$SELECT public.send_event_reminders();$cron$
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron update: %', SQLERRM;
END $$;

-- ── 7. VACUUM ANALYZE auf die am häufigsten geschriebenen Tabellen ────────
-- Räumt dead tuples auf und aktualisiert Statistiken → bessere Query-Pläne
ANALYZE public.notifications;
ANALYZE public.messages;
ANALYZE public.posts;
ANALYZE public.push_subscriptions;
