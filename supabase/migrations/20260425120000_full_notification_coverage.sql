-- ═══════════════════════════════════════════════════════════════════════════
-- Vollständige Notification-Coverage
--
-- Fügt Trigger für alle übrigen Module hinzu, damit User für jeden
-- relevanten Event einen Push bekommen. Jeder Trigger wird nur installiert
-- wenn die zugehörige Tabelle existiert (idempotent).
--
--   1. thanks                  → Empfänger eines Dankes
--   2. group_invitations        → Eingeladener User
--   3. marketplace_messages     → Listings-Owner
--   4. post_reactions           → Post-Author
--   5. group_posts              → alle Group-Members außer Autor
--   6. group_post_comments      → Post-Autor
--   7. post_shares              → Post-Author
-- ═══════════════════════════════════════════════════════════════════════════


-- ── 1. THANKS (falls Tabelle existiert) ─────────────────────────────────
DO $outer$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'thanks') THEN

    CREATE OR REPLACE FUNCTION public.notify_on_new_thanks()
    RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
    DECLARE v_from_name text; v_body text;
    BEGIN
      IF NEW.to_user_id IS NULL OR NEW.to_user_id = NEW.from_user_id THEN RETURN NEW; END IF;
      SELECT COALESCE(name, 'Jemand') INTO v_from_name FROM public.profiles WHERE id = NEW.from_user_id;
      v_body := v_from_name || ' sagt ' || NEW.emoji
        || CASE WHEN NEW.message IS NOT NULL AND length(trim(NEW.message)) > 0
                THEN ': "' || substring(trim(NEW.message) FROM 1 FOR 100) || '"' ELSE '' END;
      INSERT INTO public.notifications (user_id, type, category, title, content, link, actor_id, metadata)
      VALUES (NEW.to_user_id, 'system', 'thanks',
        'Du hast ein Danke bekommen ' || NEW.emoji, v_body,
        CASE WHEN NEW.post_id IS NOT NULL THEN '/dashboard/posts/' || NEW.post_id::text ELSE '/dashboard/profile' END,
        NEW.from_user_id,
        jsonb_build_object('thanks_id', NEW.id, 'post_id', NEW.post_id, 'emoji', NEW.emoji));
      RETURN NEW;
    EXCEPTION WHEN OTHERS THEN RAISE WARNING 'notify_on_new_thanks: %', SQLERRM; RETURN NEW; END;
    $f$;

    DROP TRIGGER IF EXISTS trg_notify_on_new_thanks ON public.thanks;
    CREATE TRIGGER trg_notify_on_new_thanks
      AFTER INSERT ON public.thanks
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_thanks();
  END IF;
END $outer$;


-- ── 2. GROUP INVITATIONS ────────────────────────────────────────────────
DO $outer$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'group_invitations') THEN

    CREATE OR REPLACE FUNCTION public.notify_on_new_group_invitation()
    RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
    DECLARE v_inviter_name text; v_group_name text;
    BEGIN
      IF NEW.invited_user_id IS NULL OR NEW.invited_user_id = NEW.invited_by THEN RETURN NEW; END IF;
      SELECT COALESCE(name, 'Jemand') INTO v_inviter_name FROM public.profiles WHERE id = NEW.invited_by;
      BEGIN
        SELECT COALESCE(name, 'eine Gruppe') INTO v_group_name FROM public.groups WHERE id = NEW.group_id;
      EXCEPTION WHEN OTHERS THEN v_group_name := 'eine Gruppe'; END;
      INSERT INTO public.notifications (user_id, type, category, title, content, link, actor_id, metadata)
      VALUES (NEW.invited_user_id, 'system', 'system',
        'Einladung zu ' || COALESCE(v_group_name, 'einer Gruppe'),
        v_inviter_name || ' hat dich zu ' || COALESCE(v_group_name, 'einer Gruppe') || ' eingeladen',
        '/dashboard/groups/' || NEW.group_id::text, NEW.invited_by,
        jsonb_build_object('invitation_id', NEW.id, 'group_id', NEW.group_id));
      RETURN NEW;
    EXCEPTION WHEN OTHERS THEN RAISE WARNING 'notify_on_new_group_invitation: %', SQLERRM; RETURN NEW; END;
    $f$;

    DROP TRIGGER IF EXISTS trg_notify_on_new_group_invitation ON public.group_invitations;
    CREATE TRIGGER trg_notify_on_new_group_invitation
      AFTER INSERT ON public.group_invitations
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_group_invitation();
  END IF;
END $outer$;


