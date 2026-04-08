// ============================================================
// MENSAENA – Typen-Definitionen
// ============================================================

export type UserProfile = {
  id: string
  name: string
  nickname: string | null
  email: string
  location: string | null
  skills: string[] | null
  avatar_url: string | null
  bio: string | null
  trust_score: number
  impact_score: number
  created_at: string
  updated_at: string
}

export type PostType =
  | 'help_needed'
  | 'help_offered'
  | 'rescue'
  | 'animal'
  | 'housing'
  | 'supply'
  | 'mobility'
  | 'sharing'
  | 'crisis'
  | 'community'

export type PostCategory =
  | 'food'
  | 'everyday'
  | 'moving'
  | 'animals'
  | 'housing'
  | 'knowledge'
  | 'skills'
  | 'mental'
  | 'mobility'
  | 'sharing'
  | 'emergency'
  | 'general'

export type PostStatus = 'active' | 'fulfilled' | 'archived' | 'pending'

export type Post = {
  id: string
  user_id: string
  type: PostType
  category: PostCategory
  title: string
  description: string
  image_urls: string[] | null
  latitude: number | null
  longitude: number | null
  urgency: 'low' | 'medium' | 'high' | 'critical'
  contact_phone: string | null
  contact_whatsapp: string | null
  contact_email: string | null
  status: PostStatus
  created_at: string
  updated_at: string
  profiles?: UserProfile
}

export type Interaction = {
  id: string
  post_id: string
  helper_id: string
  status: 'pending' | 'accepted' | 'completed' | 'cancelled'
  message: string | null
  created_at: string
  updated_at: string
}

export type Message = {
  id: string
  sender_id: string
  receiver_id: string | null
  conversation_id: string
  content: string
  created_at: string
  read_at: string | null
  profiles?: UserProfile
}

export type Conversation = {
  id: string
  type: 'direct' | 'group' | 'system'
  title: string | null
  created_at: string
  members?: ConversationMember[]
  messages?: Message[]
  last_message?: Message
}

export type ConversationMember = {
  id: string
  conversation_id: string
  user_id: string
  created_at: string
  profiles?: UserProfile
}

export type NotificationCategory =
  | 'message'
  | 'interaction'
  | 'trust_rating'
  | 'post_nearby'
  | 'post_response'
  | 'system'
  | 'bot'
  | 'mention'
  | 'welcome'
  | 'reminder'

export type AppNotification = {
  id: string
  user_id: string
  type: string
  category: NotificationCategory
  title: string | null
  content: string | null
  link: string | null
  read: boolean
  actor_id: string | null
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  metadata: Record<string, any>
  created_at: string
  deleted_at: string | null
  // Joined fields
  actor_name?: string | null
  actor_avatar?: string | null
}

/** @deprecated use AppNotification */
export type Notification = {
  id: string
  user_id: string
  type: 'message' | 'interaction' | 'post_update' | 'system' | 'help_found'
  title: string
  body: string
  read_at: string | null
  created_at: string
  link?: string
}

export type SavedPost = {
  id: string
  user_id: string
  post_id: string
  created_at: string
  posts?: Post
}

export type MapPin = {
  id: string
  lat: number
  lng: number
  type: PostType
  title: string
  category: PostCategory
  urgency: 'low' | 'medium' | 'high' | 'critical'
  status: PostStatus
}

export type DashboardStats = {
  totalPosts: number
  activePosts: number
  helpGiven: number
  helpReceived: number
  trustScore: number
  impactScore: number
}

// ── Trust Ratings ─────────────────────────────────────────────────────

export type RatingCategory =
  | 'zuverlaessig'
  | 'freundlich'
  | 'hilfsbereit'
  | 'kommunikativ'
  | 'puenktlich'
  | 'kompetent'

export type TrustRating = {
  id: string
  rater_id: string
  rated_id: string
  rating: number
  score?: number
  comment: string | null
  interaction_id: string | null
  categories: RatingCategory[]
  helpful: boolean | null
  would_recommend: boolean | null
  response: string | null
  response_at: string | null
  edited_at: string | null
  reported: boolean
  created_at: string
  // Joined fields
  rater_name?: string | null
  rater_avatar?: string | null
  rated_name?: string | null
  rated_avatar?: string | null
  post_title?: string | null
}

export type TrustScoreData = {
  average: number
  count: number
  level: number
  helpful_percent: number
  recommend_percent: number
  distribution: Record<string, number>
  recent_trend: 'up' | 'down' | 'stable'
}

export type TrustLevelInfo = {
  level: number
  name: string
  color: string
  bgColor: string
  borderColor: string
  icon: string
  description: string
  minRatings: number
  minAvg: number
}

export type PendingRating = {
  interaction_id: string
  post_id: string
  helper_id: string
  completed_at: string
  post_title: string
  partner_id: string
  partner_name: string | null
  partner_avatar: string | null
}

// ── Board (Pinnwand) ─────────────────────────────────────────────────

export type BoardPostCategory =
  | 'general'
  | 'gesucht'
  | 'biete'
  | 'event'
  | 'info'
  | 'warnung'
  | 'verloren'
  | 'fundbuero'

export type BoardPostColor = 'yellow' | 'green' | 'blue' | 'pink' | 'orange' | 'purple'

export type BoardPostStatus = 'active' | 'expired' | 'hidden' | 'deleted'

export type BoardPost = {
  id: string
  author_id: string
  content: string
  category: BoardPostCategory
  color: BoardPostColor
  image_url: string | null
  contact_info: string | null
  expires_at: string | null
  pinned: boolean
  pin_count: number
  comment_count: number
  latitude: number | null
  longitude: number | null
  region_id: string | null
  status: BoardPostStatus
  created_at: string
  updated_at: string
  // Joined fields
  profiles?: {
    name: string | null
    avatar_url: string | null
    trust_score?: number
    trust_score_count?: number
  }
  // Client state
  is_pinned_by_me?: boolean
}

export type BoardPin = {
  id: string
  user_id: string
  board_post_id: string
  created_at: string
}

export type BoardComment = {
  id: string
  board_post_id: string
  author_id: string
  content: string
  created_at: string
  updated_at: string
  profiles?: {
    name: string | null
    avatar_url: string | null
  }
}

// Navigation
export type NavItem = {
  href: string
  label: string
  icon: string
  badge?: number
  section?: string
}
