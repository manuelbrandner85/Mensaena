'use client'

import { useEffect, useState, useCallback, useSyncExternalStore } from 'react'

/**
 * Mensaena Feature Flags
 * ----------------------
 * Zentrales Registry für alle neuen Modul-Features. Jeder Eintrag ist eine
 * Feature-Toggle, die per localStorage pro Browser persistiert wird. Das
 * erlaubt Opt-In/Opt-Out aus der Settings-Seite heraus, ohne DB-Migrations.
 */

export interface FeatureFlag {
  key: string
  module: string
  label: string
  description: string
  defaultEnabled: boolean
}

export const FEATURE_FLAGS = [
  // Hilfe & Support
  { key: 'animals_food_tracker',       module: 'animals',        label: 'Futter-Spenden-Tracker',       description: 'Nachbarn tragen ein, was fürs Tier gerade fehlt.',                defaultEnabled: true },
  { key: 'crisis_silent_alarm',        module: 'crisis',         label: 'Stiller Alarm-Button',         description: 'Standort-Weitergabe an Vertrauenskontakte in einem Klick.',       defaultEnabled: true },
  { key: 'mental_support_queue',       module: 'mental-support', label: 'Anonyme Reden-Queue',          description: '„Jemand zum Reden"-Warteschlange mit Matching.',                  defaultEnabled: true },
  { key: 'rescuer_pager',              module: 'rescuer',        label: 'Ersthelfer-Pager',             description: 'Benachrichtigt Ersthelfer in der Nähe bei Notfällen.',            defaultEnabled: true },

  // Community & Soziales
  { key: 'board_expiry',               module: 'board',          label: 'Ablaufdatum für Einträge',     description: 'Einträge am schwarzen Brett mit automatischem Ablauf.',           defaultEnabled: true },
  { key: 'community_voting',           module: 'community',      label: 'Nachbar des Monats',           description: 'Voting für die aktivsten Helfer der Nachbarschaft.',              defaultEnabled: true },
  { key: 'events_carpooling',          module: 'events',         label: 'Event-Carpooling',             description: 'Mitfahrgelegenheiten zum Event organisieren.',                    defaultEnabled: true },
  { key: 'groups_private_chats',       module: 'groups',         label: 'Private Gruppen-Chats',        description: 'Moderierte private Chats innerhalb einer Gruppe.',               defaultEnabled: true },
  { key: 'posts_reactions',            module: 'posts',          label: 'Dank-Reaktionen',              description: 'Reaktionen wie Danke, Herz, Hilfreich statt nur Likes.',          defaultEnabled: true },
  { key: 'chat_voice_messages',        module: 'chat',           label: 'Sprachnachrichten',            description: 'Kurze Sprachnachrichten bis 60 Sekunden aufnehmen.',              defaultEnabled: true },

  // Austausch & Ressourcen
  { key: 'marketplace_reservation',    module: 'marketplace',    label: 'Reservierungs-Queue',          description: 'Warteschlange für kostenlos abzugebende Artikel.',                defaultEnabled: true },
  { key: 'sharing_lending_calendar',   module: 'sharing',        label: 'Leih-Kalender',                description: 'Kalender für Werkzeug-Verleih mit optionalem Pfand.',             defaultEnabled: true },
  { key: 'harvest_fruit_map',          module: 'harvest',        label: 'Obstbaum-Karte',               description: 'Karte mit reifem Obst, das gepflückt werden darf.',               defaultEnabled: true },
  { key: 'supply_emergency_swap',      module: 'supply',         label: 'Notvorrats-Tausch',            description: 'Schneller Tausch von Grundlebensmitteln und Batterien.',          defaultEnabled: true },
  { key: 'timebank_transfer',          module: 'timebank',       label: 'Stunden-Transfer',             description: 'Stunden zwischen Nachbarn übertragen.',                           defaultEnabled: true },

  // Wissen & Lernen
  { key: 'knowledge_bookmarks',        module: 'knowledge',      label: 'Kurz-Tutorials',               description: 'Tutorials unter 3 Min. mit Bookmark-Funktion.',                   defaultEnabled: true },
  { key: 'wiki_local_entries',         module: 'wiki',           label: 'Lokales Nachbarschafts-Wiki',  description: 'Einträge zu Müllabfuhr, Ärzten und örtlichen Infos.',             defaultEnabled: true },
  { key: 'skills_matching',            module: 'skills',         label: 'Skill-Matching',               description: '„Wer kann mir X beibringen?"-Anfragen.',                          defaultEnabled: true },
  { key: 'challenges_weekly',          module: 'challenges',     label: 'Wöchentliche Mini-Challenges', description: 'Kleine Aufgaben zur Stärkung der Nachbarschaft.',                 defaultEnabled: true },
  { key: 'badges_seasonal',            module: 'badges',         label: 'Saison-Abzeichen',             description: 'Besondere Abzeichen für Frühling, Sommer, Herbst, Winter.',       defaultEnabled: true },

  // Alltag & Organisation
  { key: 'calendar_shared',            module: 'calendar',       label: 'Geteilter Nachbarschafts-Kalender', description: 'Gemeinsame Termine mit Nachbarn teilen.',                    defaultEnabled: true },
  { key: 'map_activity_heatmap',       module: 'map',            label: 'Aktivitäts-Heatmap',           description: 'Heatmap zeigt, wo gerade was los ist.',                           defaultEnabled: true },
  { key: 'housing_room_share',         module: 'housing',        label: 'WG-Zimmer-Weitergabe',         description: 'Zimmer innerhalb der Nachbarschaft weitergeben.',                 defaultEnabled: true },
  { key: 'mobility_cargo_bike',        module: 'mobility',       label: 'Lastenrad-Slots',              description: 'Buchungs-Slots für gemeinsame Lastenräder.',                      defaultEnabled: true },
  { key: 'matching_interests',         module: 'matching',       label: 'Interessen-Matching',          description: 'Passende Nachbarn mit gleichen Interessen finden.',               defaultEnabled: true },
  { key: 'interactions_reminder',      module: 'interactions',   label: '„Wieder melden"-Erinnerung',   description: 'Erinnerung, sich später wieder bei Kontakten zu melden.',         defaultEnabled: true },

  // Organisation & Admin
  { key: 'organizations_invite',       module: 'organizations',  label: 'Vereins-Einladungen',          description: 'Einladungs-Links für Vereins-Mitglieder.',                        defaultEnabled: true },
  { key: 'admin_moderation_queue',     module: 'admin',          label: 'Moderations-Queue',            description: 'Gemeldete Inhalte an einem Ort bearbeiten.',                      defaultEnabled: true },
  { key: 'create_templates',           module: 'create',         label: 'Post-Vorlagen',                description: 'Vorlagen-Bibliothek für häufige Beitrags-Typen.',                  defaultEnabled: true },
  { key: 'profile_offer_seek_tags',    module: 'profile',        label: '„Biete / Suche"-Tags',         description: 'Tags für Angebote und Gesuche auf dem Profil.',                   defaultEnabled: true },
  { key: 'settings_quiet_hours',       module: 'settings',       label: 'Ruhezeiten',                   description: 'Notifications in festgelegten Zeitfenstern stumm schalten.',      defaultEnabled: true },
  { key: 'notifications_digest',       module: 'notifications',  label: 'Notification-Digest',          description: 'Benachrichtigungen alle 2h gebündelt statt sofort.',              defaultEnabled: true },
] as const satisfies readonly FeatureFlag[]

