-- ============================================================
-- Migration 009: GPS-Koordinaten + korrigierte Krisentelefon-Eintraege
-- Quelle: polizei.gv.at, oesterreich.gv.at, telefonseelsorge.de/at, 143.ch, ch.ch
-- ============================================================

-- Geodaten fuer bereits vorhandene Organisationen nachtraeglich ergaenzen
-- (UPDATE nur falls Tabelle existiert)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'organizations' AND table_schema = 'public') THEN

    -- ── TIERHEIME ────────────────────────────────────────────────────────────
    UPDATE public.organizations SET latitude = 52.5616, longitude = 13.4813
      WHERE name ILIKE '%Tierheim Berlin%' AND country = 'DE';

    UPDATE public.organizations SET latitude = 53.5425, longitude = 10.0420
      WHERE name ILIKE '%Hamburger Tierschutzverein%' AND country = 'DE';

    UPDATE public.organizations SET latitude = 53.5791, longitude = 9.9490
      WHERE name ILIKE '%Franziskus Tierheim Hamburg%' AND country = 'DE';

    UPDATE public.organizations SET latitude = 50.1246, longitude = 8.7412
      WHERE name ILIKE '%Tierschutzverein Frankfurt%' AND country = 'DE';

    UPDATE public.organizations SET latitude = 50.9720, longitude = 7.0955
      WHERE name ILIKE '%Tierheim Koeln%' AND country = 'DE';

    UPDATE public.organizations SET latitude = 49.4657, longitude = 11.1023
      WHERE name ILIKE '%Tierheim Nuernberg%' AND country = 'DE';

    UPDATE public.organizations SET latitude = 48.1985, longitude = 11.3968
      WHERE name ILIKE '%Muenchner Tierschutzverein%' AND country = 'DE';

    UPDATE public.organizations SET latitude = 48.7268, longitude = 9.0982
      WHERE name ILIKE '%Tierheim Stuttgart%' AND country = 'DE';

    UPDATE public.organizations SET latitude = 48.1760, longitude = 16.3055
      WHERE name ILIKE '%TierQuarTier Wien%' AND country = 'AT';

    UPDATE public.organizations SET latitude = 48.1050, longitude = 16.3310
      WHERE name ILIKE '%Tierschutz Austria%' AND country = 'AT';

    UPDATE public.organizations SET latitude = 47.0435, longitude = 15.4147
      WHERE name ILIKE '%Tierheim Graz%' AND country = 'AT';

    UPDATE public.organizations SET latitude = 48.2897, longitude = 14.2894
      WHERE name ILIKE '%Tierheim Linz%' AND country = 'AT';

    UPDATE public.organizations SET latitude = 47.4018, longitude = 8.5702
      WHERE name ILIKE '%Zuercher Tierschutz%' AND country = 'CH';

    UPDATE public.organizations SET latitude = 46.9530, longitude = 7.3943
      WHERE name ILIKE '%Berner Tierschutz%' AND country = 'CH';

    -- ── SUPPENKUECHEN ────────────────────────────────────────────────────────
    UPDATE public.organizations SET latitude = 52.5688, longitude = 13.3918
      WHERE name ILIKE '%Franziskaner Suppenkueche Berlin%' AND country = 'DE';

    UPDATE public.organizations SET latitude = 52.5668, longitude = 13.3919
      WHERE name ILIKE '%Caritas Suppenkueche Berlin%' AND country = 'DE';

    UPDATE public.organizations SET latitude = 48.1178, longitude = 11.6093
      WHERE name ILIKE '%Franziskaner Suppenkueche Muenchen%' AND country = 'DE';

    UPDATE public.organizations SET latitude = 48.1980, longitude = 16.3549
      WHERE name ILIKE '%Caritas Gruft Wien%' AND country = 'AT';

    -- ── OBDACHLOSENHILFE ─────────────────────────────────────────────────────
    UPDATE public.organizations SET latitude = 52.5290, longitude = 13.3612
      WHERE name ILIKE '%Berliner Stadtmission%' AND country = 'DE';

    UPDATE public.organizations SET latitude = 48.1980, longitude = 16.3549
      WHERE name ILIKE '%Caritas Wien%Kaeltetelefon%' AND country = 'AT';

    UPDATE public.organizations SET latitude = 47.3769, longitude = 8.5417
      WHERE name ILIKE '%Winterhilfe Schweiz%' AND country = 'CH';

    -- ── TAFELN ───────────────────────────────────────────────────────────────
    UPDATE public.organizations SET latitude = 52.4788, longitude = 13.3475
      WHERE name ILIKE '%Berliner Tafel%' AND country = 'DE';

    UPDATE public.organizations SET latitude = 48.1375, longitude = 16.3440
      WHERE name ILIKE '%Wiener Tafel%' AND country = 'AT';

    -- ── KRISENTELEFONE ───────────────────────────────────────────────────────
    UPDATE public.organizations SET latitude = 48.2090, longitude = 16.3700
      WHERE name ILIKE '%Telefonseelsorge Oesterreich%' AND country = 'AT';

    UPDATE public.organizations SET latitude = 48.2090, longitude = 16.3700
      WHERE name ILIKE '%Rat auf Draht%' AND country = 'AT';

    UPDATE public.organizations SET latitude = 47.3769, longitude = 8.5417
      WHERE name ILIKE '%Dargebotene Hand%' AND country = 'CH';

    UPDATE public.organizations SET latitude = 48.1980, longitude = 16.3400
      WHERE name ILIKE '%PSD Wien%' AND country = 'AT';

    -- ── ALLGEMEIN ────────────────────────────────────────────────────────────
    UPDATE public.organizations SET latitude = 47.8125, longitude = 13.0550
      WHERE name ILIKE '%Rotes Kreuz Oesterreich%' AND country = 'AT';

    UPDATE public.organizations SET latitude = 46.9498, longitude = 7.4474
      WHERE name ILIKE '%Schweizerisches Rotes Kreuz%' AND country = 'CH';

    UPDATE public.organizations SET latitude = 48.1985, longitude = 16.3373
      WHERE name ILIKE '%Caritas Oesterreich%' AND country = 'AT';

  END IF;
