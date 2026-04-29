-- Tighten RLS on channel_events / channel_polls / event_rsvps / poll_votes.
--
-- Previous policies allowed any authenticated user to insert/delete with no
-- guard that the target channel actually exists. We add an EXISTS check on
-- chat_channels (which is itself protected by channels_read for SELECT) and
-- restrict deletion to the creator or an admin.
--
-- Note: chat_channels currently has no `is_public` column. Channels are
-- effectively public to all authenticated users via the existing channels_read
-- policy. We therefore only require the channel to exist, plus the standard
-- "auth.uid() = created_by/user_id" check.

-- ── channel_events ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "members can create events" ON public.channel_events;
CREATE POLICY "channel_events_insert" ON public.channel_events
  FOR INSERT WITH CHECK (
    auth.uid() = created_by
    AND EXISTS (SELECT 1 FROM public.chat_channels c WHERE c.id = channel_events.channel_id)
  );

DROP POLICY IF EXISTS "admin can delete events" ON public.channel_events;
CREATE POLICY "channel_events_delete" ON public.channel_events
  FOR DELETE USING (
    auth.uid() = created_by
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- ── channel_polls ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "members can create polls" ON public.channel_polls;
CREATE POLICY "channel_polls_insert" ON public.channel_polls
  FOR INSERT WITH CHECK (
    auth.uid() = created_by
    AND EXISTS (SELECT 1 FROM public.chat_channels c WHERE c.id = channel_polls.channel_id)
  );

-- Allow poll creators (and admins) to delete their own polls.
DROP POLICY IF EXISTS "channel_polls_delete" ON public.channel_polls;
CREATE POLICY "channel_polls_delete" ON public.channel_polls
  FOR DELETE USING (
    auth.uid() = created_by
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- ── event_rsvps ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "members can rsvp" ON public.event_rsvps;
CREATE POLICY "event_rsvps_insert" ON public.event_rsvps
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM public.channel_events e WHERE e.id = event_rsvps.event_id)
  );

DROP POLICY IF EXISTS "members can un-rsvp" ON public.event_rsvps;
CREATE POLICY "event_rsvps_delete" ON public.event_rsvps
  FOR DELETE USING (
    auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- ── poll_votes ────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "members can vote" ON public.poll_votes;
CREATE POLICY "poll_votes_insert" ON public.poll_votes
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM public.channel_polls p WHERE p.id = poll_votes.poll_id)
  );

DROP POLICY IF EXISTS "members can change vote" ON public.poll_votes;
CREATE POLICY "poll_votes_delete" ON public.poll_votes
  FOR DELETE USING (
    auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );
