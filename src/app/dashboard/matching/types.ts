// ============================================================
// MENSAENA – Matching System Types
// ============================================================

/** Match status enum matching the DB enum */
export type MatchStatus =
  | 'suggested'
  | 'pending'
  | 'accepted'
  | 'declined'
  | 'expired'
  | 'completed'
  | 'cancelled'

/** Score breakdown from the matching algorithm */
export interface ScoreBreakdown {
  category_match: number   // max 30
  distance_score: number   // max 25
  trust_score: number      // max 20
  availability_score: number // max 15
  activity_score: number   // max 10
}

/** Post summary embedded in a match */
export interface MatchPostSummary {
  id: string
  title: string
  type: string
  category: string | null
  description: string | null
  location: string | null
  urgency: string | null
  media_urls: string[] | null
}

/** User profile summary embedded in a match */
export interface MatchUserProfile {
  id: string
  name: string | null
  avatar_url: string | null
  trust_score: number
  trust_score_count: number
}

/** Full match record returned by get_my_matches RPC */
export interface Match {
  id: string
  offer_post_id: string
  request_post_id: string
  offer_user_id: string
  request_user_id: string
  match_score: number
  score_breakdown: ScoreBreakdown
  status: MatchStatus
  distance_km: number | null
  offer_responded: boolean
  request_responded: boolean
  offer_accepted: boolean | null
  request_accepted: boolean | null
  conversation_id: string | null
  seen_by_offer: boolean
  seen_by_request: boolean
  declined_by: string | null
  decline_reason: string | null
  expires_at: string
  completed_at: string | null
  created_at: string
  updated_at: string
  // Denormalized post & profile data
  offer_post: MatchPostSummary
  request_post: MatchPostSummary
  offer_user: MatchUserProfile
  request_user: MatchUserProfile
}

/** User's matching preferences */
export interface MatchPreferences {
  id: string
  user_id: string
  matching_enabled: boolean
  max_distance_km: number
  preferred_categories: string[]
  excluded_categories: string[]
  min_trust_score: number
  max_matches_per_day: number
  notify_on_match: boolean
  auto_accept_threshold: number | null
  created_at: string
  updated_at: string
}

/** Default preferences used when no record exists */
export const DEFAULT_PREFERENCES: Omit<MatchPreferences, 'id' | 'user_id' | 'created_at' | 'updated_at'> = {
  matching_enabled: true,
  max_distance_km: 25,
  preferred_categories: [],
  excluded_categories: [],
  min_trust_score: 0,
  max_matches_per_day: 5,
  notify_on_match: true,
  auto_accept_threshold: null,
}

/** Filter options for the match list */
export type MatchFilter = 'all' | MatchStatus

/** Available actions on a match */
export type MatchAction = 'accept' | 'decline' | 'complete' | 'cancel' | 'open_chat'

/** Match counts returned by get_match_counts RPC */
export interface MatchCounts {
  suggested: number
  pending: number
  accepted: number
  completed: number
}

/** Notification types related to matching */
export type MatchNotificationType =
  | 'new_match'
  | 'match_partner_accepted'
  | 'match_both_accepted'
  | 'match_expiring'

/** Score factor config for UI display */
export interface ScoreFactor {
  key: keyof ScoreBreakdown
  label: string
  maxPoints: number
  color: string
  icon: string
}

/** The five scoring factors with their weights */
export const SCORE_FACTORS: ScoreFactor[] = [
  { key: 'category_match', label: 'Kategorie', maxPoints: 30, color: '#6366f1', icon: 'Tag' },
  { key: 'distance_score', label: 'Entfernung', maxPoints: 25, color: '#10b981', icon: 'MapPin' },
  { key: 'trust_score', label: 'Vertrauen', maxPoints: 20, color: '#f59e0b', icon: 'Shield' },
  { key: 'availability_score', label: 'Verfuegbarkeit', maxPoints: 15, color: '#3b82f6', icon: 'Clock' },
  { key: 'activity_score', label: 'Aktivitaet', maxPoints: 10, color: '#ef4444', icon: 'Activity' },
]

/** German labels for match statuses */
export const MATCH_STATUS_LABELS: Record<MatchStatus, string> = {
  suggested: 'Vorgeschlagen',
  pending: 'Warte auf Antwort',
  accepted: 'Akzeptiert',
  declined: 'Abgelehnt',
  expired: 'Abgelaufen',
  completed: 'Abgeschlossen',
  cancelled: 'Abgebrochen',
}

/** Status colors for badges */
export const MATCH_STATUS_COLORS: Record<MatchStatus, { text: string; bg: string; border: string }> = {
  suggested: { text: 'text-blue-700', bg: 'bg-blue-50', border: 'border-blue-200' },
  pending: { text: 'text-amber-700', bg: 'bg-amber-50', border: 'border-amber-200' },
  accepted: { text: 'text-emerald-700', bg: 'bg-emerald-50', border: 'border-emerald-200' },
  declined: { text: 'text-red-700', bg: 'bg-red-50', border: 'border-red-200' },
  expired: { text: 'text-gray-600', bg: 'bg-gray-50', border: 'border-gray-200' },
  completed: { text: 'text-green-700', bg: 'bg-green-50', border: 'border-green-200' },
  cancelled: { text: 'text-gray-600', bg: 'bg-gray-100', border: 'border-gray-300' },
}
