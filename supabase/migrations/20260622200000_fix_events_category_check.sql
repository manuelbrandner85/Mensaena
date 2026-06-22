-- Fix: Event-Erstellung schlug still fehl. Die Flutter-App nutzt Kategorie-
-- Werte (community, sports, education, nature, music, volunteer), die NICHT im
-- events_category_check standen (nur meetup/workshop/sport/food/market/culture/
-- kids/seniors/cleanup/other). Default 'community' → INSERT-Constraint-Verstoß
-- → "events.createFailed". CHECK auf die Vereinigung erweitern (Web + App).

ALTER TABLE public.events DROP CONSTRAINT IF EXISTS events_category_check;
ALTER TABLE public.events ADD CONSTRAINT events_category_check CHECK (
  category = ANY (ARRAY[
    'meetup','workshop','sport','food','market','culture','kids','seniors','cleanup','other',
    'community','sports','education','nature','music','volunteer'
  ])
);
