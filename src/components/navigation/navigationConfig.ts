import {
  LayoutDashboard, Map, PlusCircle, MessageCircle, Bell,
  Calendar, Users, Trophy,
  BookOpen, AlertTriangle,
  User, Settings, ShieldCheck,
  Brain, Home, Menu,
  PawPrint, Car, Wrench, Clock, Heart,
  GraduationCap, Store, StickyNote, Users2, LifeBuoy,
  Package, Wheat, Repeat, LayoutGrid, ShoppingBag,
  UserCircle,
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
  { id: 'map', label: 'Karte', path: '/dashboard/map', icon: Map },
  { id: 'create', label: 'Beitrag erstellen', path: '/dashboard/create', icon: PlusCircle, variant: 'highlight' },
  { id: 'chat', label: 'Nachrichten', path: '/dashboard/chat', icon: MessageCircle, badgeKey: 'unreadMessages' },
  { id: 'notifications', label: 'Benachrichtigungen', path: '/dashboard/notifications', icon: Bell, badgeKey: 'unreadNotifications' },
]

// ── Grouped Navigation (6 categories + admin) ────────────────────────
export const navGroups: NavGroupConfig[] = [
  {
    id: 'emergency',
    title: 'Notfall & Krise',
    icon: AlertTriangle,
    items: [
      { id: 'crisis', label: 'Krisenmeldungen', path: '/dashboard/crisis', icon: AlertTriangle, variant: 'crisis', badgeKey: 'activeCrises' },
      { id: 'mental-support', label: 'Mentale Unterstützung', path: '/dashboard/mental-support', icon: Brain },
      { id: 'rescuer', label: 'Rettungsnetz', path: '/dashboard/rescuer', icon: LifeBuoy },
    ],
  },
  {
    id: 'supply',
    title: 'Versorgung & Alltag',
    icon: ShoppingBag,
    items: [
      { id: 'housing', label: 'Wohnen & Alltag', path: '/dashboard/housing', icon: Home },
      { id: 'mobility', label: 'Mobilität', path: '/dashboard/mobility', icon: Car },
      { id: 'harvest', label: 'Ernte & Hofladen', path: '/dashboard/harvest', icon: Wheat },
      { id: 'supply', label: 'Versorgung', path: '/dashboard/supply', icon: Package },
    ],
  },
  {
    id: 'community',
    title: 'Gemeinschaft',
    icon: Users,
    items: [
      { id: 'animals', label: 'Tierhilfe', path: '/dashboard/animals', icon: PawPrint },
      { id: 'community', label: 'Community', path: '/dashboard/community', icon: Heart },
      { id: 'sharing', label: 'Teilen & Tauschen', path: '/dashboard/sharing', icon: Repeat },
      { id: 'timebank', label: 'Zeitbank', path: '/dashboard/timebank', icon: Clock },
      { id: 'skills', label: 'Skill-Netzwerk', path: '/dashboard/skills', icon: Wrench },
    ],
  },
  {
    id: 'groups',
    title: 'Gruppen & Mehr',
    icon: LayoutGrid,
    items: [
      { id: 'groups', label: 'Gruppen', path: '/dashboard/groups', icon: Users2 },
      { id: 'board', label: 'Schwarzes Brett', path: '/dashboard/board', icon: StickyNote },
      { id: 'events', label: 'Events', path: '/dashboard/events', icon: Calendar },
      { id: 'marketplace', label: 'Marktplatz', path: '/dashboard/marketplace', icon: Store },
      { id: 'challenges', label: 'Challenges', path: '/dashboard/challenges', icon: Trophy },
    ],
  },
  {
    id: 'knowledge',
    title: 'Wissen & Hilfe',
    icon: BookOpen,
    items: [
      { id: 'knowledge', label: 'Bildung & Wissen', path: '/dashboard/knowledge', icon: GraduationCap },
      { id: 'wiki', label: 'Wiki', path: '/dashboard/wiki', icon: BookOpen },
    ],
  },
  {
    id: 'personal',
    title: 'Persönlich',
    icon: UserCircle,
    items: [
      { id: 'profile', label: 'Profil', path: '/dashboard/profile', icon: User },
      { id: 'settings', label: 'Einstellungen', path: '/dashboard/settings', icon: Settings },
    ],
  },

  // ── Admin (visible for admin and moderator roles) ──
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

// ── Bottom Nav Items (mobile, 4 items + Mehr) ─────────────────────────
export const bottomNavItems: NavItemConfig[] = [
  { id: 'dashboard', label: 'Home', path: '/dashboard', icon: LayoutDashboard },
  { id: 'map', label: 'Karte', path: '/dashboard/map', icon: Map },
  { id: 'create', label: 'Erstellen', path: '/dashboard/create', icon: PlusCircle, variant: 'highlight' },
  { id: 'chat', label: 'Chat', path: '/dashboard/chat', icon: MessageCircle, badgeKey: 'unreadMessages' },
  { id: 'more', label: 'Mehr', path: '#more', icon: Menu, variant: 'default' },
]
