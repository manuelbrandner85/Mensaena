// ============================================================
// Dashboard – TypeScript Types
// ============================================================

export interface DashboardData {
  profile: DashboardProfile | null
  nearbyPosts: NearbyPost[]
  recentActivity: ActivityItem[]
  stats: UserStats
  unreadMessages: UnreadMessage[]
  communityPulse: CommunityPulse
  onboardingProgress: OnboardingProgress
  botTip: string | null
  trustScore: TrustScore
}

export interface DashboardProfile {
  id: string
  name: string | null
  nickname: string | null
  email: string | null
  avatar_url: string | null
  bio: string | null
  location: string | null
  latitude: number | null
  longitude: number | null
  radius_km: number | null
  trust_score: number | null
  impact_score: number | null
  created_at: string
  role: string | null
}

export interface NearbyPost {
  id: string
  title: string
  description: string | null
  type: string
  category: string | null
  status: string
  urgency: string | null
  latitude: number | null
  longitude: number | null
  location_text: string | null
  created_at: string
  user_id: string
  author_name: string | null
  author_avatar: string | null
  distance_km: number | null
}

export interface UserStats {
  postsCreated: number
  interactionsCompleted: number
  peopleHelped: number
  trustRatingAvg: number
  memberSinceDays: number
  savedPostsCount: number
}

export type ActivityType =
  | 'new_post'
  | 'interaction_completed'
  | 'trust_rating'
  | 'new_neighbor'
  | 'event_upcoming'
  | 'crisis_alert'

export interface ActivityItem {
  id: string
  type: ActivityType
  title: string
  description: string
  timestamp: string
  iconName: string
  color: string
  linkTo: string
  actorName: string | null
  actorAvatarUrl: string | null
}

export interface UnreadMessage {
  conversationId: string
  senderName: string
  senderAvatarUrl: string | null
  lastMessageText: string
  timestamp: string
  unreadCount: number
}

export interface CommunityPulse {
  activeUsersToday: number
  newPostsToday: number
  interactionsThisWeek: number
  newestNeighborName: string | null
  newestNeighborJoinedAt: string | null
}

export interface OnboardingProgress {
  completed: boolean
  steps: OnboardingStep[]
  percentComplete: number
}

export interface OnboardingStep {
  id: string
  label: string
  done: boolean
  actionPath: string
}

export interface TrustScore {
  average: number
  totalRatings: number
  trend: 'up' | 'down' | 'stable'
}
