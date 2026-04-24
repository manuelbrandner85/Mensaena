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
  FileText, Gift,
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
  { id: 'dashboard', label: 'dashboard', path: '/dashboard', icon: LayoutDashboard },
  { id: 'create', label: 'create', path: '/dashboard/create', icon: PlusCircle, variant: 'highlight' },
  { id: 'notifications', label: 'notifications', path: '/dashboard/notifications', icon: Bell, badgeKey: 'unreadNotifications' },
]

// ── Grouped Navigation (7 categories + admin) ────────────────────────
export const navGroups: NavGroupConfig[] = [
  // ─── 1. KOMMUNIKATION ───────────────────────────────────────
  {
    id: 'communication',
    title: 'groupCommunication',
    icon: MessageCircle,
    items: [
      { id: 'messages', label: 'directMessages', path: '/dashboard/messages', icon: Mail, badgeKey: 'unreadMessages' },
      { id: 'chat', label: 'communityChat', path: '/dashboard/chat', icon: MessageCircle },
      { id: 'matching', label: 'matching', path: '/dashboard/matching', icon: Sparkles, badgeKey: 'suggestedMatches' },
    ],
  },

  // ─── 2. HELFEN & FINDEN ─────────────────────────────────────
  {
    id: 'help',
    title: 'groupHelp',
    icon: Heart,
    items: [
      { id: 'map', label: 'map', path: '/dashboard/map', icon: Map },
      { id: 'posts', label: 'posts', path: '/dashboard/posts', icon: FileText },
      { id: 'organizations', label: 'organizations', path: '/dashboard/organizations', icon: Building2 },
      { id: 'interactions', label: 'interactions', path: '/dashboard/interactions', icon: Handshake, badgeKey: 'interactionRequests' },
    ],
  },

  // ─── 3. NOTFALL & SICHERHEIT ────────────────────────────────
  {
    id: 'emergency',
    title: 'groupEmergency',
    icon: AlertTriangle,
    items: [
      { id: 'crisis', label: 'crisisReports', path: '/dashboard/crisis', icon: AlertTriangle, variant: 'crisis', badgeKey: 'activeCrises' },
      { id: 'mental-support', label: 'mentalSupport', path: '/dashboard/mental-support', icon: Brain },
      { id: 'rescuer', label: 'rescuer', path: '/dashboard/rescuer', icon: LifeBuoy },
    ],
  },

  // ─── 4. GEMEINSCHAFT & GRUPPEN ──────────────────────────────
  {
    id: 'community',
    title: 'groupCommunity',
    icon: Users,
    items: [
      { id: 'community', label: 'community', path: '/dashboard/community', icon: Heart },
      { id: 'groups', label: 'groups', path: '/dashboard/groups', icon: Users2 },
      { id: 'events', label: 'events', path: '/dashboard/events', icon: Calendar },
      { id: 'board', label: 'board', path: '/dashboard/board', icon: StickyNote },
      { id: 'challenges', label: 'challenges', path: '/dashboard/challenges', icon: Trophy },
    ],
  },

  // ─── 5. TEILEN & VERSORGEN ──────────────────────────────────
  {
    id: 'sharing',
    title: 'groupSharing',
    icon: Repeat,
    items: [
      { id: 'sharing', label: 'sharing', path: '/dashboard/sharing', icon: Repeat },
      { id: 'timebank', label: 'timebank', path: '/dashboard/timebank', icon: Clock },
      { id: 'marketplace', label: 'marketplace', path: '/dashboard/marketplace', icon: Store },
      { id: 'supply', label: 'supply', path: '/dashboard/supply', icon: Package },
      { id: 'harvest', label: 'harvest', path: '/dashboard/harvest', icon: Wheat },
    ],
  },

  // ─── 6. WISSEN & ENGAGEMENT ─────────────────────────────────
  {
    id: 'knowledge',
    title: 'groupKnowledge',
    icon: BookOpen,
    items: [
      { id: 'wiki', label: 'wiki', path: '/dashboard/wiki', icon: BookOpen },
      { id: 'knowledge', label: 'education', path: '/dashboard/knowledge', icon: GraduationCap },
      { id: 'skills', label: 'skills', path: '/dashboard/skills', icon: Wrench },
      { id: 'animals', label: 'animals', path: '/dashboard/animals', icon: PawPrint },
    ],
  },

  // ─── 7. MEIN BEREICH ────────────────────────────────────────
  {
    id: 'personal',
    title: 'groupPersonal',
    icon: UserCircle,
    items: [
      { id: 'profile', label: 'profile', path: '/dashboard/profile', icon: User },
      { id: 'invite', label: 'inviteNeighbors', path: '/dashboard/invite', icon: Share2, variant: 'highlight' },
      { id: 'badges', label: 'badges', path: '/dashboard/badges', icon: Award },
      { id: 'housing', label: 'housing', path: '/dashboard/housing', icon: Home },
      { id: 'mobility', label: 'mobility', path: '/dashboard/mobility', icon: Car },
      { id: 'calendar', label: 'calendar', path: '/dashboard/calendar', icon: Calendar },
      { id: 'settings', label: 'settings', path: '/dashboard/settings', icon: Settings },
      { id: 'donate', label: 'donate', path: '/spenden', icon: Gift, variant: 'highlight' },
    ],
  },

  // ─── ADMIN ──────────────────────────────────────────────────
  {
    id: 'admin',
    title: 'groupAdmin',
    icon: ShieldCheck,
    adminOnly: true,
    items: [
      { id: 'admin', label: 'adminDashboard', path: '/dashboard/admin', icon: ShieldCheck },
    ],
  },
]

// ── Bottom Nav Items (mobile, 5 items) ──────────────────────────────
export const bottomNavItems: NavItemConfig[] = [
  { id: 'dashboard', label: 'home', path: '/dashboard', icon: LayoutDashboard },
  { id: 'map', label: 'map', path: '/dashboard/map', icon: Map },
  { id: 'create', label: 'createShort', path: '/dashboard/create', icon: PlusCircle, variant: 'highlight' },
  { id: 'messages', label: 'chat', path: '/dashboard/messages', icon: MessageCircle, badgeKey: 'unreadMessages' },
  { id: 'more', label: 'more', path: '#more', icon: Menu, variant: 'default' },
]
