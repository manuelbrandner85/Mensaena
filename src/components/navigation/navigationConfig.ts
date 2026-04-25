import {
  LayoutDashboard, Map, PlusCircle, MessageCircle, Mail, Bell,
  Calendar, Users, Trophy,
  BookOpen, AlertTriangle,
  User, Settings, ShieldCheck,
  Brain, Home,
  PawPrint, Car, Wrench, Clock, Heart,
  GraduationCap, Store, StickyNote, Users2, LifeBuoy,
  Package, Wheat, Repeat, Briefcase,
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
  { id: 'dashboard', label: 'dashboard', path: '/dashboard', icon: LayoutDashboard },
  { id: 'create', label: 'create', path: '/dashboard/create', icon: PlusCircle, variant: 'highlight' },
  { id: 'notifications', label: 'notifications', path: '/dashboard/notifications', icon: Bell, badgeKey: 'unreadNotifications' },
]

// ── Grouped Navigation ────────────────────────────────────────────────
export const navGroups: NavGroupConfig[] = [

  // ─── 1. KOMMUNIKATION ───────────────────────────────────────
  // Alles rund um direkte & indirekte Kommunikation mit anderen Nutzern
  {
    id: 'communication',
    title: 'groupCommunication',
    icon: MessageCircle,
    items: [
      { id: 'messages',  label: 'directMessages', path: '/dashboard/messages',  icon: Mail,        badgeKey: 'unreadMessages' },
      { id: 'chat',      label: 'communityChat',  path: '/dashboard/chat',      icon: MessageCircle },
      { id: 'matching',  label: 'matching',        path: '/dashboard/matching',  icon: Sparkles,    badgeKey: 'suggestedMatches' },
    ],
  },

  // ─── 2. HELFEN & FINDEN ─────────────────────────────────────
  // Karte, Hilfe-Posts, Organisationen, Vermittlung & Tierhilfe
  {
    id: 'help',
    title: 'groupHelp',
    icon: Heart,
    items: [
      { id: 'map',           label: 'map',           path: '/dashboard/map',           icon: Map },
      { id: 'posts',         label: 'posts',         path: '/dashboard/posts',         icon: FileText },
      { id: 'organizations', label: 'organizations', path: '/dashboard/organizations', icon: Building2 },
      { id: 'interactions',  label: 'interactions',  path: '/dashboard/interactions',  icon: Handshake, badgeKey: 'interactionRequests' },
      { id: 'animals',       label: 'animals',       path: '/dashboard/animals',       icon: PawPrint },
    ],
  },

  // ─── 3. NOTFALL & SICHERHEIT ────────────────────────────────
  // Krisenberichte, psychische Unterstützung – echte Notfallhilfe
  {
    id: 'emergency',
    title: 'groupEmergency',
    icon: AlertTriangle,
    items: [
      { id: 'crisis',         label: 'crisisReports', path: '/dashboard/crisis',         icon: AlertTriangle, variant: 'crisis', badgeKey: 'activeCrises' },
      { id: 'mental-support', label: 'mentalSupport', path: '/dashboard/mental-support', icon: Brain },
    ],
  },

  // ─── 4. GEMEINSCHAFT ────────────────────────────────────────
  // Gruppen, Veranstaltungen, Pinnwand & Challenges
  {
    id: 'community',
    title: 'groupCommunity',
    icon: Users,
    items: [
      { id: 'groups',     label: 'groups',     path: '/dashboard/groups',     icon: Users2 },
      { id: 'events',     label: 'events',     path: '/dashboard/events',     icon: Calendar },
      { id: 'board',      label: 'board',      path: '/dashboard/board',      icon: StickyNote },
      { id: 'challenges', label: 'challenges', path: '/dashboard/challenges', icon: Trophy },
    ],
  },

  // ─── 5. TEILEN & RESSOURCEN ─────────────────────────────────
  // Alles rund um das Teilen von Gegenständen, Zeit, Lebensmitteln,
  // Wohnraum, Mobilität und Ressourcen-Rettung
  {
    id: 'sharing',
    title: 'groupSharing',
    icon: Repeat,
    items: [
      { id: 'sharing',     label: 'sharing',     path: '/dashboard/sharing',     icon: Repeat },
      { id: 'timebank',    label: 'timebank',     path: '/dashboard/timebank',    icon: Clock },
      { id: 'marketplace', label: 'marketplace',  path: '/dashboard/marketplace', icon: Store },
      { id: 'supply',      label: 'supply',       path: '/dashboard/supply',      icon: Package },
      { id: 'harvest',     label: 'harvest',      path: '/dashboard/harvest',     icon: Wheat },
      { id: 'rescuer',     label: 'rescuer',      path: '/dashboard/rescuer',     icon: LifeBuoy },
      { id: 'housing',     label: 'housing',      path: '/dashboard/housing',     icon: Home },
      { id: 'mobility',    label: 'mobility',     path: '/dashboard/mobility',    icon: Car },
      { id: 'jobs',        label: 'jobs',         path: '/dashboard/jobs',        icon: Briefcase },
    ],
  },

  // ─── 6. WISSEN & SKILLS ─────────────────────────────────────
  // Wiki, Bildung, Fähigkeiten – Wissen teilen & lernen
  {
    id: 'knowledge',
    title: 'groupKnowledge',
    icon: BookOpen,
    items: [
      { id: 'wiki',      label: 'wiki',      path: '/dashboard/wiki',      icon: BookOpen },
      { id: 'knowledge', label: 'education', path: '/dashboard/knowledge', icon: GraduationCap },
      { id: 'skills',    label: 'skills',    path: '/dashboard/skills',    icon: Wrench },
    ],
  },

  // ─── 7. MEIN BEREICH ────────────────────────────────────────
  // Profil, persönliche Einstellungen, Kalender & Einladen
  {
    id: 'personal',
    title: 'groupPersonal',
    icon: UserCircle,
    items: [
      { id: 'profile',  label: 'profile',         path: '/dashboard/profile',  icon: User },
      { id: 'invite',   label: 'inviteNeighbors', path: '/dashboard/invite',   icon: Share2, variant: 'highlight' },
      { id: 'badges',   label: 'badges',          path: '/dashboard/badges',   icon: Award },
      { id: 'calendar', label: 'calendar',        path: '/dashboard/calendar', icon: Calendar },
      { id: 'settings', label: 'settings',        path: '/dashboard/settings', icon: Settings },
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
// Reihenfolge: Home → Map → Erstellen (Primäraktion) → Nachrichten → Jobs
// Vollständige Navigation lebt in der linken Sidebar – per ☰-Menü oben
// links erreichbar.
export const bottomNavItems: NavItemConfig[] = [
  { id: 'dashboard', label: 'home',        path: '/dashboard',          icon: LayoutDashboard },
  { id: 'map',       label: 'map',         path: '/dashboard/map',      icon: Map },
  { id: 'create',    label: 'createShort', path: '/dashboard/create',   icon: PlusCircle, variant: 'highlight' },
  { id: 'messages',  label: 'chat',        path: '/dashboard/messages', icon: MessageCircle, badgeKey: 'unreadMessages' },
  { id: 'jobs',      label: 'jobs',        path: '/dashboard/jobs',     icon: Briefcase },
]