-- ── 3. MARKETPLACE MESSAGES ─────────────────────────────────────────────
DO $outer$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'marketplace_messages') THEN

    CREATE OR REPLACE FUNCTION public.notify_on_marketplace_message()
    RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
    DECLARE v_sender_name text; v_listing_title text; v_preview text;
    BEGIN
      IF NEW.receiver_id IS NULL OR NEW.receiver_id = NEW.sender_id THEN RETURN NEW; END IF;
      IF NEW.content IS NULL OR length(trim(NEW.content)) = 0 THEN RETURN NEW; END IF;
      SELECT COALESCE(name, 'Jemand') INTO v_sender_name FROM public.profiles WHERE id = NEW.sender_id;
      SELECT title INTO v_listing_title FROM public.marketplace_listings WHERE id = NEW.listing_id;
      v_preview := substring(trim(NEW.content) FROM 1 FOR 140);
      IF length(NEW.content) > 140 THEN v_preview := v_preview || '…'; END IF;
      INSERT INTO public.notifications (user_id, type, category, title, content, link, actor_id, metadata)
      VALUES (NEW.receiver_id, 'message', 'message',
        v_sender_name || CASE WHEN v_listing_title IS NOT NULL
                              THEN ' (zu „' || LEFT(v_listing_title, 40) || '")' ELSE '' END,
        v_preview, '/dashboard/marketplace/' || NEW.listing_id::text, NEW.sender_id,
        jsonb_build_object('marketplace_message_id', NEW.id, 'listing_id', NEW.listing_id));
      RETURN NEW;
    EXCEPTION WHEN OTHERS THEN RAISE WARNING 'notify_on_marketplace_message: %', SQLERRM; RETURN NEW; END;
    $f$;

    DROP TRIGGER IF EXISTS trg_notify_on_marketplace_message ON public.marketplace_messages;
    CREATE TRIGGER trg_notify_on_marketplace_message
      AFTER INSERT ON public.marketplace_messages
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_marketplace_message();
  END IF;
END $outer$;


-- ── 4. POST REACTIONS ──────────────────────────────────────────────────
DO $outer$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'post_reactions') THEN

    CREATE OR REPLACE FUNCTION public.notify_on_post_reaction()
    RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
    DECLARE v_reactor_name text; v_post_owner uuid; v_post_title text; v_emoji text;
    BEGIN
      SELECT user_id, title INTO v_post_owner, v_post_title FROM public.posts WHERE id = NEW.post_id;
      IF v_post_owner IS NULL OR v_post_owner = NEW.user_id THEN RETURN NEW; END IF;
      SELECT COALESCE(name, 'Jemand') INTO v_reactor_name FROM public.profiles WHERE id = NEW.user_id;
      v_emoji := CASE NEW.reaction_type
        WHEN 'like' THEN '👍' WHEN 'heart' THEN '❤️' WHEN 'love' THEN '❤️'
        WHEN 'fire' THEN '🔥' WHEN 'thanks' THEN '🙏' WHEN 'clap' THEN '👏'
        WHEN 'wow' THEN '😮' WHEN 'haha' THEN '😄' WHEN 'sad' THEN '😢'
        ELSE '👍' END;
      INSERT INTO public.notifications (user_id, type, category, title, content, link, actor_id, metadata)
      VALUES (v_post_owner, 'system', 'comment',
        v_emoji || ' ' || v_reactor_name,
        'reagierte auf "' || COALESCE(LEFT(v_post_title, 50), 'deinen Beitrag') || '"',
        '/dashboard/posts/' || NEW.post_id::text, NEW.user_id,
        jsonb_build_object('post_id', NEW.post_id, 'reaction_type', NEW.reaction_type));
      RETURN NEW;
    EXCEPTION WHEN OTHERS THEN RAISE WARNING 'notify_on_post_reaction: %', SQLERRM; RETURN NEW; END;
    $f$;

    DROP TRIGGER IF EXISTS trg_notify_on_post_reaction ON public.post_reactions;
    CREATE TRIGGER trg_notify_on_post_reaction
      AFTER INSERT ON public.post_reactions
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_post_reaction();
  END IF;
END $outer$;


-- ── 5. GROUP POSTS ──────────────────────────────────────────────────────
DO $outer$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'group_posts') THEN

    CREATE OR REPLACE FUNCTION public.notify_on_new_group_post()
    RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
    DECLARE v_author_name text; v_group_name text; v_preview text;
    BEGIN
      IF NEW.content IS NULL OR length(trim(NEW.content)) = 0 THEN RETURN NEW; END IF;
      SELECT COALESCE(name, 'Jemand') INTO v_author_name FROM public.profiles WHERE id = NEW.user_id;
      BEGIN
        SELECT COALESCE(name, 'die Gruppe') INTO v_group_name FROM public.groups WHERE id = NEW.group_id;
      EXCEPTION WHEN OTHERS THEN v_group_name := 'die Gruppe'; END;
      v_preview := substring(trim(NEW.content) FROM 1 FOR 140);
      IF length(NEW.content) > 140 THEN v_preview := v_preview || '…'; END IF;
      INSERT INTO public.notifications (user_id, type, category, title, content, link, actor_id, metadata)
      SELECT gm.user_id, 'system', 'comment',
        v_author_name || ' in ' || COALESCE(v_group_name, 'der Gruppe'), v_preview,
        '/dashboard/groups/' || NEW.group_id::text, NEW.user_id,
        jsonb_build_object('group_post_id', NEW.id, 'group_id', NEW.group_id)
      FROM public.group_members gm
      WHERE gm.group_id = NEW.group_id AND gm.user_id <> NEW.user_id;
      RETURN NEW;
    EXCEPTION WHEN OTHERS THEN RAISE WARNING 'notify_on_new_group_post: %', SQLERRM; RETURN NEW; END;
    $f$;

    DROP TRIGGER IF EXISTS trg_notify_on_new_group_post ON public.group_posts;
    CREATE TRIGGER trg_notify_on_new_group_post
      AFTER INSERT ON public.group_posts
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_group_post();
  END IF;
