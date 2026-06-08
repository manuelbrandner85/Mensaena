-- ════════════════════════════════════════════════════════════════════════
-- Godmode Admin-Benachrichtigungen
--
-- Bei wichtigen Godmode-Events bekommen NUR Admins (profiles.role='admin')
-- eine interne Notification + (über den bestehenden Push-Trigger) eine
-- FCM-Push. Es wird pro Admin genau eine notifications-Zeile geschrieben —
-- da nur für Admins Zeilen entstehen, erhalten ausschließlich Admins die
-- Benachrichtigung.
--
-- Benachrichtigte Events (vom Admin gewählt):
--   • Agent-Auftrag: PR erstellt / wartet auf Review (pr_open, awaiting_review)
--   • Agent-Auftrag: Änderung live (merged)
--   • Agent-Auftrag: fehlgeschlagen (failed)        → priority=high
--   • Deep-Scan fertig MIT neuen Vorschlägen (found > 0)
--   • Modul-Scan fertig MIT neuen Insights (insights_count > 0)
--   • Scan fehlgeschlagen (failed)                   → priority=high
--
-- Bewusst NICHT: queued/running/no_changes/cancelled und Scans ohne Treffer
-- (vermeidet Push-Spam, v.a. beim 30-Min-Cron-Scan).
--
-- Die Notifications nutzen category='system' + type='system'. Sie fließen
-- durch die bestehende Push-Pipeline (trigger_push_on_notification → send-push).
-- Idempotent: CREATE OR REPLACE + DROP TRIGGER IF EXISTS.
-- ════════════════════════════════════════════════════════════════════════

-- ── 1. Agent-Aufträge (admin_dev_tasks) ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_admins_godmode_task()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_title text;
  v_body  text;
  v_prio  text := 'normal';
BEGIN
  -- Nur bei echtem Status-Wechsel.
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  IF NEW.status = 'awaiting_review' THEN
    v_title := '🤖 Godmode: Auftrag wartet auf Review';
    v_body  := 'Bitte prüfen: ' || COALESCE(NEW.summary, NEW.instruction);
  ELSIF NEW.status = 'pr_open' THEN
    v_title := '🤖 Godmode: Auftrag fertig (PR erstellt)';
    v_body  := COALESCE(NEW.summary, NEW.instruction);
  ELSIF NEW.status = 'merged' THEN
    v_title := '✅ Godmode: Änderung ist live';
    v_body  := 'Gemerged und wird ausgeliefert: ' || COALESCE(NEW.summary, NEW.instruction);
  ELSIF NEW.status = 'failed' THEN
    v_title := '⚠️ Godmode: Auftrag fehlgeschlagen';
    v_body  := COALESCE(NEW.error, NEW.instruction);
    v_prio  := 'high';
  ELSE
    RETURN NEW;  -- queued/running/no_changes/cancelled → keine Benachrichtigung
  END IF;

  INSERT INTO public.notifications
    (user_id, type, category, title, content, link, priority, metadata)
  SELECT
    p.id, 'system', 'system', v_title, LEFT(COALESCE(v_body, ''), 500),
    '/dashboard/admin/dev-agent', v_prio,
    jsonb_build_object(
      'kind', 'godmode_task',
      'task_id', NEW.id,
      'status', NEW.status,
      'pr_url', NEW.pr_url
    )
  FROM public.profiles p
  WHERE p.role = 'admin';

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_admins_godmode_task ON public.admin_dev_tasks;
CREATE TRIGGER trg_notify_admins_godmode_task
  AFTER UPDATE OF status ON public.admin_dev_tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admins_godmode_task();


-- ── 2. Deep-Scan / Tiefenanalyse (admin_scan_runs) ──────────────────────
CREATE OR REPLACE FUNCTION public.notify_admins_godmode_deep_scan()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_title text;
  v_body  text;
  v_prio  text := 'normal';
  v_found int  := COALESCE(NEW.found, 0);
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  IF NEW.status = 'done' AND v_found > 0 THEN
    v_title := '🔎 Godmode: ' || v_found || ' neue Vorschläge';
    v_body  := 'Die Tiefenanalyse hat ' || v_found || ' neue Vorschläge gefunden.';
  ELSIF NEW.status = 'failed' THEN
    v_title := '⚠️ Godmode: Tiefenanalyse fehlgeschlagen';
    v_body  := COALESCE(NEW.error, 'Der Scan ist fehlgeschlagen.');
    v_prio  := 'high';
  ELSE
    RETURN NEW;  -- done ohne Treffer, running, queued → keine Benachrichtigung
  END IF;

  INSERT INTO public.notifications
    (user_id, type, category, title, content, link, priority, metadata)
  SELECT
    p.id, 'system', 'system', v_title, LEFT(v_body, 500),
    '/dashboard/admin/dev-agent', v_prio,
    jsonb_build_object(
      'kind', 'godmode_deep_scan',
      'scan_id', NEW.id,
      'status', NEW.status,
      'found', v_found
    )
  FROM public.profiles p
  WHERE p.role = 'admin';

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_admins_godmode_deep_scan ON public.admin_scan_runs;
CREATE TRIGGER trg_notify_admins_godmode_deep_scan
  AFTER UPDATE OF status ON public.admin_scan_runs
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admins_godmode_deep_scan();


-- ── 3. Modul-Intelligenz-Scan (admin_module_scan_runs) ──────────────────
CREATE OR REPLACE FUNCTION public.notify_admins_godmode_module_scan()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_title text;
  v_body  text;
  v_prio  text := 'normal';
  v_count int  := COALESCE(NEW.insights_count, 0);
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  IF NEW.status = 'done' AND v_count > 0 THEN
    v_title := '🧠 Godmode: ' || v_count || ' neue Modul-Insights';
    v_body  := 'Die Modul-Intelligenz hat ' || v_count || ' neue Erkenntnisse gefunden.';
  ELSIF NEW.status = 'failed' THEN
    v_title := '⚠️ Godmode: Modul-Scan fehlgeschlagen';
    v_body  := COALESCE(NEW.error, 'Der Modul-Scan ist fehlgeschlagen.');
    v_prio  := 'high';
  ELSE
    RETURN NEW;  -- done ohne Treffer, running, queued → keine Benachrichtigung
  END IF;

  INSERT INTO public.notifications
    (user_id, type, category, title, content, link, priority, metadata)
  SELECT
    p.id, 'system', 'system', v_title, LEFT(v_body, 500),
    '/dashboard/admin/dev-agent', v_prio,
    jsonb_build_object(
      'kind', 'godmode_module_scan',
      'scan_id', NEW.id,
      'status', NEW.status,
      'insights_count', v_count
    )
  FROM public.profiles p
  WHERE p.role = 'admin';

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_admins_godmode_module_scan ON public.admin_module_scan_runs;
CREATE TRIGGER trg_notify_admins_godmode_module_scan
  AFTER UPDATE OF status ON public.admin_module_scan_runs
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admins_godmode_module_scan();
