/**
 * Post type configuration – single source of truth for all post-type
 * styling, labels, emojis, and color classes throughout the app.
 */

export interface TypeConfig {
  label: string
  emoji: string
  color: string
  bg: string
  dot: string
}

const TYPE_CONFIG: Record<string, TypeConfig> = {
  rescue:    { label: 'Hilfe / Retten',   emoji: '🧡', color: 'text-orange-700',  bg: 'bg-orange-50 border-orange-200',  dot: 'bg-orange-500'  },
  animal:    { label: 'Tierhilfe',         emoji: '🐾', color: 'text-pink-700',    bg: 'bg-pink-50 border-pink-200',      dot: 'bg-pink-500'    },
  housing:   { label: 'Wohnangebot',       emoji: '🏡', color: 'text-blue-700',    bg: 'bg-blue-50 border-blue-200',      dot: 'bg-blue-500'    },
  supply:    { label: 'Versorgung',        emoji: '🌾', color: 'text-yellow-700',  bg: 'bg-yellow-50 border-yellow-200',  dot: 'bg-yellow-500'  },
  mobility:  { label: 'Mobilität',         emoji: '🚗', color: 'text-indigo-700',  bg: 'bg-indigo-50 border-indigo-200',  dot: 'bg-indigo-500'  },
  sharing:   { label: 'Teilen / Skill',    emoji: '🔄', color: 'text-teal-700',    bg: 'bg-teal-50 border-teal-200',      dot: 'bg-teal-500'    },
  community: { label: 'Community',         emoji: '🗳️', color: 'text-violet-700',  bg: 'bg-violet-50 border-violet-200',  dot: 'bg-violet-500'  },
  crisis:    { label: 'Notfall',           emoji: '🚨', color: 'text-red-700',     bg: 'bg-red-100 border-red-400',       dot: 'bg-red-600'     },
  // Legacy fallbacks
  help_request: { label: 'Hilfe gesucht',    emoji: '🆘', color: 'text-red-700',    bg: 'bg-red-50 border-red-200',       dot: 'bg-red-500'     },
  help_offered: { label: 'Hilfe angeboten',  emoji: '💚', color: 'text-green-700',  bg: 'bg-green-50 border-green-200',   dot: 'bg-green-500'   },
  skill:        { label: 'Skill',            emoji: '🎯', color: 'text-purple-700', bg: 'bg-purple-50 border-purple-200', dot: 'bg-purple-500'  },
  knowledge:    { label: 'Wissen',           emoji: '📚', color: 'text-emerald-700',bg: 'bg-emerald-50 border-emerald-200',dot:'bg-emerald-500'  },
  mental:       { label: 'Mentale Hilfe',    emoji: '🧠', color: 'text-cyan-700',   bg: 'bg-cyan-50 border-cyan-200',     dot: 'bg-cyan-500'    },
}

const FALLBACK: TypeConfig = {
  label: 'Beitrag',
  emoji: '📝',
  color: 'text-gray-700',
  bg: 'bg-gray-50 border-gray-200',
  dot: 'bg-gray-500',
}

/**
 * Returns the full TypeConfig for a given post type string.
 * Falls back to a neutral grey config if the type is unknown.
 */
export function getTypeConfig(type: string): TypeConfig {
  return TYPE_CONFIG[type] ?? FALLBACK
}

/**
 * Shape of a post as consumed by PostCard and related components.
 */
export interface PostCardPost {
  id: string
  type: string
  category?: string
  title: string
  description?: string
  location_text?: string
  lat?: number
  lng?: number
  contact_phone?: string
  contact_email?: string
  contact_whatsapp?: string
  urgency?: number | string
  created_at: string
  user_id: string
  is_anonymous?: boolean
  is_recurring?: boolean
  recurring_interval?: string
  availability_days?: string[]
  availability_start?: string
  availability_end?: string
  reaction_count?: number
  media_urls?: string[]
  tags?: string[]
  status?: string
  privacy_phone?: boolean
  privacy_email?: boolean
  profiles?: {
    name?: string
    avatar_url?: string
    verified_email?: boolean
    verified_phone?: boolean
    verified_community?: boolean
    trust_score?: number
    trust_score_count?: number
  }
}

export default TYPE_CONFIG
