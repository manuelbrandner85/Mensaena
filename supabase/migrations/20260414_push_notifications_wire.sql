-- ═══════════════════════════════════════════════════════════════════════
-- PUSH NOTIFICATIONS – Wire DB trigger → send-push Edge Function
--
-- Reconciles schema drift with the deployed push_subscriptions table
-- (adds active / updated_at columns, indexes, RLS) and creates the
-- INSERT trigger on notifications that calls the send-push function
-- via pg_net.
--
-- Requires:
--   * pg_net extension (already enabled)
--   * Edge function `send-push` deployed
--   * ALTER DATABASE … SET of:
--       app.settings.supabase_url
--       app.settings.supabase_anon_key
--       app.settings.push_webhook_secret
--     (applied separately via execute_sql, not in this migration so the
--      secret is never committed to git)
-- ═══════════════════════════════════════════════════════════════════════

-- ── Reconcile push_subscriptions schema ─────────────────────────────

ALTER TABLE public.push_subscriptions
  ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE public.push_subscriptions
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Unique endpoint: one subscription per browser/device.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'push_subscriptions_endpoint_key'
  ) THEN
    ALTER TABLE public.push_subscriptions
      ADD CONSTRAINT push_subscriptions_endpoint_key UNIQUE (endpoint);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_active
  ON public.push_subscriptions (user_id, active)
  WHERE active = true;

-- ── RLS ─────────────────────────────────────────────────────────────

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own push subscriptions"   ON public.push_subscriptions;
DROP POLICY IF EXISTS "Users can insert own push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Users can update own push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Users can delete own push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Service role has full access to push subscriptions" ON public.push_subscriptions;

CREATE POLICY "Users can view own push subscriptions"
  ON public.push_subscriptions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own push subscriptions"
  ON public.push_subscriptions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own push subscriptions"
  ON public.push_subscriptions FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own push subscriptions"
  ON public.push_subscriptions FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Service role has full access to push subscriptions"
  ON public.push_subscriptions FOR ALL
  USING (auth.role() = 'service_role');

-- ── updated_at auto-bump ────────────────────────────────────────────

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
-- TRIGGER: notifications INSERT → send-push edge function
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.notify_push_on_new_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  _url    TEXT;
  _anon   TEXT;
  _secret TEXT;
BEGIN
  -- Skip pre-read, deleted, or scheduled-in-the-future notifications.
  IF NEW.read = true OR NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Read DB-level config. If any of these are unset we bail silently
  -- (so INSERTs never fail because of push-config problems).
  _url    := current_setting('app.settings.supabase_url',       true);
  _anon   := current_setting('app.settings.supabase_anon_key',  true);
  _secret := current_setting('app.settings.push_webhook_secret', true);

  IF _url IS NULL OR _url = '' OR _anon IS NULL OR _anon = '' THEN
    RETURN NEW;
  END IF;

  BEGIN
    PERFORM net.http_post(
      url     := _url || '/functions/v1/send-push',
      headers := jsonb_build_object(
        'Content-Type',      'application/json',
        'Authorization',     'Bearer ' || _anon,
        'apikey',            _anon,
        'X-Webhook-Secret',  COALESCE(_secret, '')
      ),
      body    := jsonb_build_object(
        'user_id', NEW.user_id,
        'title',   COALESCE(NEW.title, 'Mensaena'),
        'body',    COALESCE(NEW.content, ''),
        'url',     COALESCE(NEW.link, '/dashboard/notifications'),
        'tag',     'notification-' || NEW.id::text
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'push notification trigger failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_push_on_notification ON public.notifications;
CREATE TRIGGER trigger_push_on_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_push_on_new_notification();

-- ═══════════════════════════════════════════════════════════════════════
-- DONE
-- ═══════════════════════════════════════════════════════════════════════
