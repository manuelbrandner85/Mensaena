ALTER TABLE profiles ADD COLUMN IF NOT EXISTS location_verified BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS location_verified_at TIMESTAMPTZ;

-- Badge für verifizierte Nachbarn
-- (Badge wird vom Frontend nach erfolgreicher Verifikation eingefügt)
