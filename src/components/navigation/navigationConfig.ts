import {
  LayoutDashboard, Map, PlusCircle, MessageCircle, Mail, Bell,
  Calendar, Users, Trophy,
  BookOpen, AlertTriangle,
  User, Settings, ShieldCheck,
  Brain, Home, Menu,
  PawPrint, Car, Wrench, Clock, Heart,
  GraduationCap, Store, StickyNote, Users2, LifeBuoy,
  Package, Wheat, Repeat, LayoutGrid, ShoppingBag,
  UserCircle, Building2, Handshake, Sparkles, Award, Share2,
  FileText,
  type LucideIcon,
} from 'lucide-react'

export interface NavItemConfig {
  id: string
  label: string
  path: string
  icon: LucideIcon
  /** If set, shows a badge from store (key name) */
  badgeKey?: 'unreadMessages' | 'unreadNotifications' | 'activeCrises' | 'suggestedMatches' | 'interactionRequests'
  /** "Bald" tag for upcoming features – triggers toast, no navigation, opacity-75 */
  comingSoon?: boolean
  /** Special styling (e.g., crisis items) */
  variant?: 'default' | 'crisis' | 'highlight'
}

export interface NavGroupConfig {
  id: string
  title: string
  icon?: LucideIcon
  items: NavItemConfig[]
  /** Only visible for admins */
  adminOnly?: boolean
}

// ── Main Navigation (always visible, no group header) ──────────────────
export const mainNavItems: NavItemConfig[] = [
  { id: 'dashboard', label: 'Dashboard', path: '/dashboard', icon: LayoutDashboard },
  { id: 'create', label: 'Beitrag erstellen', path: '/dashboard/create', icon: PlusCircle, variant: 'highlight' },
  { id: 'notifications', label: 'Benachrichtigungen', path: '/dashboard/notifications', icon: Bell, badgeKey: 'unreadNotifications' },
]

