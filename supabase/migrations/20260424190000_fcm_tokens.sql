-- ═══════════════════════════════════════════════════════════════════════════
-- FCM Tokens for Capacitor Push Notifications
--
-- Web Push (push_subscriptions Tabelle) funktioniert nicht zuverlässig in
-- Capacitor-APKs wenn die App geschlossen ist. Für echte Hintergrund-Pushes
-- im Capacitor-APK nutzen wir Firebase Cloud Messaging (FCM).
--
-- Diese Tabelle speichert FCM-Registration-Tokens, die der Client nach
-- PushNotifications.register() an uns sendet.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token       text NOT NULL,
  platform    text NOT NULL CHECK (platform IN ('android', 'ios')),
  app_version text,
  device_info text,
  active      boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  last_used   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user ON public.fcm_tokens(user_id) WHERE active;
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_token ON public.fcm_tokens(token) WHERE active;

-- updated_at auto-bump
CREATE OR REPLACE FUNCTION public.update_fcm_token_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_fcm_token_updated_at ON public.fcm_tokens;
CREATE TRIGGER trg_fcm_token_updated_at
  BEFORE UPDATE ON public.fcm_tokens
  FOR EACH ROW
  EXECUTE FUNCTION public.update_fcm_token_updated_at();

-- ── RLS ──────────────────────────────────────────────────────────────
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fcm_token_select_own" ON public.fcm_tokens
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "fcm_token_insert_own" ON public.fcm_tokens
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "fcm_token_update_own" ON public.fcm_tokens
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "fcm_token_delete_own" ON public.fcm_tokens
  FOR DELETE USING (auth.uid() = user_id);

-- ── FCM Service Account (für send-push Edge Function) ────────────────
-- Das JSON des Firebase Service Accounts (für HTTP v1 API) liegt in
-- private.push_config. Die Edge Function lädt es via get_push_config().
INSERT INTO private.push_config (key, value) VALUES
  ('fcm_project_id', ''),
  ('fcm_service_account_json', '')
ON CONFLICT (key) DO NOTHING;

COMMENT ON TABLE public.fcm_tokens IS
  'Firebase Cloud Messaging tokens for Capacitor-APK push notifications. '
  'Complements push_subscriptions (Web Push / PWA). '
  'Populated by @capacitor/push-notifications register() callback.';
