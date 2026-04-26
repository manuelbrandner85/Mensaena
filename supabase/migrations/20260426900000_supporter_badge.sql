-- Supporter Badge: awarded to donors who support Mensaena

-- Insert the supporter badge (golden heart, legendary rarity)
INSERT INTO badges (name, description, icon, category, requirement_type, requirement_value, points, rarity)
VALUES (
  'Unterstützer:in',
  'Hat Mensaena mit einer Spende unterstützt – ein sichtbares Dankeschön von der Community.',
  'heart',
  'special',
  'supporter',
  1,
  100,
  'legendary'
)
ON CONFLICT DO NOTHING;

-- Allow service_role to insert into user_badges (so admin API can award badges)
DROP POLICY IF EXISTS user_badges_insert_service ON user_badges;
CREATE POLICY user_badges_insert_service ON user_badges
  FOR INSERT
  TO service_role
  WITH CHECK (true);
