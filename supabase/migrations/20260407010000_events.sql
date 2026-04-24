-- =====================================================================
-- Mensaena: Events (Veranstaltungen) Feature
-- Migration: 20260407_events.sql
-- =====================================================================

-- ── handle_updated_at trigger function (reuse if exists) ─────────────
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ══════════════════════════════════════════════════════════════════════
-- 1. EVENTS TABLE
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL CHECK (char_length(title) BETWEEN 3 AND 100),
  description TEXT CHECK (char_length(description) <= 2000),
  category TEXT NOT NULL DEFAULT 'meetup'
    CHECK (category IN ('meetup','workshop','sport','food','market','culture','kids','seniors','cleanup','other')),
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ,
  is_all_day BOOLEAN DEFAULT false,
  location_name TEXT,
  location_address TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  region_id UUID REFERENCES public.regions(id) ON DELETE SET NULL,
  image_url TEXT,
  max_attendees INTEGER,
  cost TEXT DEFAULT 'kostenlos',
  what_to_bring TEXT,
  contact_info TEXT,
  is_recurring BOOLEAN DEFAULT false,
  recurring_pattern JSONB,
  recurring_parent_id UUID REFERENCES public.events(id) ON DELETE SET NULL,
  status TEXT DEFAULT 'upcoming'
    CHECK (status IN ('upcoming','ongoing','completed','cancelled')),
  attendee_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_events_status_start ON public.events(status, start_date);
CREATE INDEX IF NOT EXISTS idx_events_category ON public.events(category) WHERE status = 'upcoming';
CREATE INDEX IF NOT EXISTS idx_events_author ON public.events(author_id);
CREATE INDEX IF NOT EXISTS idx_events_region ON public.events(region_id);
CREATE INDEX IF NOT EXISTS idx_events_start_date ON public.events(start_date);

-- RLS
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone can read active events" ON public.events
    FOR SELECT USING (status IN ('upcoming','ongoing') OR auth.uid() = author_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Authenticated users can create events" ON public.events
    FOR INSERT WITH CHECK (auth.uid() = author_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Users can update own events" ON public.events
    FOR UPDATE USING (auth.uid() = author_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Users can delete own events" ON public.events
    FOR DELETE USING (auth.uid() = author_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "service_role full access events" ON public.events
    FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- updated_at trigger
DROP TRIGGER IF EXISTS set_events_updated_at ON public.events;
CREATE TRIGGER set_events_updated_at
  BEFORE UPDATE ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ══════════════════════════════════════════════════════════════════════
-- 2. EVENT_ATTENDEES TABLE
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.event_attendees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  status TEXT DEFAULT 'going'
    CHECK (status IN ('going','interested','declined')),
  reminder_set BOOLEAN DEFAULT false,
  reminder_minutes INTEGER DEFAULT 60,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(event_id, user_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_event_attendees_event ON public.event_attendees(event_id);
CREATE INDEX IF NOT EXISTS idx_event_attendees_user ON public.event_attendees(user_id);

-- RLS
ALTER TABLE public.event_attendees ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone can read attendees" ON public.event_attendees
    FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Users can insert own attendance" ON public.event_attendees
    FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Users can update own attendance" ON public.event_attendees
    FOR UPDATE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Users can delete own attendance" ON public.event_attendees
    FOR DELETE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "service_role full access event_attendees" ON public.event_attendees
    FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ══════════════════════════════════════════════════════════════════════
-- 3. TRIGGERS: attendee_count sync
-- ══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.update_event_attendee_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    UPDATE public.events SET attendee_count = (
      SELECT COUNT(*) FROM public.event_attendees
      WHERE event_id = NEW.event_id AND status = 'going'
    ) WHERE id = NEW.event_id;
  END IF;
  IF TG_OP = 'DELETE' THEN
    UPDATE public.events SET attendee_count = (
      SELECT COUNT(*) FROM public.event_attendees
      WHERE event_id = OLD.event_id AND status = 'going'
    ) WHERE id = OLD.event_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_event_attendee_count ON public.event_attendees;
CREATE TRIGGER trigger_event_attendee_count
  AFTER INSERT OR UPDATE OR DELETE ON public.event_attendees
  FOR EACH ROW EXECUTE FUNCTION public.update_event_attendee_count();

-- ══════════════════════════════════════════════════════════════════════
-- 4. FUNCTION: auto-update event status (upcoming→ongoing→completed)
-- ══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.update_event_status()
RETURNS void AS $$
  UPDATE public.events SET status = 'ongoing'
  WHERE status = 'upcoming'
    AND start_date <= NOW()
    AND (end_date IS NULL OR end_date > NOW());

  UPDATE public.events SET status = 'completed'
  WHERE status IN ('upcoming','ongoing')
    AND (
      (end_date IS NOT NULL AND end_date < NOW()) OR
      (end_date IS NULL AND start_date + INTERVAL '3 hours' < NOW())
    );
$$ LANGUAGE sql SECURITY DEFINER;

-- ══════════════════════════════════════════════════════════════════════
-- 5. STORAGE: event-images bucket
-- ══════════════════════════════════════════════════════════════════════
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'event-images',
  'event-images',
  true,
  5242880,
  ARRAY['image/jpeg','image/png','image/webp','image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
DO $$ BEGIN
  CREATE POLICY "Anyone can view event images" ON storage.objects
    FOR SELECT USING (bucket_id = 'event-images');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Authenticated users upload event images" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'event-images' AND auth.role() = 'authenticated');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Users delete own event images" ON storage.objects
    FOR DELETE USING (bucket_id = 'event-images' AND auth.uid()::text = (storage.foldername(name))[1]);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ══════════════════════════════════════════════════════════════════════
-- 6. REALTIME
-- ══════════════════════════════════════════════════════════════════════
ALTER PUBLICATION supabase_realtime ADD TABLE public.events;
ALTER PUBLICATION supabase_realtime ADD TABLE public.event_attendees;

-- ══════════════════════════════════════════════════════════════════════
-- 7. Add scheduled_for column to notifications (for reminders)
-- ══════════════════════════════════════════════════════════════════════
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS scheduled_for TIMESTAMPTZ;
