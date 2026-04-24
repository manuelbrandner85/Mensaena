-- Posts
CREATE INDEX IF NOT EXISTS idx_posts_user_status ON posts(user_id, status);
CREATE INDEX IF NOT EXISTS idx_posts_status_created ON posts(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_active_recent ON posts(created_at DESC) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_posts_active_geo ON posts(latitude, longitude) WHERE status = 'active' AND latitude IS NOT NULL AND longitude IS NOT NULL;

-- Trust Ratings
CREATE INDEX IF NOT EXISTS idx_trust_ratings_rated_created ON trust_ratings(rated_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_trust_ratings_rater_id ON trust_ratings(rater_id);

-- Interactions
CREATE INDEX IF NOT EXISTS idx_interactions_helper_status ON interactions(helper_id, status);
CREATE INDEX IF NOT EXISTS idx_interactions_completed_recent ON interactions(created_at DESC) WHERE status = 'completed';

-- Messages
CREATE INDEX IF NOT EXISTS idx_messages_conv_created ON messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender_created ON messages(sender_id, created_at DESC);

-- Conversation Members
CREATE INDEX IF NOT EXISTS idx_conv_members_user_conv ON conversation_members(user_id, conversation_id);

-- Saved Posts
CREATE INDEX IF NOT EXISTS idx_saved_posts_user_post ON saved_posts(user_id, post_id);

-- Notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, created_at DESC) WHERE read_at IS NULL;

-- Marketplace
CREATE INDEX IF NOT EXISTS idx_marketplace_status_created ON marketplace_listings(status, created_at DESC);

-- Board
CREATE INDEX IF NOT EXISTS idx_board_posts_created ON board_posts(created_at DESC);

-- Events
CREATE INDEX IF NOT EXISTS idx_events_date ON events(date_start);

-- Crises
CREATE INDEX IF NOT EXISTS idx_crises_status_created ON crises(status, created_at DESC);