// ── Grouped Navigation (7 categories + admin) ────────────────────────
export const navGroups: NavGroupConfig[] = [
  // ─── 1. KOMMUNIKATION ───────────────────────────────────────
  {
    id: 'communication',
    title: 'Kommunikation',
    icon: MessageCircle,
    items: [
      { id: 'messages', label: 'Direktnachrichten', path: '/dashboard/messages', icon: Mail, badgeKey: 'unreadMessages' },
      { id: 'chat', label: 'Community-Chat', path: '/dashboard/chat', icon: MessageCircle },
      { id: 'matching', label: 'Matching', path: '/dashboard/matching', icon: Sparkles, badgeKey: 'suggestedMatches' },
    ],
  },

  // ─── 2. HELFEN & FINDEN ─────────────────────────────────────
  {
    id: 'help',
    title: 'Helfen & Finden',
    icon: Heart,
    items: [
      { id: 'map', label: 'Karte', path: '/dashboard/map', icon: Map },
      { id: 'posts', label: 'Beiträge', path: '/dashboard/posts', icon: FileText },
      { id: 'organizations', label: 'Hilfsorganisationen', path: '/dashboard/organizations', icon: Building2 },
      { id: 'interactions', label: 'Interaktionen', path: '/dashboard/interactions', icon: Handshake, badgeKey: 'interactionRequests' },
    ],
  },

  // ─── 3. NOTFALL & SICHERHEIT ────────────────────────────────
  {
    id: 'emergency',
    title: 'Notfall & Sicherheit',
    icon: AlertTriangle,
    items: [
      { id: 'crisis', label: 'Krisenmeldungen', path: '/dashboard/crisis', icon: AlertTriangle, variant: 'crisis', badgeKey: 'activeCrises' },
      { id: 'mental-support', label: 'Mentale Unterstützung', path: '/dashboard/mental-support', icon: Brain },
      { id: 'rescuer', label: 'Rettungsnetz', path: '/dashboard/rescuer', icon: LifeBuoy },
    ],
  },

  // ─── 4. GEMEINSCHAFT & GRUPPEN ──────────────────────────────
  {
    id: 'community',
    title: 'Gemeinschaft',
    icon: Users,
    items: [
      { id: 'community', label: 'Community', path: '/dashboard/community', icon: Heart },
      { id: 'groups', label: 'Gruppen', path: '/dashboard/groups', icon: Users2 },
      { id: 'events', label: 'Events', path: '/dashboard/events', icon: Calendar },
      { id: 'board', label: 'Schwarzes Brett', path: '/dashboard/board', icon: StickyNote },
      { id: 'challenges', label: 'Challenges', path: '/dashboard/challenges', icon: Trophy },
    ],
  },

  // ─── 5. TEILEN & VERSORGEN ──────────────────────────────────
  {
    id: 'sharing',
    title: 'Teilen & Versorgen',
    icon: Repeat,
    items: [
      { id: 'sharing', label: 'Teilen & Tauschen', path: '/dashboard/sharing', icon: Repeat },
      { id: 'timebank', label: 'Zeitbank', path: '/dashboard/timebank', icon: Clock },
      { id: 'marketplace', label: 'Marktplatz', path: '/dashboard/marketplace', icon: Store },
      { id: 'supply', label: 'Regionale Versorgung', path: '/dashboard/supply', icon: Package },
      { id: 'harvest', label: 'Ernte & Hofladen', path: '/dashboard/harvest', icon: Wheat },
    ],
  },

  // ─── 6. WISSEN & ENGAGEMENT ─────────────────────────────────
  {
    id: 'knowledge',
    title: 'Wissen & Engagement',
    icon: BookOpen,
    items: [
      { id: 'wiki', label: 'Wiki', path: '/dashboard/wiki', icon: BookOpen },
      { id: 'knowledge', label: 'Bildung & Kurse', path: '/dashboard/knowledge', icon: GraduationCap },
      { id: 'skills', label: 'Skill-Netzwerk', path: '/dashboard/skills', icon: Wrench },
      { id: 'animals', label: 'Tierhilfe', path: '/dashboard/animals', icon: PawPrint },
    ],
  },

  // ─── 7. MEIN BEREICH ────────────────────────────────────────
  {
    id: 'personal',
    title: 'Mein Bereich',
    icon: UserCircle,
    items: [
      { id: 'profile', label: 'Profil', path: '/dashboard/profile', icon: User },
      { id: 'invite', label: 'Nachbarn einladen', path: '/dashboard/invite', icon: Share2, variant: 'highlight' },
      { id: 'badges', label: 'Badges', path: '/dashboard/badges', icon: Award },
      { id: 'housing', label: 'Wohnen', path: '/dashboard/housing', icon: Home },
      { id: 'mobility', label: 'Mobilität', path: '/dashboard/mobility', icon: Car },
      { id: 'calendar', label: 'Kalender', path: '/dashboard/calendar', icon: Calendar },
      { id: 'settings', label: 'Einstellungen', path: '/dashboard/settings', icon: Settings },
    ],
  },

  // ─── ADMIN ──────────────────────────────────────────────────
  {
    id: 'admin',
    title: 'Administration',
    icon: ShieldCheck,
    adminOnly: true,
    items: [
      { id: 'admin', label: 'Admin-Dashboard', path: '/dashboard/admin', icon: ShieldCheck },
    ],
  },
]

// ── Bottom Nav Items (mobile, 5 items) ──────────────────────────────
export const bottomNavItems: NavItemConfig[] = [
  { id: 'dashboard', label: 'Home', path: '/dashboard', icon: LayoutDashboard },
  { id: 'map', label: 'Karte', path: '/dashboard/map', icon: Map },
  { id: 'create', label: 'Erstellen', path: '/dashboard/create', icon: PlusCircle, variant: 'highlight' },
  { id: 'messages', label: 'Chat', path: '/dashboard/messages', icon: MessageCircle, badgeKey: 'unreadMessages' },
  { id: 'more', label: 'Mehr', path: '#more', icon: Menu, variant: 'default' },
]
