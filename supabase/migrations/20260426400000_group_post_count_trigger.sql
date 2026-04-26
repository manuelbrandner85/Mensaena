-- ═══════════════════════════════════════════════════════════════════════════
-- groups.post_count automatisch pflegen
--
-- Analog zu trg_group_member_count (20260414030000) aber für Beiträge.
-- Ohne diesen Trigger bleibt post_count immer 0.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Trigger-Funktion ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_group_post_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.groups
    SET post_count = GREATEST(0, post_count + 1)
    WHERE id = NEW.group_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.groups
    SET post_count = GREATEST(0, post_count - 1)
    WHERE id = OLD.group_id;
  END IF;
  RETURN NULL;
END;
$$;

-- ── 2. Trigger registrieren ───────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_group_post_count ON public.group_posts;
CREATE TRIGGER trg_group_post_count
  AFTER INSERT OR DELETE ON public.group_posts
  FOR EACH ROW EXECUTE FUNCTION public.update_group_post_count();

-- ── 3. Einmalkorrektur: post_count auf aktuellen Stand bringen ────────────
UPDATE public.groups g
SET post_count = (
  SELECT COUNT(*) FROM public.group_posts gp WHERE gp.group_id = g.id
);
