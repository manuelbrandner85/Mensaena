import {
  Clock, CheckCircle, CheckCircle2, XCircle, Loader,
  AlertTriangle, Scale, type LucideIcon,
} from 'lucide-react'

// ── Status ──────────────────────────────────────────────────────────
export type InteractionStatus =
  | 'requested' | 'accepted' | 'in_progress' | 'completed'
  | 'cancelled_by_helper' | 'cancelled_by_helped'
  | 'disputed' | 'resolved'

// ── Status config ───────────────────────────────────────────────────
export interface StatusConfig {
  label: string
  color: string
  icon: LucideIcon
  description: string
  actionable: boolean
}

export const STATUS_CONFIG: Record<InteractionStatus, StatusConfig> = {
  requested:            { label: 'Angefragt',                  color: 'bg-blue-100 text-blue-800',    icon: Clock,           description: 'Wartet auf Antwort des Partners',                        actionable: true },
  accepted:             { label: 'Angenommen',                 color: 'bg-emerald-100 text-emerald-800', icon: CheckCircle,  description: 'Hilfe wurde zugesagt',                                   actionable: true },
  in_progress:          { label: 'In Bearbeitung',             color: 'bg-amber-100 text-amber-800',  icon: Loader,          description: 'Hilfe wird gerade geleistet',                            actionable: true },
  completed:            { label: 'Abgeschlossen',              color: 'bg-green-100 text-green-800',  icon: CheckCircle2,    description: 'Erfolgreich abgeschlossen',                              actionable: false },
  cancelled_by_helper:  { label: 'Vom Helfer abgesagt',        color: 'bg-red-100 text-red-800',      icon: XCircle,         description: 'Der Helfer hat die Interaktion beendet',                 actionable: false },
  cancelled_by_helped:  { label: 'Vom Hilfesuchenden abgesagt', color: 'bg-red-100 text-red-800',     icon: XCircle,         description: 'Der Hilfesuchende hat die Interaktion beendet',          actionable: false },
  disputed:             { label: 'Streitfall',                 color: 'bg-orange-100 text-orange-800', icon: AlertTriangle,   description: 'Es gibt eine Unstimmigkeit – Admin wurde informiert',    actionable: false },
  resolved:             { label: 'Geklaert',                   color: 'bg-gray-100 text-gray-800',    icon: Scale,           description: 'Der Streitfall wurde geklaert',                          actionable: false },
}

// ── Core types ──────────────────────────────────────────────────────
export interface InteractionPartner {
  id: string
  name: string | null
  avatar_url: string | null
  trust_score: number | null
  trust_count: number | null
}

export interface InteractionPost {
  id: string
  title: string | null
  category: string | null
  type: string | null
}

export interface Interaction {
  id: string
  post_id: string | null
  match_id: string | null
  helper_id: string
  helped_id: string | null
  status: InteractionStatus
  message: string | null
  response_message: string | null
  cancel_reason: string | null
  completed_at: string | null
  completed_by: string | null
  completion_notes: string | null
  helper_rated: boolean
  helped_rated: boolean
  rating_requested: boolean
  conversation_id: string | null
  created_at: string
  updated_at: string
  // Joined fields
  post: InteractionPost | null
  partner: InteractionPartner
  myRole: 'helper' | 'helped'
  match_score: number | null
}

export interface InteractionUpdate {
  id: string
  interaction_id: string
  author_id: string
  update_type: string
  content: string | null
  old_status: string | null
  new_status: string | null
  created_at: string
  author_name: string | null
  author_avatar: string | null
}

export interface InteractionFilter {
  role: 'all' | 'helper' | 'helped'
  status: 'all' | 'active' | 'completed' | 'cancelled'
  search: string
}

export interface CreateInteractionInput {
  post_id: string
  target_user_id: string
  message: string
  i_am_helper: boolean
}

export interface InteractionStats {
  total_as_helper: number
  total_as_helped: number
  completed: number
  active: number
  cancelled: number
  disputed: number
  average_completion_hours: number | null
  most_helped_category: string | null
}

export interface InteractionCounts {
  requested: number
  active: number
  awaiting_rating: number
}

// ── Update type labels ──────────────────────────────────────────────
export const UPDATE_TYPE_LABELS: Record<string, string> = {
  created:       'hat die Interaktion erstellt',
  accepted:      'hat angenommen',
  declined:      'hat abgelehnt',
  in_progress:   'hat als gestartet markiert',
  completed:     'hat als abgeschlossen markiert',
  cancelled:     'hat abgesagt',
  disputed:      'hat einen Streitfall gemeldet',
  resolved:      'Streitfall wurde geklaert',
  message:       'hat eine Notiz hinzugefuegt',
  status_change: 'Status geaendert',
}
