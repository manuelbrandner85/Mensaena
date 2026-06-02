-- 'board' als gültigen content_type für Meldungen ergänzen, damit das
-- Melden eines Pinnwand-Eintrags nicht am CHECK scheitert.
alter table public.reports drop constraint if exists reports_content_type_check;
alter table public.reports add constraint reports_content_type_check
  check (content_type = any (array['post','message','review','profile','marketplace','board']));