END $outer$;


-- ── 6. GROUP POST COMMENTS ──────────────────────────────────────────────
DO $outer$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'group_post_comments') THEN

    CREATE OR REPLACE FUNCTION public.notify_on_group_post_comment()
    RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
    DECLARE v_commenter_name text; v_post_owner uuid; v_preview text;
    BEGIN
      IF NEW.content IS NULL OR length(trim(NEW.content)) = 0 THEN RETURN NEW; END IF;
      SELECT user_id INTO v_post_owner FROM public.group_posts WHERE id = NEW.post_id;
      IF v_post_owner IS NULL OR v_post_owner = NEW.user_id THEN RETURN NEW; END IF;
      SELECT COALESCE(name, 'Jemand') INTO v_commenter_name FROM public.profiles WHERE id = NEW.user_id;
      v_preview := substring(trim(NEW.content) FROM 1 FOR 140);
      IF length(NEW.content) > 140 THEN v_preview := v_preview || '…'; END IF;
      INSERT INTO public.notifications (user_id, type, category, title, content, link, actor_id, metadata)
      VALUES (v_post_owner, 'system', 'comment',
        v_commenter_name || ' hat kommentiert', v_preview,
        '/dashboard/groups', NEW.user_id,
        jsonb_build_object('comment_id', NEW.id, 'group_post_id', NEW.post_id));
      RETURN NEW;
    EXCEPTION WHEN OTHERS THEN RAISE WARNING 'notify_on_group_post_comment: %', SQLERRM; RETURN NEW; END;
    $f$;

    DROP TRIGGER IF EXISTS trg_notify_on_group_post_comment ON public.group_post_comments;
    CREATE TRIGGER trg_notify_on_group_post_comment
      AFTER INSERT ON public.group_post_comments
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_group_post_comment();
  END IF;
END $outer$;


-- ── 7. POST SHARES ──────────────────────────────────────────────────────
DO $outer$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'post_shares') THEN

    CREATE OR REPLACE FUNCTION public.notify_on_post_share()
    RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
    DECLARE v_sharer_name text; v_post_owner uuid; v_post_title text;
    BEGIN
      SELECT user_id, title INTO v_post_owner, v_post_title FROM public.posts WHERE id = NEW.post_id;
      IF v_post_owner IS NULL OR v_post_owner = NEW.user_id THEN RETURN NEW; END IF;
      SELECT COALESCE(name, 'Jemand') INTO v_sharer_name FROM public.profiles WHERE id = NEW.user_id;
      INSERT INTO public.notifications (user_id, type, category, title, content, link, actor_id, metadata)
      VALUES (v_post_owner, 'system', 'comment',
        v_sharer_name || ' hat geteilt',
        '"' || COALESCE(LEFT(v_post_title, 50), 'dein Beitrag') || '" wurde geteilt',
        '/dashboard/posts/' || NEW.post_id::text, NEW.user_id,
        jsonb_build_object('share_id', NEW.id, 'post_id', NEW.post_id));
      RETURN NEW;
    EXCEPTION WHEN OTHERS THEN RAISE WARNING 'notify_on_post_share: %', SQLERRM; RETURN NEW; END;
    $f$;

    DROP TRIGGER IF EXISTS trg_notify_on_post_share ON public.post_shares;
    CREATE TRIGGER trg_notify_on_post_share
      AFTER INSERT ON public.post_shares
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_post_share();
  END IF;
END $outer$;


-- Verifikation: welche Trigger sind installiert?
SELECT count(*) AS new_triggers_installed
FROM pg_trigger
WHERE NOT tgisinternal
  AND tgname IN (
    'trg_notify_on_new_thanks',
    'trg_notify_on_new_group_invitation',
    'trg_notify_on_marketplace_message',
    'trg_notify_on_post_reaction',
    'trg_notify_on_new_group_post',
    'trg_notify_on_group_post_comment',
    'trg_notify_on_post_share'
  );
