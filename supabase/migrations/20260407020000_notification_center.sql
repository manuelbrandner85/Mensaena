-- ═══════════════════════════════════════════════════════════════════════
-- NOTIFICATION CENTER – Erweiterte Benachrichtigungen
-- ═══════════════════════════════════════════════════════════════════════

-- ── Neue Spalten ─────────────────────────────────────────────────────

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'system';
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS read BOOLEAN DEFAULT false;

-- ── Indizes ──────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_notifications_user_read
  ON notifications(user_id, read) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_user_category
  ON notifications(user_id, category) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_created_at
  ON notifications(created_at DESC);

-- ── RLS Policies ─────────────────────────────────────────────────────

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can read own notifications'
  ) THEN
    CREATE POLICY "Users can read own notifications"
      ON notifications FOR SELECT USING (auth.uid() = user_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can update own notifications'
  ) THEN
    CREATE POLICY "Users can update own notifications"
      ON notifications FOR UPDATE
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can delete own notifications'
  ) THEN
    CREATE POLICY "Users can delete own notifications"
      ON notifications FOR DELETE USING (auth.uid() = user_id);
  END IF;
END $$;

-- Service role full access
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Service role full access notifications'
  ) THEN
    CREATE POLICY "Service role full access notifications"
      ON notifications FOR ALL USING (auth.role() = 'service_role');
  END IF;
END $$;

-- ── RPC: Batch mark as read ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION mark_all_notifications_read(
  p_user_id UUID,
  p_category TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  affected INTEGER;
BEGIN
  IF p_category IS NULL THEN
    UPDATE notifications
    SET read = true
    WHERE user_id = p_user_id AND read = false AND deleted_at IS NULL;
  ELSE
    UPDATE notifications
    SET read = true
    WHERE user_id = p_user_id AND read = false AND category = p_category AND deleted_at IS NULL;
  END IF;
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── RPC: Batch soft delete ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION soft_delete_all_notifications(
  p_user_id UUID,
  p_category TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  affected INTEGER;
BEGIN
  IF p_category IS NULL THEN
    UPDATE notifications
    SET deleted_at = NOW()
    WHERE user_id = p_user_id AND deleted_at IS NULL;
  ELSE
    UPDATE notifications
    SET deleted_at = NOW()
    WHERE user_id = p_user_id AND category = p_category AND deleted_at IS NULL;
  END IF;
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── RPC: Get notification counts per category ────────────────────────

CREATE OR REPLACE FUNCTION get_notification_counts(p_user_id UUID)
RETURNS JSON AS $$
  SELECT json_build_object(
    'total',         COUNT(*) FILTER (WHERE read = false),
    'message',       COUNT(*) FILTER (WHERE read = false AND category = 'message'),
    'interaction',   COUNT(*) FILTER (WHERE read = false AND category = 'interaction'),
    'trust_rating',  COUNT(*) FILTER (WHERE read = false AND category = 'trust_rating'),
    'post_nearby',   COUNT(*) FILTER (WHERE read = false AND category = 'post_nearby'),
    'post_response', COUNT(*) FILTER (WHERE read = false AND category = 'post_response'),
    'system',        COUNT(*) FILTER (WHERE read = false AND category IN ('system','bot','welcome','reminder','mention'))
  )
  FROM notifications
  WHERE user_id = p_user_id AND deleted_at IS NULL;
$$ LANGUAGE sql SECURITY DEFINER;

-- ── Trigger: Nearby-post notifications ───────────────────────────────

CREATE OR REPLACE FUNCTION notify_nearby_users_on_new_post()
RETURNS TRIGGER AS $$
BEGIN
  -- Nur für aktive Posts mit Koordinaten
  IF NEW.status = 'active' AND NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    INSERT INTO notifications (user_id, type, category, title, content, actor_id, link, metadata)
    SELECT
      p.id,
      'post_nearby',
      'post_nearby',
      'Neuer Beitrag in deiner Nähe',
      substring(NEW.title FROM 1 FOR 100),
      NEW.user_id,
      '/dashboard/posts/' || NEW.id,
      jsonb_build_object(
        'post_id', NEW.id,
        'category', NEW.category,
        'distance_km', round(
          (6371 * acos(
            LEAST(1.0, GREATEST(-1.0,
              cos(radians(p.latitude)) * cos(radians(NEW.latitude))
              * cos(radians(NEW.longitude) - radians(p.longitude))
              + sin(radians(p.latitude)) * sin(radians(NEW.latitude))
            ))
          ))::numeric, 1
        )
      )
    FROM profiles p
    WHERE p.id != NEW.user_id
      AND p.latitude IS NOT NULL
      AND p.longitude IS NOT NULL
      AND p.notify_nearby_posts = true
      AND (6371 * acos(
        LEAST(1.0, GREATEST(-1.0,
          cos(radians(p.latitude)) * cos(radians(NEW.latitude))
          * cos(radians(NEW.longitude) - radians(p.longitude))
          + sin(radians(p.latitude)) * sin(radians(NEW.latitude))
        ))
      )) <= COALESCE(p.notification_radius_km, 10)
      -- Rate limit: max 1 nearby notification per user per hour
      AND NOT EXISTS (
        SELECT 1 FROM notifications n
        WHERE n.user_id = p.id
          AND n.category = 'post_nearby'
          AND n.created_at > NOW() - INTERVAL '1 hour'
      );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger only if posts table exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'posts'
  ) THEN
    DROP TRIGGER IF EXISTS trigger_notify_nearby_on_post ON public.posts;
    CREATE TRIGGER trigger_notify_nearby_on_post
      AFTER INSERT ON posts
      FOR EACH ROW
      EXECUTE FUNCTION notify_nearby_users_on_new_post();
  END IF;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════
-- DONE
-- ═══════════════════════════════════════════════════════════════════════
