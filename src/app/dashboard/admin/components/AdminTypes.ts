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
  slug: string
  category: string | null
  verified: boolean
  rating_avg: number | null
  rating_count: number
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
  | 'system'
