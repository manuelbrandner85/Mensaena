-- Impact/Aufwand-Priorisierung für Godmode-Vorschläge.
-- impact: Nutzen für Nutzer/App (1=gering … 5=sehr hoch)
-- effort: Umsetzungsaufwand (1=schnell … 5=groß)
-- Quick-Wins = hoher impact + niedriger effort. Sortierung/Badge im Dashboard.
alter table public.admin_dev_suggestions
  add column if not exists impact  smallint,
  add column if not exists effort  smallint;

comment on column public.admin_dev_suggestions.impact is
  'Nutzen 1-5 (5=sehr hoch). Vom Tiefen-Scan gesetzt.';
comment on column public.admin_dev_suggestions.effort is
  'Aufwand 1-5 (1=schnell, 5=groß). Vom Tiefen-Scan gesetzt.';
