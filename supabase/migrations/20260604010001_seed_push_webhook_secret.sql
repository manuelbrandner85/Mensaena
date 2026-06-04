-- ═══════════════════════════════════════════════════════════════════════════
-- SECURITY-FIX B2 (Teil 2): push_webhook_secret garantieren
--
-- send-push erzwingt ab jetzt das Webhook-Secret (sonst 503/401). Damit der
-- legitime Notification-Trigger weiter durchkommt, MUSS push_webhook_secret in
-- private.push_config gesetzt sein.
--
-- Eleganz: BEIDE Seiten (der notify_push-Trigger UND die send-push Edge-
-- Function via get_push_config) lesen denselben Wert aus push_config. Wir
-- generieren ihn ZUFÄLLIG pro DB — er steht damit NICHT im Repo und beide
-- Seiten stimmen trotzdem automatisch überein. Idempotent: nur setzen wenn
-- noch nicht vorhanden/leer.
-- ═══════════════════════════════════════════════════════════════════════════

INSERT INTO private.push_config (key, value)
VALUES (
  'push_webhook_secret',
  replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')
)
ON CONFLICT (key) DO UPDATE
  SET value = EXCLUDED.value
  WHERE private.push_config.value IS NULL OR private.push_config.value = '';
