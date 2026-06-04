-- ═══════════════════════════════════════════════════════════════════════════
-- FIX H2: Bidirektionaler Block für Feed-Filter
--
-- Bisher filterte der Client nur User raus, die ER selbst blockiert hat
-- (myBlockedIds → blocker_id = me). User die MICH blockiert haben, sahen
-- meine Beiträge/Aktivität weiter → Harassment-Eskalation/Stalking.
--
-- RLS auf user_blocks lässt absichtlich NICHT zu, "wer hat mich blockiert"
-- direkt zu lesen (sonst könnte man Blocker enumerieren). Deshalb eine
-- SECURITY-DEFINER-RPC, die die VEREINIGUNG zurückgibt:
--   { User die ich blockiert habe } ∪ { User die mich blockiert haben }
-- Der Client bekommt nur die ID-Liste zum Ausblenden — NICHT die Info,
-- wer in welche Richtung blockiert hat. Privacy bleibt gewahrt.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.my_block_filter_ids()
RETURNS TABLE (user_id uuid)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT blocked_id AS user_id
    FROM public.user_blocks
   WHERE blocker_id = auth.uid()
  UNION
  SELECT blocker_id AS user_id
    FROM public.user_blocks
   WHERE blocked_id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.my_block_filter_ids() TO authenticated;
