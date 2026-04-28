-- ── Donor Tier System ──────────────────────────────────────────────────────────
-- Stufe 0: Kein Spender
-- Stufe 1: Unterstützer  (1+ Spende ODER >= 5€)
-- Stufe 2: Förderer      (3+ Spenden ODER >= 25€) → Polls + eigener Kanal
-- Stufe 3: Partner       (5+ Spenden ODER >= 50€) → Livestream-Events + Ankündigungen
-- Stufe 4: Botschafter   (10+ Spenden ODER >= 100€) → Post-Boost + Profil-Banner

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS donor_tier      int          NOT NULL DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS donation_count  int          NOT NULL DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS donation_total  numeric(10,2) NOT NULL DEFAULT 0;

-- ── Tier-Berechnung ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.calculate_donor_tier(p_count int, p_total numeric)
RETURNS int LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  IF    p_count >= 10 OR p_total >= 100 THEN RETURN 4;
  ELSIF p_count >= 5  OR p_total >= 50  THEN RETURN 3;
  ELSIF p_count >= 3  OR p_total >= 25  THEN RETURN 2;
  ELSIF p_count >= 1  OR p_total >= 5   THEN RETURN 1;
  ELSE RETURN 0;
  END IF;
END;
$$;

-- ── Sicherheit: donor_tier kann nicht durch den User selbst erhöht werden ───────
CREATE OR REPLACE FUNCTION public.prevent_donor_tier_tampering()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    NEW.donor_tier     := OLD.donor_tier;
    NEW.donation_count := OLD.donation_count;
    NEW.donation_total := OLD.donation_total;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_donor_columns ON profiles;
CREATE TRIGGER protect_donor_columns
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  WHEN (
    NEW.donor_tier     IS DISTINCT FROM OLD.donor_tier     OR
    NEW.donation_count IS DISTINCT FROM OLD.donation_count OR
    NEW.donation_total IS DISTINCT FROM OLD.donation_total
  )
  EXECUTE FUNCTION prevent_donor_tier_tampering();

-- ── Kanäle: Förderer (tier >= 2) dürfen eigene Kanäle erstellen ───────────────
DROP POLICY IF EXISTS "channels_donor_insert" ON public.chat_channels;
CREATE POLICY "channels_donor_insert" ON public.chat_channels
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND donor_tier >= 2
    )
  );
