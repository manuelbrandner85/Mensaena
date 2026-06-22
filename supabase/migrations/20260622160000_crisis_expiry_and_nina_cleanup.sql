-- Krisen-Ablauf + NINA-Aufräumen.
-- Problem: import-nina-warnings legt BBK/NINA-Warnungen als crises an
-- (creator_id IS NULL, contact_name='BBK'); nichts entfernt sie je →
-- alte Meldungen häufen sich an. Nutzer-Krisen haben keine Ablauf-Logik.

-- 1) Alle bestehenden NINA/BBK-Krisen SOFORT entfernen ("entferne alle").
DELETE FROM public.crises
  WHERE creator_id IS NULL AND contact_name = 'BBK';

-- 2) Alte, nicht aktualisierte Nutzer-Krisen sofort auflösen (verschwinden).
UPDATE public.crises
  SET status = 'resolved', resolved_at = now()
  WHERE resolved_at IS NULL AND status <> 'resolved'
    AND COALESCE(updated_at, created_at) < now() - interval '7 days';

-- 3) Wiederkehrendes Aufräumen.
CREATE OR REPLACE FUNCTION public.cleanup_expired_crises() RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  -- NINA/BBK: höchstens 24h ab letzter Aktualisierung. Solange die Warnung im
  -- NINA-Feed bleibt, frischt der Importer updated_at auf → sie überlebt.
  DELETE FROM public.crises
    WHERE creator_id IS NULL AND contact_name = 'BBK'
      AND COALESCE(updated_at, created_at) < now() - interval '24 hours';
  -- Nutzer-Krisen: nach 7 Tagen ohne Update als resolved markieren.
  UPDATE public.crises
    SET status = 'resolved', resolved_at = now()
    WHERE resolved_at IS NULL AND status <> 'resolved'
      AND creator_id IS NOT NULL
      AND COALESCE(updated_at, created_at) < now() - interval '7 days';
$$;

-- pg_cron: alle 30 Minuten (idempotent — schedule upsertet per Job-Name).
SELECT cron.schedule(
  'cleanup-expired-crises',
  '*/30 * * * *',
  $$SELECT public.cleanup_expired_crises();$$
);
