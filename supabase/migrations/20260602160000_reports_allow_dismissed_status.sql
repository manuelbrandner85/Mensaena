-- Der Admin-Reports-Screen bietet einen 'Verwerfen'-Button (status=
-- 'dismissed'), aber der CHECK erlaubte nur pending/reviewed/resolved →
-- Verwerfen schlug immer fehl ("Fehler beim Update"). 'dismissed' ergänzt.
alter table public.reports drop constraint if exists reports_status_check;
alter table public.reports add constraint reports_status_check
  check (status = any (array['pending','reviewed','resolved','dismissed']));
