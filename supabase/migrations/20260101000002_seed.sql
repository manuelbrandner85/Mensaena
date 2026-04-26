-- ============================================================
-- MENSAENA – Seed Data für Entwicklung und Demo
-- ============================================================

-- Test-Nutzer werden über Supabase Auth erstellt,
-- Profile werden automatisch via Trigger angelegt.
-- Diese Seed-Daten setzen vorhandene Profile voraus.

-- Temporäre Test-Profile (UUID manuell eintragen nach Auth-Registrierung)
-- Für Demo-Zwecke: Direkt einfügen mit bekannten IDs

-- Demo Regions
INSERT INTO public.regions (name, slug, lat, lng, radius_km) VALUES
  ('München Mitte',      'muenchen-mitte',     48.1351, 11.5820, 5),
  ('München Schwabing',  'muenchen-schwabing',  48.1590, 11.5880, 4),
  ('München Maxvorstadt','muenchen-maxvorstadt',48.1490, 11.5720, 3),
  ('Berlin Mitte',       'berlin-mitte',        52.5200, 13.4050, 5),
  ('Hamburg Altona',     'hamburg-altona',      53.5500, 9.9350,  4),
  ('Köln Innenstadt',    'koeln-innenstadt',    50.9333, 6.9500,  5)
ON CONFLICT (slug) DO NOTHING;

-- Demo Posts (werden nach Nutzer-Registrierung über UI erstellt)
-- Beispiel-SQL für manuelles Seeding nach Nutzeranmeldung:
/*
INSERT INTO public.posts (user_id, type, category, title, description, latitude, longitude, urgency, contact_phone, status)
VALUES
  ('YOUR-USER-UUID', 'help_needed', 'everyday',
   'Begleitung zum Arzt gesucht',
   'Ich bin 78 Jahre alt und suche jemanden, der mich kommenden Dienstag zum Arzt in der Innenstadt begleitet. Die Fahrt dauert ca. 30 Minuten.',
   48.1351, 11.5820, 'high', '+4915112345678', 'active'),

  ('YOUR-USER-UUID', 'help_offered', 'food',
   'Frisches Gemüse aus dem Garten – kostenlos',
   'Ich habe viel zu viel Zucchini, Tomaten und Gurken im Garten. Wer möchte, kann gerne vorbeikommen und sich etwas mitnehmen.',
   48.1590, 11.5880, 'low', '+4917698765432', 'active'),

  ('YOUR-USER-UUID', 'rescue', 'food',
   'Bäckereiüberbleibsel – heute Abend abholen',
   'Die lokale Bäckerei hat am Abend noch Brot und Brötchen übrig. Wer abholen möchte: Bitte bis 18 Uhr melden.',
   48.1490, 11.5720, 'high', NULL, 'active'),

  ('YOUR-USER-UUID', 'animal', 'animals',
   'Hund Bello sucht liebevolles Zuhause',
   'Bello ist ein 3-jähriger Mischling, der ein neues Zuhause sucht. Er ist sehr verträglich mit Kindern.',
   48.1351, 11.5900, 'medium', '+4916023456789', 'active'),

  ('YOUR-USER-UUID', 'housing', 'housing',
   'Wohnzimmer für 3 Monate zu vermieten',
   'Ich reise für 3 Monate ins Ausland und biete mein möbliertes Zimmer gegen symbolische Miete an.',
   48.1550, 11.5750, 'medium', NULL, 'active'),

  ('YOUR-USER-UUID', 'crisis', 'emergency',
   'DRINGEND: Familie ohne Heizung',
   'Eine Familie in unserer Straße ist seit gestern ohne Heizung. Wer hat einen Elektriker-Kontakt oder kann kurzfristig helfen?',
   48.1400, 11.5800, 'critical', '+4915587654321', 'active');
*/
