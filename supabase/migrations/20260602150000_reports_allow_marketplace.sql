-- Marktplatz-Inserate können jetzt gemeldet werden (Moderation/Betrugsschutz).
-- Bisher erlaubte der CHECK nur post/message/review/profile.
alter table public.reports drop constraint if exists reports_content_type_check;
alter table public.reports add constraint reports_content_type_check
  check (content_type = any (array['post','message','review','profile','marketplace']));
