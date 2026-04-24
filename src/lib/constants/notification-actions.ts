export interface NotificationAction {
  label: string
  emoji: string
}

export const NOTIFICATION_ACTIONS: Record<string, NotificationAction> = {
  new_post:               { label: 'Anschauen',           emoji: '👀' },
  interaction_completed:  { label: 'Details ansehen',     emoji: '🤝' },
  trust_rating:           { label: 'Bewertung ansehen',   emoji: '⭐' },
  new_neighbor:           { label: 'Begrüßen',            emoji: '👋' },
  event_upcoming:         { label: 'Teilnehmen',          emoji: '📅' },
  crisis_alert:           { label: 'Krisenmodus öffnen',  emoji: '🆘' },
  new_message:            { label: 'Antworten',           emoji: '💬' },
  animal_alert:           { label: 'Hast du es gesehen?', emoji: '🐾' },
}
