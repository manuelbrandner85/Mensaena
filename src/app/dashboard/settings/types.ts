/**
 * TypeScript types for the Settings system.
 */

export interface SettingsProfile {
  id: string;
  display_name: string | null;
  username: string | null;
  bio: string;
  email: string;
  phone: string | null;
  homepage: string | null;
  avatar_url: string | null;
  latitude: number | null;
  longitude: number | null;
  address: string | null;
  radius_km: number;

  // Benachrichtigungen
  notify_new_messages: boolean;
  notify_new_interactions: boolean;
  notify_nearby_posts: boolean;
  notify_trust_ratings: boolean;
  notify_system: boolean;
  notify_email: boolean;
  notify_push: boolean;
  notify_sound: boolean;
  notification_radius_km: number;
  notify_inactivity_reminder: boolean;

  // Privatsphäre
  show_online_status: boolean;
  show_location: boolean;
  show_trust_score: boolean;
  show_activity: boolean;
  show_phone: boolean;
  allow_messages_from: 'everyone' | 'trusted' | 'nobody';
  read_receipts: boolean;
  allow_matching: boolean;
  profile_visibility: 'public' | 'neighbors' | 'private';

  // Rollen
  is_mentor: boolean;
  mentor_topics: string[];

  // Notfall
  emergency_contacts: EmergencyContact[];

  // Account (internal, read-only)
  deletion_requested_at?: string | null;
  deletion_confirmed?: boolean;
  created_at?: string;
  updated_at?: string;

  // Verification (read-only)
  verified_email?: boolean;
  verified_phone?: boolean;
  verified_community?: boolean;

  // Legacy / optional extras
  name?: string;
  location?: string | null;
  skills?: string[];
}

export interface EmergencyContact {
  name: string;
  phone: string;
  relationship: string;
}

export interface DataExport {
  exported_at: string;
  user: {
    id: string;
    email: string;
    created_at: string;
  };
  profile: Record<string, unknown>;
  posts: Record<string, unknown>[];
  messages: Record<string, unknown>[];
  interactions: Record<string, unknown>[];
  saved_posts: Record<string, unknown>[];
  trust_ratings_given: Record<string, unknown>[];
  trust_ratings_received: Record<string, unknown>[];
  notifications: Record<string, unknown>[];
  conversations: Record<string, unknown>[];
  reports: Record<string, unknown>[];
  blocks: Record<string, unknown>[];
}

export type SettingsTab = 'profile' | 'notifications' | 'privacy' | 'security' | 'account';

export interface BlockedUser {
  id: string;
  blocked_id: string;
  created_at: string;
  profiles?: {
    name?: string;
    avatar_url?: string | null;
  };
}

export interface TabConfig {
  id: SettingsTab;
  label: string;
  icon: string;
}
