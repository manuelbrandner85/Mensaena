-- Fix: 20260524100000_live_rooms.sql created live_rooms without conversation_id.
-- The subsequent 20260524130000 migration used CREATE TABLE IF NOT EXISTS (no-op)
-- then tried to index conversation_id — which fails on a fresh DB replay.
ALTER TABLE public.live_rooms
  ADD COLUMN IF NOT EXISTS conversation_id uuid
    REFERENCES public.conversations(id) ON DELETE CASCADE;
