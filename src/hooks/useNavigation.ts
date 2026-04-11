'use client'

import { useMemo } from 'react'
import { usePathname } from 'next/navigation'

interface Breadcrumb {
  label: string
  href: string
}

const PAGE_TITLES: Record<string, string> = {
  '/dashboard': 'Dashboard',
  '/dashboard/map': 'Karte',
  '/dashboard/create': 'Beitrag erstellen',
  '/dashboard/posts': 'Alle Beiträge',
  '/dashboard/chat': 'Nachrichten',
  '/dashboard/profile': 'Mein Profil',
  '/dashboard/settings': 'Einstellungen',
  '/dashboard/notifications': 'Benachrichtigungen',
  '/dashboard/calendar': 'Kalender',
  '/dashboard/community': 'Community',
  '/dashboard/crisis': 'Krisenhilfe',
  '/dashboard/organizations': 'Hilfsorganisationen',
  '/dashboard/rescuer': 'Retter-System',
  '/dashboard/mental-support': 'Mentale Unterstützung',
  '/dashboard/supply': 'Regionale Versorgung',
  '/dashboard/harvest': 'Erntehilfe',
  '/dashboard/housing': 'Wohnen & Alltag',
  '/dashboard/animals': 'Tiere',
  '/dashboard/mobility': 'Mobilität & Fahrten',
  '/dashboard/skills': 'Skill-Netzwerk',
  '/dashboard/timebank': 'Zeitbank',
  '/dashboard/sharing': 'Teilen & Tauschen',
  '/dashboard/knowledge': 'Bildung & Wissen',
  '/dashboard/admin': 'Admin-Dashboard',
  '/dashboard/marketplace': 'Marktplatz',
  '/dashboard/events': 'Veranstaltungen',
  '/dashboard/groups': 'Gruppen',
  '/dashboard/wiki': 'Wissensbasis',
  '/dashboard/board': 'Pinnwand',
  '/dashboard/challenges': 'Challenges',
  '/dashboard/badges': 'Badges & Erfolge',
  '/dashboard/matching': 'Matching',
  '/dashboard/interactions': 'Interaktionen',
  '/dashboard/farm-listings': 'Regionale Erzeuger',
  '/dashboard/search': 'Suche',
}

export function useNavigation() {
  const currentPath = usePathname()

  const isActive = (path: string): boolean => {
    if (path === '/dashboard') return currentPath === '/dashboard'
    return currentPath.startsWith(path)
  }

  const isExactActive = (path: string): boolean => {
    return currentPath === path
  }

  const pageTitle = useMemo(() => {
    // Exact match first
    if (PAGE_TITLES[currentPath]) return PAGE_TITLES[currentPath]
    // Check if current path starts with a known path (for sub-routes like /dashboard/posts/[id])
    const sorted = Object.keys(PAGE_TITLES).sort((a, b) => b.length - a.length)
    for (const path of sorted) {
      if (currentPath.startsWith(path) && path !== '/dashboard') {
        return PAGE_TITLES[path]
      }
    }
    return 'Mensaena'
  }, [currentPath])

  const breadcrumbs = useMemo((): Breadcrumb[] => {
    const crumbs: Breadcrumb[] = [{ label: 'Home', href: '/dashboard' }]
    if (currentPath === '/dashboard') return crumbs

    // Split the path into segments after /dashboard/
    const segments = currentPath.replace('/dashboard/', '').split('/')
    let builtPath = '/dashboard'

    for (const segment of segments) {
      builtPath += `/${segment}`
      const label = PAGE_TITLES[builtPath] || decodeURIComponent(segment)
      crumbs.push({ label, href: builtPath })
    }

    return crumbs
  }, [currentPath])

  return {
    currentPath,
    isActive,
    isExactActive,
    pageTitle,
    breadcrumbs,
  }
}
