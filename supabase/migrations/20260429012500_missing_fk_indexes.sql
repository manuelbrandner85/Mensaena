-- Cover unindexed foreign keys to remove sequential-scan hotspots.
-- These were flagged by Supabase performance advisor.

CREATE INDEX IF NOT EXISTS idx_dm_calls_caller_id            ON public.dm_calls(caller_id);
CREATE INDEX IF NOT EXISTS idx_group_post_reactions_post_id  ON public.group_post_reactions(post_id);
CREATE INDEX IF NOT EXISTS idx_group_post_reactions_user_id  ON public.group_post_reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_channel_polls_channel_id      ON public.channel_polls(channel_id);
CREATE INDEX IF NOT EXISTS idx_poll_votes_poll_id            ON public.poll_votes(poll_id);
CREATE INDEX IF NOT EXISTS idx_poll_votes_user_id            ON public.poll_votes(user_id);
CREATE INDEX IF NOT EXISTS idx_channel_events_channel_id     ON public.channel_events(channel_id);
CREATE INDEX IF NOT EXISTS idx_event_rsvps_event_id          ON public.event_rsvps(event_id);
CREATE INDEX IF NOT EXISTS idx_event_rsvps_user_id           ON public.event_rsvps(user_id);
