-- ═══════════════════════════════════════════════════════════════════════
-- PUSH SUBSCRIPTIONS – Web Push subscription storage
-- ═══════════════════════════════════════════════════════════════════════

-- ── Table ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint    TEXT NOT NULL,
  p256dh      TEXT NOT NULL,
  auth        TEXT NOT NULL,
  user_agent  TEXT,
  active      BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Unique constraint on endpoint (one subscription per browser)
ALTER TABLE public.push_subscriptions
  ADD CONSTRAINT push_subscriptions_endpoint_key UNIQUE (endpoint);

-- ── Indexes ──────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id
  ON public.push_subscriptions (user_id);

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_active
  ON public.push_subscriptions (active)
  WHERE active = true;

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_active
  ON public.push_subscriptions (user_id, active)
  WHERE active = true;

-- ── RLS ──────────────────────────────────────────────────────────────

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can read their own subscriptions
CREATE POLICY "Users can view own push subscriptions"
  ON public.push_subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own subscriptions
CREATE POLICY "Users can insert own push subscriptions"
  ON public.push_subscriptions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own subscriptions
CREATE POLICY "Users can update own push subscriptions"
  ON public.push_subscriptions FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own subscriptions
CREATE POLICY "Users can delete own push subscriptions"
  ON public.push_subscriptions FOR DELETE
  USING (auth.uid() = user_id);

-- Service role has full access (for edge function cleanup)
CREATE POLICY "Service role has full access to push subscriptions"
  ON public.push_subscriptions FOR ALL
  USING (auth.role() = 'service_role');

-- ── Auto-update updated_at ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_push_subscription_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_push_subscription_updated_at ON public.push_subscriptions;
CREATE TRIGGER trigger_push_subscription_updated_at
  BEFORE UPDATE ON public.push_subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION update_push_subscription_updated_at();

-- ═══════════════════════════════════════════════════════════════════════
-- PUSH NOTIFICATION TRIGGER – Fires on new notifications
-- ═══════════════════════════════════════════════════════════════════════
-- NOTE: This requires either:
--   a) pg_net extension enabled (Supabase dashboard → Database → Extensions)
--   b) A database webhook configured in Supabase dashboard
--
-- The function below calls the send-push Edge Function via pg_net.
-- If pg_net is not available, set up a Database Webhook in the Supabase
-- dashboard instead (Table: notifications, Event: INSERT, HTTP target).
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION notify_push_on_new_notification()
RETURNS TRIGGER AS $$
DECLARE
  _supabase_url TEXT;
  _service_key  TEXT;
BEGIN
  -- Only fire for new unread notifications
  IF NEW.read = true THEN
    RETURN NEW;
  END IF;

  -- Get project URL from secrets / env
  _supabase_url := current_setting('app.settings.supabase_url', true);
  _service_key  := current_setting('app.settings.service_role_key', true);

  -- Call the send-push edge function via pg_net (if available)
  -- Falls back silently if pg_net is not enabled
  BEGIN
    PERFORM net.http_post(
      url     := _supabase_url || '/functions/v1/send-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || _service_key
      ),
      body    := jsonb_build_object(
        'user_id', NEW.user_id,
        'title',   COALESCE(NEW.title, 'Mensaena'),
        'body',    COALESCE(NEW.message, ''),
        'url',     '/dashboard/notifications',
        'tag',     'notification-' || NEW.id::text
      )
    );
  EXCEPTION WHEN OTHERS THEN
    -- pg_net not available or call failed – ignore silently
    RAISE LOG 'push notification trigger failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger on the notifications table (if it exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'notifications'
  ) THEN
    DROP TRIGGER IF EXISTS trigger_push_on_notification ON public.notifications;
    CREATE TRIGGER trigger_push_on_notification
      AFTER INSERT ON public.notifications
      FOR EACH ROW
      EXECUTE FUNCTION notify_push_on_new_notification();
  END IF;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════
-- DONE
-- ═══════════════════════════════════════════════════════════════════════
