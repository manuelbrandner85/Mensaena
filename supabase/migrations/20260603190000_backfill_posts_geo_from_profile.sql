-- Backfill: Beiträge ohne lat/lng erben die Geo-Koordinaten ihres Autors.
-- Bisheriger Bug: der Create-Flow speicherte lat/lng nur, wenn der User
-- aktiv den GPS-Button tippte. Folge: die meisten Posts hatten keine
-- Koordinaten und waren auf der Karte unsichtbar (clientseitiger
-- hasGeo-Filter). Das Profil hat in vielen Fällen bereits lat/lng aus
-- dem Onboarding — diese Werte sind eine sinnvolle Default-Position.
--
-- Idempotent: nur Posts mit NULL-Koordinaten werden angefasst.

UPDATE public.posts AS p
SET
  latitude  = pr.latitude,
  longitude = pr.longitude
FROM public.profiles AS pr
WHERE p.user_id = pr.id
  AND p.latitude IS NULL
  AND p.longitude IS NULL
  AND pr.latitude IS NOT NULL
  AND pr.longitude IS NOT NULL;