END $$;

-- ============================================================
-- Krisentelefon-Eintraege: Falsche loeschen + korrekte neu einfuegen
-- (nur falls organizations-Tabelle existiert)
-- ============================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'organizations' AND table_schema = 'public') THEN

    -- Alte (ggf. falsche) Krisentelefon-Eintraege entfernen
    DELETE FROM public.organizations WHERE category = 'krisentelefon';

    -- ── DEUTSCHLAND – Offizielle Krisentelefone ──────────────────────────────
    INSERT INTO public.organizations
      (name, category, description, city, state, country, phone, website,
       opening_hours, services, tags, is_verified) VALUES

    ('TelefonSeelsorge Deutschland (evangelisch)',
     'krisentelefon',
     'Kostenlose, anonyme Krisenberatung rund um die Uhr. Evangelischer Dienst. Quelle: telefonseelsorge.de',
     'Berlin', 'Berlin', 'DE',
     '0800 111 0 111', 'https://www.telefonseelsorge.de',
     '24/7 kostenlos',
     ARRAY['Krisenberatung','Seelsorge','Chat','E-Mail-Beratung'],
     ARRAY['krisentelefon','seelsorge','kostenlos','anonym','deutschland'], TRUE),

    ('TelefonSeelsorge Deutschland (katholisch)',
     'krisentelefon',
     'Kostenlose, anonyme Krisenberatung rund um die Uhr. Katholischer Dienst. Quelle: telefonseelsorge.de',
     'Berlin', 'Berlin', 'DE',
     '0800 111 0 222', 'https://www.telefonseelsorge.de',
     '24/7 kostenlos',
     ARRAY['Krisenberatung','Seelsorge','Chat','E-Mail-Beratung'],
     ARRAY['krisentelefon','seelsorge','kostenlos','anonym','deutschland'], TRUE),

    ('TelefonSeelsorge Deutschland (EU-Helpline 116 123)',
     'krisentelefon',
     'Europaeische Helpline fuer emotionale Unterstuetzung. Quelle: telefonseelsorge.de',
     'Berlin', 'Berlin', 'DE',
     '116 123', 'https://www.telefonseelsorge.de',
     '24/7 kostenlos',
     ARRAY['Krisenberatung','Seelsorge','EU-weit'],
     ARRAY['krisentelefon','seelsorge','eu','deutschland'], TRUE),

    ('Nummer gegen Kummer – Kinder- & Jugendtelefon',
     'krisentelefon',
     'Beratung fuer Kinder und Jugendliche bis 19 Jahre. Quelle: nummergegenkummer.de',
     'Wuppertal', 'Nordrhein-Westfalen', 'DE',
     '116 111', 'https://www.nummergegenkummer.de',
     'Mo-Sa 14-20 Uhr, kostenlos',
     ARRAY['Kinder','Jugend','Krisenberatung','Anonym'],
     ARRAY['krisentelefon','kinder','jugend','deutschland'], TRUE),

    ('Hilfetelefon – Gewalt gegen Frauen',
     'krisentelefon',
     'Bundesweites Hilfetelefon fuer Frauen bei Gewalt. Viele Sprachen. Quelle: hilfetelefon.de',
     'Berlin', 'Berlin', 'DE',
     '116 016', 'https://www.hilfetelefon.de',
     '24/7 kostenlos, viele Sprachen',
     ARRAY['Frauen','Gewalt','Beratung','Anonym'],
     ARRAY['krisentelefon','frauen','gewalt','deutschland'], TRUE),

    -- ── OESTERREICH – Offizielle Krisentelefone ──────────────────────────────
    ('Telefonseelsorge Oesterreich',
     'krisentelefon',
     'Kostenloser, anonymer Notrufdienst rund um die Uhr. Quelle: telefonseelsorge.at & oesterreich.gv.at',
     'Wien', 'Wien', 'AT',
     '142', 'https://www.telefonseelsorge.at',
     '24/7 kostenlos',
     ARRAY['Krisenberatung','Seelsorge','Chat','Anonym'],
     ARRAY['krisentelefon','seelsorge','kostenlos','anonym','oesterreich'], TRUE),

    ('Rat auf Draht – Kinder & Jugend',
     'krisentelefon',
     'Kostenlose Krisenhotline fuer Kinder und Jugendliche in Oesterreich. Quelle: rataufdraht.at',
     'Wien', 'Wien', 'AT',
     '147', 'https://www.rataufdraht.at',
     '24/7 kostenlos',
     ARRAY['Kinder','Jugend','Krisenberatung','Anonym'],
     ARRAY['krisentelefon','kinder','jugend','oesterreich'], TRUE),

    ('Frauenhelpline gegen Gewalt',
     'krisentelefon',
     'Kostenlose Hilfe fuer Frauen bei Gewalt in Oesterreich. Quelle: oesterreich.gv.at',
     'Wien', 'Wien', 'AT',
     '0800 222 555', 'https://www.frauenhelpline.at',
     '24/7 kostenlos',
     ARRAY['Frauen','Gewalt','Beratung','Anonym'],
     ARRAY['krisentelefon','frauen','gewalt','oesterreich'], TRUE),

    ('Maennernotruf Oesterreich',
     'krisentelefon',
     'Beratung fuer Maenner in Krisen- und Gewaltsituationen. Quelle: maennernotruf.at',
     'Wien', 'Wien', 'AT',
     '0800 400 777', 'https://www.maennernotruf.at',
     '24/7 kostenlos',
     ARRAY['Maenner','Krisenberatung','Anonym'],
     ARRAY['krisentelefon','maenner','oesterreich'], TRUE),

    ('PSD Wien – Sozialpsychiatrischer Notdienst',
     'krisentelefon',
     'Psychiatrische Krisenintervention und Akuthilfe in Wien. Quelle: psd-wien.at',
     'Wien', 'Wien', 'AT',
     '01 31330', 'https://psd-wien.at',
     '24/7',
     ARRAY['Psychiatrie','Krisenintervention','Akuthilfe'],
     ARRAY['krisentelefon','psychiatrie','wien','oesterreich'], TRUE),

    -- ── SCHWEIZ – Offizielle Krisentelefone ──────────────────────────────────
    ('Die Dargebotene Hand (Tel 143)',
     'krisentelefon',
     'Schweizer Sorgentelefon – kostenlos, anonym, vertraulich. Quelle: 143.ch & ch.ch',
     'Zuerich', 'Zuerich', 'CH',
     '143', 'https://www.143.ch',
     '24/7 kostenlos',
     ARRAY['Krisenberatung','Chat','E-Mail','Anonym'],
     ARRAY['krisentelefon','seelsorge','kostenlos','anonym','schweiz'], TRUE),

    ('Kinder-/Jugendtelefon Schweiz (147)',
     'krisentelefon',
     'Kostenlose Beratung fuer Kinder und Jugendliche in der Schweiz. Quelle: 147.ch & ch.ch',
     'Zuerich', 'Zuerich', 'CH',
     '147', 'https://www.147.ch',
     '24/7 kostenlos',
     ARRAY['Kinder','Jugend','Krisenberatung','Anonym'],
     ARRAY['krisentelefon','kinder','jugend','schweiz'], TRUE),

    ('Hilfetelefon Haeusliche Gewalt Schweiz',
     'krisentelefon',
     'Beratung bei haeuslicher Gewalt in der Schweiz. Kostenlos, 24/7.',
     'Bern', 'Bern', 'CH',
     '0800 040 040', NULL,
     '24/7 kostenlos',
     ARRAY['Gewalt','Beratung','Anonym'],
     ARRAY['krisentelefon','gewalt','schweiz'], TRUE);

  END IF;
END $$;
