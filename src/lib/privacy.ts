/**
 * Privacy utilities for Mensaena.
 * Controls which profile fields are visible based on privacy settings.
 */

import { createClient } from '@/lib/supabase/client'

export interface VisibleProfile {
  id: string
  name?: string | null
  display_name?: string | null
  avatar_url?: string | null
  bio?: string | null
  phone?: string | null
  location?: string | null
  address?: string | null
  latitude?: number | null
  longitude?: number | null
  skills?: string[] | null
  trust_score?: number | null
  impact_score?: number | null
  karma_score?: number | null
  is_online?: boolean
  created_at?: string | null
  verified_email?: boolean
  verified_phone?: boolean
  verified_community?: boolean
  is_mentor?: boolean
  mentor_topics?: string[]
}

/**
 * Get only the profile fields that the viewer is allowed to see,
 * based on the profile owner's privacy settings.
 *
 * Privacy rules:
 * - profile_visibility: 'public' | 'neighbors' | 'private'
 * - show_online_status: boolean
 * - show_location: boolean
 * - show_trust_score: boolean
 * - show_activity: boolean
 * - show_phone: boolean
 * - allow_messages_from: 'everyone' | 'trusted' | 'nobody'
 *
 * A viewer is "trusted" if they have given the profile owner a trust rating >= 3.
 * A viewer is a "neighbor" if they are within the owner's radius_km.
 */
export async function getVisibleProfileFields(
  profileId: string,
  viewerId: string | null
): Promise<VisibleProfile | null> {
  const supabase = createClient()

  // Load target profile with privacy settings
  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', profileId)
    .single()

  if (!profile) return null

  // Owner always sees everything
  if (viewerId === profileId) {
    return profile as VisibleProfile
  }

  const visibility = profile.profile_visibility ?? 'public'

  // Private → only the owner can see (already handled above)
  if (visibility === 'private') {
    return {
      id: profile.id,
      name: profile.name ?? profile.display_name ?? 'Privates Profil',
      avatar_url: profile.avatar_url,
      verified_email: profile.verified_email,
      verified_phone: profile.verified_phone,
      verified_community: profile.verified_community,
    }
  }

  // Check if viewer is a neighbor (within radius)
  if (visibility === 'neighbors' && viewerId) {
    const isNeighbor = await checkIsNeighbor(supabase, profileId, viewerId, profile.radius_km ?? 10)
    if (!isNeighbor) {
      return {
        id: profile.id,
        name: profile.name ?? profile.display_name ?? 'Nur fuer Nachbarn sichtbar',
        avatar_url: profile.avatar_url,
        verified_email: profile.verified_email,
        verified_phone: profile.verified_phone,
        verified_community: profile.verified_community,
      }
    }
  }

  // Not logged in → limited public view
  if (!viewerId && visibility === 'neighbors') {
    return {
      id: profile.id,
      name: profile.name ?? profile.display_name,
      avatar_url: profile.avatar_url,
    }
  }

  // Check if viewer is "trusted" (gave trust rating >= 3)
  const isTrusted = viewerId ? await checkIsTrusted(supabase, profileId, viewerId) : false

  // Build visible profile based on privacy settings
  const result: VisibleProfile = {
    id: profile.id,
    name: profile.name,
    display_name: profile.display_name,
    avatar_url: profile.avatar_url,
    bio: profile.bio,
    created_at: profile.created_at,
    verified_email: profile.verified_email,
    verified_phone: profile.verified_phone,
    verified_community: profile.verified_community,
    is_mentor: profile.is_mentor,
    mentor_topics: profile.mentor_topics,
    skills: profile.skills,
  }

  // Conditional fields based on privacy settings
  if (profile.show_online_status) {
    result.is_online = true // Would need real online status check
  }

  if (profile.show_location) {
    result.location = profile.location
    result.address = profile.address
    result.latitude = profile.latitude
    result.longitude = profile.longitude
  }

  if (profile.show_trust_score) {
    result.trust_score = profile.trust_score
    result.impact_score = profile.impact_score
    result.karma_score = profile.karma_score
  }

  if (profile.show_phone) {
    result.phone = profile.phone
  } else if (isTrusted && profile.allow_messages_from !== 'nobody') {
    // Trusted users can see phone if messaging is allowed
    result.phone = profile.phone
  }

  return result
}

/**
 * Check if a user can send messages to a profile owner.
 */
export async function canSendMessage(
  profileId: string,
  senderId: string
): Promise<boolean> {
  const supabase = createClient()
  const { data: profile } = await supabase
    .from('profiles')
    .select('allow_messages_from')
    .eq('id', profileId)
    .single()

  if (!profile) return false

  const policy = profile.allow_messages_from ?? 'everyone'

  if (policy === 'everyone') return true
  if (policy === 'nobody') return false

  // 'trusted' — check if sender is trusted
  return checkIsTrusted(supabase, profileId, senderId)
}

/**
 * Check if viewerId is "trusted" by profileId.
 * A viewer is trusted if they have given a trust rating >= 3.
 */
async function checkIsTrusted(
  supabase: ReturnType<typeof createClient>,
  profileId: string,
  viewerId: string
): Promise<boolean> {
  const { data, count } = await supabase
    .from('trust_ratings')
    .select('id', { count: 'exact', head: true })
    .eq('rater_id', viewerId)
    .eq('rated_id', profileId)
    .gte('score', 3)

  return (count ?? 0) > 0
}

/**
 * Check if viewerId is within the profileId's radius (neighbor).
 */
async function checkIsNeighbor(
  supabase: ReturnType<typeof createClient>,
  profileId: string,
  viewerId: string,
  radiusKm: number
): Promise<boolean> {
  // Load both coordinates
  const { data: profiles } = await supabase
    .from('profiles')
    .select('id, latitude, longitude')
    .in('id', [profileId, viewerId])

  if (!profiles || profiles.length < 2) return false

  const owner = profiles.find(p => p.id === profileId)
  const viewer = profiles.find(p => p.id === viewerId)

  if (!owner?.latitude || !owner?.longitude || !viewer?.latitude || !viewer?.longitude) {
    return false
  }

  // Haversine distance calculation
  const distance = haversineKm(
    owner.latitude, owner.longitude,
    viewer.latitude, viewer.longitude
  )

  return distance <= radiusKm
}

/**
 * Haversine formula: calculate distance between two coordinates in km.
 */
function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371 // Earth radius in km
  const dLat = toRad(lat2 - lat1)
  const dLon = toRad(lon2 - lon1)
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

function toRad(deg: number): number {
  return deg * (Math.PI / 180)
}
