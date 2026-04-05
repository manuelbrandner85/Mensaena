import {
  LayoutDashboard, Map, PlusCircle, MessageCircle, Bell,
  Clipboard, Calendar, Users, ShoppingBag, Trophy,
  BookOpen, Building2, AlertTriangle,
  User, Settings, ShieldCheck,
  FileText, Siren, Brain, Wheat, Sprout, Home,
  PawPrint, Car, Wrench, Clock, Shuffle,
  type LucideIcon,
} from 'lucide-react'

export interface NavItemConfig {
  id: string
  label: string
  path: string
  icon: LucideIcon
  /** If set, shows a badge from store (key name) */
  badgeKey?: 'unreadMessages' | 'unreadNotifications'
  /** "Bald" tag for upcoming features – triggers toast, no navigation, opacity-75 */
  comingSoon?: boolean
  /** Special styling (e.g., crisis items) */
  variant?: 'default' | 'crisis' | 'highlight'
}

export interface NavGroupConfig {
  id: string
  title: string
  items: NavItemConfig[]
  /** Only visible for admins */
  adminOnly?: boolean
}

// ── Main Navigation (always visible, no group header) ──────────────────
export const mainNavItems: NavItemConfig[] = [
  { id: 'dashboard', label: 'Dashboard', path: '/dashboard', icon: LayoutDashboard },
  { id: 'map', label: 'Karte', path: '/dashboard/map', icon: Map },
  { id: 'create', label: 'Beitrag erstellen', path: '/dashboard/create', icon: PlusCircle, variant: 'highlight' },
  { id: 'chat', label: 'Nachrichten', path: '/dashboard/chat', icon: MessageCircle, badgeKey: 'unreadMessages' },
  { id: 'notifications', label: 'Benachrichtigungen', path: '/dashboard/notifications', icon: Bell, badgeKey: 'unreadNotifications' },
]

// ── Grouped Navigation ─────────────────────────────────────────────────
export const navGroups: NavGroupConfig[] = [
  // ── Existing pages that need to stay navigable ──
  {
    id: 'overview',
    title: 'Übersicht',
    items: [
      { id: 'posts', label: 'Alle Beiträge', path: '/dashboard/posts', icon: FileText },
      { id: 'calendar', label: 'Kalender', path: '/dashboard/calendar', icon: Calendar },
    ],
  },
  {
    id: 'emergency',
    title: 'Notfall & Krise',
    items: [
      { id: 'crisis', label: 'Krisenhilfe', path: '/dashboard/crisis', icon: Siren, variant: 'crisis' },
      { id: 'organizations', label: 'Hilfsorganisationen', path: '/dashboard/organizations', icon: Building2 },
      { id: 'rescuer', label: 'Retter-System', path: '/dashboard/rescuer', icon: AlertTriangle },
      { id: 'mental-support', label: 'Mentale Unterstützung', path: '/dashboard/mental-support', icon: Brain },
    ],
  },
  {
    id: 'supply',
    title: 'Versorgung & Alltag',
    items: [
      { id: 'supply', label: 'Regionale Versorgung', path: '/dashboard/supply', icon: Wheat },
      { id: 'harvest', label: 'Erntehilfe', path: '/dashboard/harvest', icon: Sprout },
      { id: 'housing', label: 'Wohnen & Alltag', path: '/dashboard/housing', icon: Home },
      { id: 'animals', label: 'Tiere', path: '/dashboard/animals', icon: PawPrint },
      { id: 'mobility', label: 'Mobilität & Fahrten', path: '/dashboard/mobility', icon: Car },
    ],
  },
  {
    id: 'gemeinschaft',
    title: 'Gemeinschaft',
    items: [
      { id: 'community', label: 'Community', path: '/dashboard/community', icon: Users },
      { id: 'skills', label: 'Skill-Netzwerk', path: '/dashboard/skills', icon: Wrench },
      { id: 'timebank', label: 'Zeitbank', path: '/dashboard/timebank', icon: Clock },
      { id: 'sharing', label: 'Teilen & Tauschen', path: '/dashboard/sharing', icon: Shuffle },
      { id: 'knowledge', label: 'Bildung & Wissen', path: '/dashboard/knowledge', icon: BookOpen },
    ],
  },

  // ── "Community" group – planned, all tagged "Bald" ──
  {
    id: 'community-soon',
    title: 'Community',
    items: [
      { id: 'board', label: 'Pinnwand', path: '/dashboard/board', icon: Clipboard, comingSoon: true },
      { id: 'events', label: 'Veranstaltungen', path: '/dashboard/events', icon: Calendar, comingSoon: true },
      { id: 'groups', label: 'Gruppen', path: '/dashboard/groups', icon: Users, comingSoon: true },
      { id: 'marketplace', label: 'Marktplatz', path: '/dashboard/marketplace', icon: ShoppingBag, comingSoon: true },
      { id: 'challenges', label: 'Challenges', path: '/dashboard/challenges', icon: Trophy, comingSoon: true },
    ],
  },

  // ── "Wissen & Hilfe" group – planned, all tagged "Bald" ──
  {
    id: 'wissen-hilfe',
    title: 'Wissen & Hilfe',
    items: [
      { id: 'wiki', label: 'Wissensbasis', path: '/dashboard/wiki', icon: BookOpen, comingSoon: true },
    ],
  },

  // ── Persönlich ──
  {
    id: 'personal',
    title: 'Persönlich',
    items: [
      { id: 'profile', label: 'Mein Profil', path: '/dashboard/profile', icon: User },
      { id: 'settings', label: 'Einstellungen', path: '/dashboard/settings', icon: Settings },
    ],
  },

  // ── Admin (visible only if profile.role === 'admin') ──
  {
    id: 'admin',
    title: 'Administration',
    adminOnly: true,
    items: [
      { id: 'admin', label: 'Admin-Dashboard', path: '/dashboard/admin', icon: ShieldCheck },
    ],
  },
]

// ── Bottom Nav Items (mobile, 5 items) ─────────────────────────────────
export const bottomNavItems: NavItemConfig[] = [
  { id: 'dashboard', label: 'Home', path: '/dashboard', icon: LayoutDashboard },
  { id: 'map', label: 'Karte', path: '/dashboard/map', icon: Map },
  { id: 'create', label: 'Erstellen', path: '/dashboard/create', icon: PlusCircle, variant: 'highlight' },
  { id: 'chat', label: 'Chat', path: '/dashboard/chat', icon: MessageCircle, badgeKey: 'unreadMessages' },
  { id: 'notifications', label: 'Meldungen', path: '/dashboard/notifications', icon: Bell, badgeKey: 'unreadNotifications' },
]
