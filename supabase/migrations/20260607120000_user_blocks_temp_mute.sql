-- ═══════════════════════════════════════════════════════════════════════════
-- Temp-Mute: zeitlich begrenzte Blockierung (läuft automatisch aus)
--
-- Bisher war eine Blockierung immer DAUERHAFT. Als sanftere Alternative kann
-- ein Nutzer jemanden jetzt für eine begrenzte Zeit (Standard 24 h) stumm-
-- schalten — danach verschwindet die Wirkung automatisch, ohne dass jemand
-- den Block manuell aufheben muss.
--
-- Datenmodell: neue Spalte `expires_at`.
--   • expires_at IS NULL          → dauerhafter Block (Bestandsverhalten)
--   • expires_at > now()          → aktiver Temp-Mute
--   • expires_at <= now()         → abgelaufen, wird ignoriert (Soft-Delete)
--
-- Additiv + idempotent: ADD COLUMN IF NOT EXISTS, CREATE OR REPLACE. Bestehende
-- Zeilen (expires_at = NULL) bleiben dauerhafte Blocks. Web-Abfragen, die nur
-- blocker_id/blocked_id selektieren, bleiben unberührt (neue Spalte ist nullbar).
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF to_regclass('public.user_blocks') IS NOT NULL THEN
    ALTER TABLE public.user_blocks
      ADD COLUMN IF NOT EXISTS expires_at timestamptz;
  END IF;
END $$;

-- Bidirektionaler Feed-Filter: abgelaufene Temp-Mutes NICHT mehr ausblenden.
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
     AND (expires_at IS NULL OR expires_at > now())
  UNION
  SELECT blocker_id AS user_id
    FROM public.user_blocks
   WHERE blocked_id = auth.uid()
     AND (expires_at IS NULL OR expires_at > now());
$$;

GRANT EXECUTE ON FUNCTION public.my_block_filter_ids() TO authenticated;
