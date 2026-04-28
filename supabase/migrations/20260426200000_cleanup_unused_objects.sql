-- ═══════════════════════════════════════════════════════════════════════════
-- Cleanup: Ungenutzte Datenbankobjekte entfernen
--
-- Entfernt Tabellen, Views und Trigger die im Anwendungscode nicht mehr
-- referenziert werden. Alle Operationen sind idempotent (IF EXISTS).
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Ungenutzte Views ───────────────────────────────────────────────────
-- Code greift direkt auf post_comments/post_votes/post_shares/posts zu.

DROP VIEW IF EXISTS public.v_post_comment_counts;
DROP VIEW IF EXISTS public.v_post_vote_scores;
DROP VIEW IF EXISTS public.v_post_share_counts;
DROP VIEW IF EXISTS public.v_active_posts;

-- ── 2. Orphan Trigger (auf Tabellen die nie erstellt wurden) ──────────────
-- Diese Trigger wurden in 20260425120000 mit IF EXISTS-Guard angelegt,
-- existieren daher nur wenn die jeweilige Tabelle vorhanden ist.
-- DROP IF EXISTS ist sicher falls sie doch irgendwie angelegt wurden.

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'group_invitations') THEN
    DROP TRIGGER IF EXISTS trg_notify_on_new_group_invitation ON public.group_invitations;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'marketplace_messages') THEN
    DROP TRIGGER IF EXISTS trg_notify_on_marketplace_message ON public.marketplace_messages;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'group_post_comments') THEN
    DROP TRIGGER IF EXISTS trg_notify_on_group_post_comment ON public.group_post_comments;
  END IF;
END $$;

-- ── 3. Ungenutzte Tabellen ────────────────────────────────────────────────

-- crisis_reports: ersetzt durch public.crises
DROP TABLE IF EXISTS public.crisis_reports CASCADE;

-- skill_offers: ersetzt durch posts mit category='skills'
DROP TABLE IF EXISTS public.skill_offers CASCADE;

-- post_tags: Tags werden als JSONB-Spalte in posts gespeichert
DROP TABLE IF EXISTS public.post_tags CASCADE;

-- regions: ersetzt durch Koordinaten-basiertes Geo-Matching
DROP TABLE IF EXISTS public.regions CASCADE;

-- email_bounces: nicht in die Anwendung integriert
DROP TABLE IF EXISTS public.email_bounces CASCADE;
