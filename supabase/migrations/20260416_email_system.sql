-- ============================================================
-- E-Mail-System: Subscriptions, Kampagnen, Logs
-- ============================================================

-- ── 1. email_subscriptions ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.email_subscriptions (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email              text        NOT NULL,
  subscribed         boolean     NOT NULL DEFAULT true,
  unsubscribe_token  text        UNIQUE NOT NULL DEFAULT gen_random_uuid()::text,
  unsubscribed_at    timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

-- ── 2. email_campaigns ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.email_campaigns (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  type            text        NOT NULL CHECK (type IN ('welcome', 'newsletter', 'update', 'custom')),
  status          text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'sending', 'sent')),
  subject         text        NOT NULL,
  preview_text    text,
  html_content    text        NOT NULL,
  recipient_count int         NOT NULL DEFAULT 0,
  sent_count      int         NOT NULL DEFAULT 0,
  auto_generated  boolean     NOT NULL DEFAULT false,
  sent_at         timestamptz,
  created_by      uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- ── 3. email_logs ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.email_logs (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id  uuid        REFERENCES public.email_campaigns(id) ON DELETE CASCADE,
  user_id      uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  email        text        NOT NULL,
  status       text        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
  error_msg    text,
  sent_at      timestamptz NOT NULL DEFAULT now()
);

-- ── 4. updated_at Trigger ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_email_subscriptions_updated_at ON public.email_subscriptions;
CREATE TRIGGER trg_email_subscriptions_updated_at
  BEFORE UPDATE ON public.email_subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_email_campaigns_updated_at ON public.email_campaigns;
CREATE TRIGGER trg_email_campaigns_updated_at
  BEFORE UPDATE ON public.email_campaigns
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 5. Auto-Subscription bei Registrierung ─────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user_email_subscription()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.email_subscriptions (user_id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_email_sub ON auth.users;
CREATE TRIGGER on_auth_user_created_email_sub
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_email_subscription();

-- ── 6. RLS ─────────────────────────────────────────────────
ALTER TABLE public.email_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_campaigns     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_logs          ENABLE ROW LEVEL SECURITY;

-- email_subscriptions: User sieht/bearbeitet nur eigene Zeile
DROP POLICY IF EXISTS "subscription_select_own"  ON public.email_subscriptions;
DROP POLICY IF EXISTS "subscription_update_own"  ON public.email_subscriptions;
DROP POLICY IF EXISTS "subscription_admin_all"   ON public.email_subscriptions;

CREATE POLICY "subscription_select_own" ON public.email_subscriptions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "subscription_update_own" ON public.email_subscriptions
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "subscription_admin_all" ON public.email_subscriptions
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'moderator')
    )
  );

-- email_campaigns: Admins verwalten alles
DROP POLICY IF EXISTS "campaigns_admin_all" ON public.email_campaigns;
CREATE POLICY "campaigns_admin_all" ON public.email_campaigns
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'moderator')
    )
  );

-- email_logs: Admins lesen alles
DROP POLICY IF EXISTS "logs_admin_select" ON public.email_logs;
CREATE POLICY "logs_admin_select" ON public.email_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'moderator')
    )
  );

-- ── 7. Deletion followup table (Re-Engagement nach Kontolöschung) ──
CREATE TABLE IF NOT EXISTS public.email_deletion_followups (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  email              text        NOT NULL,
  display_name       text,
  deleted_at         timestamptz NOT NULL DEFAULT now(),
  emails_sent        int         NOT NULL DEFAULT 0,
  max_emails         int         NOT NULL DEFAULT 4,
  next_send_at       timestamptz,
  completed          boolean     NOT NULL DEFAULT false,
  unsubscribe_token  text        UNIQUE NOT NULL DEFAULT gen_random_uuid()::text,
  created_at         timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.email_deletion_followups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "deletion_followups_admin_all" ON public.email_deletion_followups;
CREATE POLICY "deletion_followups_admin_all" ON public.email_deletion_followups
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'moderator'))
  );

-- ── 8. Trigger: Löschung → Re-Engagement Followup ─────────
CREATE OR REPLACE FUNCTION public.handle_user_deleted_email_followup()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_name text;
BEGIN
  SELECT display_name INTO v_name FROM public.profiles WHERE id = OLD.id;
  INSERT INTO public.email_deletion_followups (email, display_name, next_send_at)
  VALUES (OLD.email, v_name, now());
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_deleted_email_followup ON auth.users;
CREATE TRIGGER on_auth_user_deleted_email_followup
  BEFORE DELETE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_user_deleted_email_followup();

-- ── 9. Indexes ─────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_email_subscriptions_user_id ON public.email_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_email_subscriptions_token   ON public.email_subscriptions(unsubscribe_token);
CREATE INDEX IF NOT EXISTS idx_email_subscriptions_subscribed ON public.email_subscriptions(subscribed);
CREATE INDEX IF NOT EXISTS idx_email_campaigns_status      ON public.email_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_email_campaigns_type        ON public.email_campaigns(type);
CREATE INDEX IF NOT EXISTS idx_email_logs_campaign_id      ON public.email_logs(campaign_id);
CREATE INDEX IF NOT EXISTS idx_email_logs_user_id          ON public.email_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_deletion_followups_next     ON public.email_deletion_followups(next_send_at) WHERE NOT completed;
CREATE INDEX IF NOT EXISTS idx_deletion_followups_token    ON public.email_deletion_followups(unsubscribe_token);

-- ── 10. Vorhandene User in Subscriptions aufnehmen ──────────
-- (einmalig, für bereits registrierte User)
INSERT INTO public.email_subscriptions (user_id, email)
SELECT u.id, u.email
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM public.email_subscriptions s WHERE s.user_id = u.id
)
ON CONFLICT (user_id) DO NOTHING;
