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

// Navigation
export type NavItem = {
  href: string
  label: string
  icon: string
  badge?: number
  section?: string
}
