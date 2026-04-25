-- ═══════════════════════════════════════════════════════════════════════════
-- Push Config + Critical Fixes
--
-- Fixes drei kritische Blocker die dafür sorgten, dass KEIN Push je ankam:
--
-- 1. private.push_config Table + get_push_config() RPC fehlten komplett.
--    Die send-push Edge Function rief adminClient.rpc('get_push_config') auf,
--    bekam einen Fehler und brach sofort ab → kein Push wurde je gesendet.
--
-- 2. trigger notify_push_on_new_notification() nutzte NEW.message (existiert
--    nicht) statt NEW.content → body war immer leer.
--
-- 3. URL im Push-Payload war hardcoded /dashboard/notifications statt dem
--    tatsächlichen Deep-Link (NEW.link) der Notification.
--
-- 4. notify_on_group_post_comment() speicherte nur /dashboard/groups statt
--    /dashboard/groups/{group_id} → User landete auf falscher Seite.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. private Schema + push_config Table ───────────────────────────────
CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE IF NOT EXISTS private.push_config (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- VAPID Keys (für Web Push / PWA)
-- Generiert am 2026-04-25. Wenn neu generiert werden: auch push-manager.ts
-- NEXT_PUBLIC_VAPID_PUBLIC_KEY und supabase/functions/send-push anpassen.
INSERT INTO private.push_config (key, value) VALUES
  ('vapid_public_key',  'BNVwkaAffvGVrO1fMD-JqtGjzT9pJptAxu88zfxliDkCbNn_mUnJHAeW0a0hLAc0_kE1PvMHKBWHB3x5mHmvf8I'),
  ('vapid_private_key', 'Adr-NxMY8UoHOgdLQqOdj0w6uwQ3uol0hoFvyavk-5U'),
  ('vapid_subject',     'mailto:info@mensaena.de'),
  -- FCM: nach Setup der Firebase-Service-Account-JSON hier eintragen
  -- (Repo → Settings → Actions → GOOGLE_SERVICES_JSON enthält App-Config,
  --  aber der Service Account für HTTP v1 API ist ein separater Download:
  --  Firebase Console → Projekteinstellungen → Dienstkonten → JSON generieren)
  ('fcm_project_id',          ''),
  ('fcm_service_account_json','')
ON CONFLICT (key) DO NOTHING;

-- ── 2. get_push_config() RPC (SECURITY DEFINER – Edge Function darf lesen) ─
CREATE OR REPLACE FUNCTION public.get_push_config()
RETURNS TABLE (key TEXT, value TEXT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = private, public
AS $$
  SELECT key, value FROM private.push_config;
$$;

-- Nur die Edge Function / service role darf diese Funktion aufrufen.
-- Normale anon-User dürfen nicht.
REVOKE ALL ON FUNCTION public.get_push_config() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_push_config() TO service_role;

-- ── 3. Fix: Push-Trigger-Payload ────────────────────────────────────────
-- Vorher: COALESCE(NEW.message, '')   → message-Spalte existiert nicht → leer
-- Vorher: '/dashboard/notifications'  → hardcoded, ignoriert den echten Link
-- Nachher: COALESCE(NEW.content, NEW.body, '') + COALESCE(NEW.link, '/dashboard/notifications')
CREATE OR REPLACE FUNCTION public.notify_push_on_new_notification()
RETURNS TRIGGER AS $$
DECLARE
  _supabase_url TEXT;
  _service_key  TEXT;
BEGIN
  IF NEW.read = true THEN
    RETURN NEW;
  END IF;

  _supabase_url := current_setting('app.settings.supabase_url', true);
  _service_key  := current_setting('app.settings.service_role_key', true);

  BEGIN
    PERFORM net.http_post(
      url     := _supabase_url || '/functions/v1/send-push',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || _service_key
      ),
      body    := jsonb_build_object(
        'user_id', NEW.user_id,
        'title',   COALESCE(NEW.title, 'Mensaena'),
        'body',    COALESCE(NEW.content, NEW.body, ''),
        'url',     COALESCE(NEW.link, '/dashboard/notifications'),
        'tag',     'notification-' || NEW.id::text
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'push notification trigger failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 4. Fix: group_post_comments Deep-Link ───────────────────────────────
-- Vorher: '/dashboard/groups' (keine Spezifizierung)
-- Nachher: '/dashboard/groups/' || group_id aus group_posts Tabelle
DO $outer$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'group_post_comments'
  ) THEN
    CREATE OR REPLACE FUNCTION public.notify_on_group_post_comment()
    RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
    DECLARE
      v_commenter_name TEXT;
      v_post_owner     UUID;
      v_group_id       UUID;
      v_preview        TEXT;
    BEGIN
      IF NEW.content IS NULL OR length(trim(NEW.content)) = 0 THEN RETURN NEW; END IF;

      SELECT user_id, group_id
        INTO v_post_owner, v_group_id
        FROM public.group_posts
       WHERE id = NEW.post_id;

      IF v_post_owner IS NULL OR v_post_owner = NEW.user_id THEN RETURN NEW; END IF;

      SELECT COALESCE(name, 'Jemand') INTO v_commenter_name
        FROM public.profiles WHERE id = NEW.user_id;

      v_preview := substring(trim(NEW.content) FROM 1 FOR 140);
      IF length(NEW.content) > 140 THEN v_preview := v_preview || '…'; END IF;

      INSERT INTO public.notifications
        (user_id, type, category, title, content, link, actor_id, metadata)
      VALUES (
        v_post_owner, 'system', 'comment',
        v_commenter_name || ' hat kommentiert',
        v_preview,
        CASE
          WHEN v_group_id IS NOT NULL THEN '/dashboard/groups/' || v_group_id::text
          ELSE '/dashboard/groups'
        END,
        NEW.user_id,
        jsonb_build_object('comment_id', NEW.id, 'group_post_id', NEW.post_id, 'group_id', v_group_id)
      );

      RETURN NEW;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'notify_on_group_post_comment: %', SQLERRM;
      RETURN NEW;
    END;
    $f$;
  END IF;
END $outer$;
