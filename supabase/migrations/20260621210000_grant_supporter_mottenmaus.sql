-- ════════════════════════════════════════════════════════════════════════
-- Dankeschön für eine Spende: Mottenmaus@hotmail.de ("Anika")
--
-- donor_tier >= 2 ("Förderer"):
--   • zeigt das goldene Herz im Profil-Header (Anzeige ab donorTier >= 1)
--   • schaltet per RLS (channels_donor_insert) das Erstellen von
--     Community-Chat-Kanälen frei → darf einen eigenen Raum erstellen
--
-- GREATEST(...) = niemals herabstufen, falls bereits höher. Idempotent.
-- ════════════════════════════════════════════════════════════════════════
UPDATE public.profiles p
SET donor_tier     = GREATEST(p.donor_tier, 2),
    donation_count = GREATEST(p.donation_count, 1)
FROM auth.users u
WHERE u.id = p.id
  AND lower(u.email) = lower('Mottenmaus@hotmail.de');
