-- Kontakt-E-Mail vereinheitlichen: info@mensaena.de ist die offizielle
-- Kontaktadresse. Der VAPID-Subject (Push-Service-Kontakt, RFC 8292) zeigte
-- auf hello@mensaena.de — auf info@mensaena.de korrigieren.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'private' AND table_name = 'push_config'
  ) THEN
    UPDATE private.push_config
       SET value = 'mailto:info@mensaena.de'
     WHERE key = 'vapid_subject'
       AND value = 'mailto:hello@mensaena.de';
  END IF;
END $$;
