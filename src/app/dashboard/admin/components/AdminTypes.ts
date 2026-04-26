// ============================================================
// Admin Dashboard – Shared Types
// ============================================================

export interface AdminStats {
  total_users: number
  active_users_30d: number
  total_posts: number
  active_posts: number
  total_messages: number
  total_conversations: number
  total_interactions: number
  completed_interactions: number
  total_events: number
  upcoming_events: number
  total_board_posts: number
  active_board_posts: number
  total_organizations: number
  verified_organizations: number
  total_crises: number
  active_crises: number
  total_farm_listings: number
  verified_farms: number
  total_trust_ratings: number
  avg_trust_score: number
  total_notifications: number
  unread_notifications: number
  total_saved_posts: number
  total_regions: number
  new_users_7d: number
  new_posts_7d: number
  total_groups: number
  active_groups: number
  total_challenges: number
  active_challenges: number
  total_timebank_hours: number
  total_timebank_entries: number
  // Additional fields the RPC might return
  [key: string]: number | string | undefined
}

export interface AdminUser {
  id: string
  name: string | null
  nickname: string | null
  email: string | null
  role: 'user' | 'admin' | 'moderator'
  trust_score: number
  avatar_url: string | null
  created_at: string
  location: string | null
  is_banned?: boolean
  banned_until?: string | null
  ban_reason?: string | null
}

export interface AdminPost {
  id: string
  title: string
  type: string
  category: string
  status: string
  urgency: string
  user_id: string
  created_at: string
  profiles?: { name: string | null }
}

export interface AdminEvent {
  id: string
  title: string
  category: string
  start_date: string
  end_date: string | null
  status: string
  attendee_count: number
  author_id: string
  created_at: string
  profiles?: { name: string | null }
}

export interface AdminBoardPost {
  id: string
  content: string
  category: string
  color: string
  status: string
  pin_count: number
  comment_count: number
  author_id: string
  created_at: string
  profiles?: { name: string | null }
}

export interface AdminOrg {
  id: string
  name: string
  category: string | null
  is_verified: boolean
  is_active: boolean
  created_at: string
}

export interface AdminCrisis {
  id: string
  title: string
  category: string | null
  urgency: string | null
  status: string
  creator_id: string
  created_at: string
  profiles?: { name: string | null }
}

export interface AdminMessage {
  id: string
  content: string
  created_at: string
  deleted_at: string | null
  sender_id: string
  conversation_id: string
  profiles?: { name: string | null; email: string | null }
}

export interface AdminReport {
  id: string
  reporter_id: string
  content_type: string
  content_id: string
  reason: string
  status: string
  created_at: string
  reporter?: { name: string | null; email: string | null }
}

export interface AdminGroup {
  id: string
  name: string
  slug: string
  description: string | null
  category: string
  is_private: boolean
  member_count: number
  post_count: number
  creator_id: string
  created_at: string
  profiles?: { name: string | null }
}

export interface AdminGroupMember {
  id: string
  group_id: string
  user_id: string
  role: string
  joined_at: string
  profiles?: { name: string | null; email: string | null }
}

export interface AdminChallenge {
  id: string
  title: string
  description: string | null
  category: string
  difficulty: string
  points: number
  max_participants: number | null
  participant_count: number
  start_date: string
  end_date: string
  status: string
  creator_id: string
  created_at: string
  profiles?: { name: string | null }
}

export interface AdminChallengeProgress {
  id: string
  challenge_id: string
  user_id: string
  status: string
  progress_pct: number
  completed_at: string | null
  joined_at: string
  profiles?: { name: string | null; email: string | null }
}

export interface AdminTimebankEntry {
  id: string
  giver_id: string
  receiver_id: string
  post_id: string | null
  hours: number
  description: string
  category: string
  status: string
  confirmed_at: string | null
  created_at: string
  giver?: { name: string | null; email: string | null }
  receiver?: { name: string | null; email: string | null }
}

export type AdminTab =
  | 'overview'
  | 'users'
  | 'posts'
  | 'chat'
  | 'events'
  | 'board'
  | 'crisis'
  | 'orgs'
  | 'farms'
  | 'reports'
  | 'groups'
  | 'challenges'
  | 'zeitbank'
  | 'botfeedback'
  | 'contact'
  | 'marketing'
  | 'system'

export interface AdminEmailCampaign {
  id: string
  type: 'welcome' | 'newsletter' | 'update' | 'custom'
  status: 'draft' | 'sending' | 'sent'
  subject: string
  preview_text: string | null
  html_content: string
  recipient_count: number
  sent_count: number
  auto_generated: boolean
  sent_at: string | null
  created_by: string | null
  created_at: string
  updated_at: string
}

export interface AdminEmailSubscription {
  id: string
  user_id: string
  email: string
  subscribed: boolean
  unsubscribe_token: string
  unsubscribed_at: string | null
  created_at: string
  profiles?: { name: string | null }
}

export interface SocialMediaChannel {
  id: string
  platform: 'facebook' | 'instagram' | 'x' | 'linkedin'
  label: string
  access_token: string | null
  api_key: string | null
  api_secret: string | null
  page_id: string | null
  is_connected: boolean
  last_verified: string | null
  config: Record<string, unknown>
  created_at: string
}

export interface SocialMediaPost {
  id: string
  status: 'draft' | 'scheduled' | 'publishing' | 'published' | 'failed'
  content: string
  platforms: string[]
  media_urls: string[]
  hashtags: string[]
  scheduled_at: string | null
  published_at: string | null
  auto_generated: boolean
  ai_prompt: string | null
  created_at: string
  social_media_post_logs?: SocialMediaPostLog[]
}

export interface SocialMediaPostLog {
  id: string
  post_id: string
  platform: string
  status: 'pending' | 'sent' | 'failed'
  platform_post_id: string | null
  error_msg: string | null
  posted_at: string
}