export type FeatureKey = (typeof FEATURE_FLAGS)[number]['key']

const STORAGE_KEY = 'mensaena:feature-flags'

function readStore(): Record<string, boolean> {
  if (typeof window === 'undefined') return {}
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY)
    return raw ? (JSON.parse(raw) as Record<string, boolean>) : {}
  } catch {
    return {}
  }
}

function writeStore(store: Record<string, boolean>) {
  if (typeof window === 'undefined') return
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(store))
    window.dispatchEvent(new CustomEvent('mensaena:feature-flags-changed'))
  } catch {
    /* ignore quota errors */
  }
}

export function isFeatureEnabled(key: FeatureKey): boolean {
  const flag = FEATURE_FLAGS.find(f => f.key === key)
  if (!flag) return false
  const store = readStore()
  return store[key] ?? flag.defaultEnabled
}

export function setFeatureEnabled(key: FeatureKey, enabled: boolean) {
  const store = readStore()
  store[key] = enabled
  writeStore(store)
}

function subscribe(cb: () => void): () => void {
  if (typeof window === 'undefined') return () => {}
  const handler = () => cb()
  window.addEventListener('mensaena:feature-flags-changed', handler)
  window.addEventListener('storage', handler)
  return () => {
    window.removeEventListener('mensaena:feature-flags-changed', handler)
    window.removeEventListener('storage', handler)
  }
}

export function useFeatureFlag(key: FeatureKey): [boolean, (v: boolean) => void] {
  const flag = FEATURE_FLAGS.find(f => f.key === key)
  const fallback = flag?.defaultEnabled ?? false

  const getSnapshot = useCallback(() => {
    const store = readStore()
    return store[key] ?? fallback
  }, [key, fallback])

  const getServerSnapshot = useCallback(() => fallback, [fallback])

  const enabled = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot)

  const setEnabled = useCallback(
    (v: boolean) => setFeatureEnabled(key, v),
    [key],
  )

  return [enabled, setEnabled]
}

/**
 * Simple hook variant that only mounts content after hydration, to avoid
 * SSR/CSR mismatch when localStorage differs from the default.
 */
export function useHydratedFeatureFlag(key: FeatureKey): boolean {
  const [enabled] = useFeatureFlag(key)
  const [mounted, setMounted] = useState(false)
  useEffect(() => { setMounted(true) }, [])
  if (!mounted) {
    const flag = FEATURE_FLAGS.find(f => f.key === key)
    return flag?.defaultEnabled ?? false
  }
  return enabled
}
