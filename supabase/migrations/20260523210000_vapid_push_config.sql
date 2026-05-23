-- ════════════════════════════════════════════════════════════════════════
-- VAPID-Keys in push_config — Web-Push reaktivieren
--
-- Die send-push Edge-Function liest jetzt zusaetzlich VAPID-Keys aus
-- private.push_config (Felder: vapid_public_key, vapid_private_key,
-- vapid_subject). Wenn vorhanden, sendet sie Web-Push an Browser-User.
--
-- VAPID-Keys generieren (lokal, einmalig):
--   npx web-push generate-vapid-keys
--   → Public Key (Base64URL, ~88 Zeichen)
--   → Private Key (Base64URL, ~43 Zeichen)
--
-- Anschliessend in Supabase Dashboard → Database → push_config-Tabelle
-- (oder via SQL) eintragen:
--   INSERT INTO private.push_config (key, value) VALUES
--     ('vapid_public_key', '<PUBLIC>'),
--     ('vapid_private_key', '<PRIVATE>'),
--     ('vapid_subject', 'mailto:hello@mensaena.de');
-- ════════════════════════════════════════════════════════════════════════

-- Stelle sicher dass private.push_config existiert + Zeilen fuer die
-- VAPID-Keys angelegt sind (leer falls noch nicht generiert).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'private' AND table_name = 'push_config'
  ) THEN
    INSERT INTO private.push_config (key, value)
    VALUES
      ('vapid_public_key', ''),
      ('vapid_private_key', ''),
      ('vapid_subject', 'mailto:hello@mensaena.de')
    ON CONFLICT (key) DO NOTHING;
  END IF;
END $$;

COMMENT ON SCHEMA private IS
  'Server-side config (push, fcm, vapid, secrets). Read only via SECURITY DEFINER RPCs.';
