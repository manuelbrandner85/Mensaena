-- Rate-limit bot_feedback inserts to 10 per user per rolling hour.
-- Anonymous submissions (user_id IS NULL) are not rate-limited at the row
-- level; the surrounding API endpoint handles those.

CREATE OR REPLACE FUNCTION public.check_bot_feedback_rate()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.user_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF (
    SELECT COUNT(*)
    FROM public.bot_feedback
    WHERE user_id = NEW.user_id
      AND created_at > NOW() - INTERVAL '1 hour'
  ) >= 10 THEN
    RAISE EXCEPTION 'Rate limit exceeded for bot_feedback (max 10 per hour)';
  END IF;

  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS trg_bot_feedback_rate ON public.bot_feedback;
CREATE TRIGGER trg_bot_feedback_rate
  BEFORE INSERT ON public.bot_feedback
  FOR EACH ROW
  EXECUTE FUNCTION public.check_bot_feedback_rate();

-- Index that powers the rate-limit lookup.
CREATE INDEX IF NOT EXISTS idx_bot_feedback_user_created
  ON public.bot_feedback(user_id, created_at DESC)
  WHERE user_id IS NOT NULL;
