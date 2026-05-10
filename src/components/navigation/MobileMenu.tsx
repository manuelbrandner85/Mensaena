'use client'

import { useEffect, useState, useMemo, useCallback } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { X, LogOut, Zap, Search, ChevronRight, User, Settings, Shield, MessageCircle, Bell, Globe } from 'lucide-react'
import LanguageSwitcher from '@/components/shared/LanguageSwitcher'
import { useRouter, usePathname } from 'next/navigation'
import { useTranslations } from 'next-intl'
import toast from 'react-hot-toast'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import { useNavigationStore } from '@/store/useNavigationStore'
import { useNavigation } from '@/hooks/useNavigation'
import { mainNavItems, navGroups, type NavItemConfig } from './navigationConfig'

interface MobileMenuProps {
  unreadMessages: number
  unreadNotifications: number
  activeCrises: number
  suggestedMatches: number
  interactionRequests?: number
  isAdmin: boolean
  displayName: string
  email: string
  avatarUrl?: string | null
}

export default function MobileMenu({ unreadMessages, unreadNotifications, activeCrises, suggestedMatches, interactionRequests = 0, isAdmin, displayName, email, avatarUrl }: MobileMenuProps) {
  const t = useTranslations('nav')
  const { mobileMenuOpen, closeMobileMenu } = useNavigationStore()
  const { isActive } = useNavigation()
  const router = useRouter()
  const pathname = usePathname()
  const [searchQuery, setSearchQuery] = useState('')
  const [collapsedGroups, setCollapsedGroups] = useState<Record<string, boolean>>({})

  // Close menu on route change
  useEffect(() => { closeMobileMenu() }, [pathname, closeMobileMenu])

  // Lock body scroll
  useEffect(() => {
    document.body.style.overflow = mobileMenuOpen ? 'hidden' : ''
    return () => { document.body.style.overflow = '' }
  }, [mobileMenuOpen])

  // Reset search on close
  useEffect(() => {
    if (!mobileMenuOpen) setSearchQuery('')
  }, [mobileMenuOpen])

  // Close on Escape key
  useEffect(() => {
    if (!mobileMenuOpen) return
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') closeMobileMenu()
    }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [mobileMenuOpen, closeMobileMenu])

  const getBadge = (badgeKey?: string): number | undefined => {
    if (badgeKey === 'unreadMessages') return unreadMessages || undefined
    if (badgeKey === 'unreadNotifications') return unreadNotifications || undefined
    if (badgeKey === 'activeCrises') return activeCrises || undefined
    if (badgeKey === 'suggestedMatches') return suggestedMatches || undefined
    if (badgeKey === 'interactionRequests') return interactionRequests || undefined
    return undefined
  }

  const handleLogout = async () => {
    closeMobileMenu()
    const supabase = createClient()
    await supabase.auth.signOut()
    toast.success(t('logoutSuccess'))
    router.push('/')
  }

  const handleComingSoon = (e: React.MouseEvent) => {
    e.preventDefault()
    toast(t('comingSoonToast'), { icon: '🔜' })
  }

  const toggleGroup = useCallback((id: string) => {
    setCollapsedGroups(prev => ({ ...prev, [id]: !prev[id] }))
  }, [])

  // Build flat list for search
  const allItems = useMemo(() => {
    const items: (NavItemConfig & { group?: string })[] = mainNavItems.map(i => ({ ...i }))
    navGroups.filter(g => !g.adminOnly || isAdmin).forEach(g => {
      g.items.forEach(i => items.push({ ...i, group: g.title }))
    })
    return items
  }, [isAdmin])

  const filteredItems = useMemo(() => {
    if (!searchQuery.trim()) return null
    const q = searchQuery.toLowerCase()
    return allItems.filter(i => {
      const labelText = t(i.label as Parameters<typeof t>[0]).toLowerCase()
      const groupText = i.group ? t(i.group as Parameters<typeof t>[0]).toLowerCase() : ''
      return labelText.includes(q) || groupText.includes(q)
    })
  }, [searchQuery, allItems, t])

  // User initials
  const initials = displayName
    .split(' ')
    .map(n => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2) || '?'

  // Quick stats
  const totalBadges = (unreadMessages || 0) + (unreadNotifications || 0) + (activeCrises || 0) + (suggestedMatches || 0) + (interactionRequests || 0)

  return (
    <>
      {/* Overlay */}
      {mobileMenuOpen && (
        <div
          className="md:hidden fixed inset-0 z-50 bg-black/60 backdrop-blur-sm animate-fade-in"
          onClick={closeMobileMenu}
        />
      )}

      {/* Slide-in drawer */}
      <div
        role="dialog"
        aria-modal="true"
        aria-label={t('mainNav')}
        aria-hidden={!mobileMenuOpen}
        className={cn(
          'md:hidden fixed top-0 left-0 bottom-0 z-50 w-[300px] bg-mn-elevated shadow-2xl transition-transform duration-300 ease-out flex flex-col',
          mobileMenuOpen ? 'translate-x-0' : '-translate-x-full',
        )}
      >
        {/* Header */}
        <div
          className="flex items-center justify-between px-4 h-16 flex-shrink-0"
          style={{ background: 'linear-gradient(135deg, #1EAAA6 0%, #38a169 100%)' }}
        >
          <Link href="/dashboard" onClick={closeMobileMenu}>
            <div className="bg-mn-elevated/95 rounded-xl px-2.5 py-1 shadow-sm">
              <Image
                src="/mensaena-logo.png"
                alt="Mensaena"
                width={165}
                height={110}
                className="h-11 w-auto object-contain"
                priority
              />
            </div>
          </Link>
          <button
            onClick={closeMobileMenu}
            className="p-1.5 rounded-lg bg-mn-elevated/15 hover:bg-mn-elevated/25 text-white transition-all"
            aria-label={t('closeMenu')}
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* User info with avatar */}
        <Link
          href="/dashboard/profile"
          onClick={closeMobileMenu}
          className="px-4 py-3 bg-mn-surface border-b border-white/5 flex items-center gap-3 hover:bg-mn-elevated/5 transition-colors"
        >
          {avatarUrl ? (
            <img
              src={avatarUrl}
              alt={displayName}
              className="w-10 h-10 rounded-full object-cover border-2 border-mn-amber/20 shadow-sm"
            />
          ) : (
            <div
              className="w-10 h-10 rounded-full flex items-center justify-center text-white text-sm font-bold shadow-sm"
              style={{ background: 'linear-gradient(135deg, #1EAAA6 0%, #38a169 100%)' }}
            >
              {initials}
            </div>
          )}
          <div className="flex-1 min-w-0">
            <p className="text-sm font-semibold text-mn-ink truncate">{displayName}</p>
            <p className="text-xs text-mn-mute truncate">{email}</p>
          </div>
          <ChevronRight className="w-4 h-4 text-mn-mute flex-shrink-0" />
        </Link>

        {/* Quick Stats bar */}
        {totalBadges > 0 && (
          <div className="px-3 py-2 flex gap-2 border-b border-white/5 bg-gradient-to-r from-stone-50 to-white">
            {unreadMessages > 0 && (
              <Link
                href="/dashboard/messages"
                onClick={closeMobileMenu}
                className="flex items-center gap-1.5 px-2.5 py-1.5 bg-mn-surface border border-white/5 rounded-lg hover:bg-mn-elevated transition-all"
              >
                <MessageCircle className="w-3.5 h-3.5 text-mn-teal-soft" />
                <span className="text-[11px] font-semibold text-mn-teal-soft">{unreadMessages}</span>
              </Link>
            )}
            {unreadNotifications > 0 && (
              <Link
                href="/dashboard/notifications"
                onClick={closeMobileMenu}
                className="flex items-center gap-1.5 px-2.5 py-1.5 bg-mn-amber/5 border border-mn-amber/20 rounded-lg hover:bg-mn-amber/10 transition-all"
              >
                <Bell className="w-3.5 h-3.5 text-mn-amber" />
                <span className="text-[11px] font-semibold text-mn-amber">{unreadNotifications}</span>
              </Link>
            )}
            {activeCrises > 0 && (
              <Link
                href="/dashboard/crisis"
                onClick={closeMobileMenu}
                className="flex items-center gap-1.5 px-2.5 py-1.5 bg-mn-surface border border-mn-herzrot/20 rounded-lg hover:bg-mn-elevated transition-all animate-pulse-slow"
              >
                <Zap className="w-3.5 h-3.5 text-mn-herzrot" />
                <span className="text-[11px] font-bold text-mn-herzrot">{activeCrises}</span>
              </Link>
            )}
          </div>
        )}

        {/* Search */}
        <div className="px-3 py-2 border-b border-white/5">
          <div className="relative">
            <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-mn-mute" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder={t('searchPlaceholder')}
              className="w-full pl-8 pr-3 py-2 text-sm bg-mn-surface border border-white/5 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary-300 focus:border-primary-300 transition-all"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                className="absolute right-2 top-1/2 -translate-y-1/2 text-mn-mute hover:text-mn-ink-soft"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            )}
          </div>
        </div>

        {/* SOS */}
        <div className="px-3 py-2 border-b border-white/5">
          <Link
            href="/dashboard/crisis"
            onClick={closeMobileMenu}
            className="flex items-center gap-2 px-3 py-2 bg-mn-surface border border-mn-herzrot/20 rounded-xl hover:bg-mn-elevated transition-all w-full"
          >
            <Zap className="w-4 h-4 text-mn-herzrot" />
            <span className="text-sm font-bold text-mn-herzrot">{t('sosCrisis')}</span>
            {activeCrises > 0 && (
              <span className="ml-auto w-5 h-5 bg-red-500 text-white text-xs font-bold rounded-full flex items-center justify-center animate-pulse">
                {activeCrises}
              </span>
            )}
          </Link>
        </div>

        {/* Navigation - scrollable */}
        <nav className="flex-1 overflow-y-auto py-2 px-3">
          {/* Search results */}
          {filteredItems ? (
            <div>
              <div className="flex items-center gap-2 px-3 mb-2">
                <span className="text-xs font-black uppercase tracking-wider text-mn-mute">
                  {t('searchResults')} ({filteredItems.length})
                </span>
                <div className="flex-1 h-px bg-mn-raised" />
              </div>
              {filteredItems.length === 0 ? (
                <div className="py-6 text-center">
                  <Search className="w-6 h-6 text-mn-ghost mx-auto mb-2" />
                  <p className="text-sm text-mn-mute">{t('noResults')}</p>
                </div>
              ) : (
                <div className="space-y-0.5">
                  {filteredItems.map((item) => {
                    const Icon = item.icon
                    const active = isActive(item.path)
                    return (
                      <Link
                        key={item.id}
                        href={item.path}
                        onClick={closeMobileMenu}
                        className={cn(
                          'flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all',
                          active
                            ? 'bg-mn-amber/5 text-primary-800 font-semibold border border-mn-amber/20'
                            : 'text-mn-ink-soft hover:bg-mn-elevated/[0.02] border border-transparent',
                        )}
                      >
                        <Icon className={cn('w-5 h-5', active ? 'text-mn-amber' : 'text-mn-mute')} />
                        <div className="flex-1 min-w-0">
                          <span className="text-sm">{t(item.label as Parameters<typeof t>[0])}</span>
                          {item.group && <p className="text-xs text-mn-mute">{t(item.group as Parameters<typeof t>[0])}</p>}
                        </div>
                      </Link>
                    )
                  })}
                </div>
              )}
            </div>
          ) : (
            <>
              {/* Main items */}
              <div className="space-y-0.5">
                {mainNavItems.map((item) => {
                  const Icon = item.icon
                  const active = isActive(item.path)
                  const badge = getBadge(item.badgeKey)

                  return (
                    <Link
                      key={item.id}
                      href={item.path}
                      onClick={closeMobileMenu}
                      className={cn(
                        'flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all',
                        active
                          ? 'bg-mn-amber/5 text-primary-800 font-semibold border border-mn-amber/20'
                          : 'text-mn-ink-soft hover:bg-mn-elevated/[0.02] border border-transparent',
                      )}
                    >
                      <Icon className={cn('w-5 h-5', active ? 'text-mn-amber' : 'text-mn-mute')} />
                      <span className="flex-1 text-sm">{t(item.label as Parameters<typeof t>[0])}</span>
                      {badge !== undefined && badge > 0 && (
                        <span className="min-w-[20px] h-5 bg-red-500 text-white text-xs font-bold rounded-full flex items-center justify-center px-1">
                          {badge > 99 ? '99+' : badge}
                        </span>
                      )}
                    </Link>
                  )
                })}
              </div>

              {/* Groups - collapsible */}
              {navGroups
                .filter((group) => !group.adminOnly || isAdmin)
                .map((group) => {
                  const isCollapsed = collapsedGroups[group.id]
                  return (
                    <div key={group.id} className="mt-3">
                      <button
                        onClick={() => toggleGroup(group.id)}
                        className="w-full flex items-center gap-2 px-3 mb-1 group hover:opacity-100 opacity-80 transition-opacity"
                      >
                        <span className="text-xs font-black uppercase tracking-wider text-mn-mute">
                          {t(group.title as Parameters<typeof t>[0])}
                        </span>
                        <div className="flex-1 h-px bg-mn-raised" />
                        <ChevronRight
                          className={cn(
                            'w-3 h-3 text-mn-mute transition-transform duration-200',
                            !isCollapsed && 'rotate-90',
                          )}
                        />
                      </button>
                      <div className={cn(
                        'overflow-hidden transition-all duration-200 ease-out',
                        isCollapsed ? 'max-h-0 opacity-0' : 'max-h-[800px] opacity-100',
                      )}>
                        <div className="space-y-0.5">
                          {group.items.map((item) => {
                            const Icon = item.icon
                            const active = isActive(item.path)
                            const isCrisis = item.variant === 'crisis'
                            const isComingSoon = item.comingSoon
                            const badge = getBadge(item.badgeKey)

                            return isComingSoon ? (
                              <button
                                key={item.id}
                                onClick={handleComingSoon}
                                className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-mn-mute opacity-60 border border-transparent text-left"
                              >
                                <Icon className="w-5 h-5" />
                                <span className="flex-1 text-sm">{t(item.label as Parameters<typeof t>[0])}</span>
                                <span className="text-[9px] font-bold uppercase text-mn-mute bg-mn-elevated px-1.5 py-0.5 rounded">
                                  {t('comingSoon')}
                                </span>
                              </button>
                            ) : (
                              <Link
                                key={item.id}
                                href={item.path}
                                onClick={closeMobileMenu}
                                className={cn(
                                  'flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all',
                                  active
                                    ? isCrisis
                                      ? 'bg-mn-surface text-mn-herzrot font-semibold border border-mn-herzrot/20'
                                      : 'bg-mn-amber/5 text-primary-800 font-semibold border border-mn-amber/20'
                                    : cn(
                                        'text-mn-ink-soft hover:bg-mn-elevated/[0.02] border border-transparent',
                                        isCrisis && 'text-mn-herzrot',
                                      ),
                                )}
                              >
                                <Icon className={cn('w-5 h-5', active ? (isCrisis ? 'text-mn-herzrot' : 'text-mn-amber') : isCrisis ? 'text-mn-herzrot' : 'text-mn-mute')} />
                                <span className="flex-1 text-sm">{t(item.label as Parameters<typeof t>[0])}</span>
                                {badge !== undefined && badge > 0 && (
                                  <span className={cn(
                                    'min-w-[20px] h-5 text-white text-xs font-bold rounded-full flex items-center justify-center px-1',
                                    isCrisis ? 'bg-red-500' : 'bg-blue-500',
                                  )}>
                                    {badge > 99 ? '99+' : badge}
                                  </span>
                                )}
                                {isCrisis && !active && <span className="w-2 h-2 bg-red-400 rounded-full animate-pulse" />}
                              </Link>
                            )
                          })}
                        </div>
                      </div>
                    </div>
                  )
                })}
            </>
          )}
        </nav>

        {/* Quick links */}
        <div className="flex-shrink-0 border-t border-white/5 px-3 py-2">
          <div className="flex gap-2">
            <Link
              href="/dashboard/profile"
              onClick={closeMobileMenu}
              className="flex-1 flex items-center justify-center gap-1.5 px-2 py-2 rounded-xl text-mn-ink-soft hover:bg-mn-elevated/[0.02] transition-all text-xs font-medium"
            >
              <User className="w-3.5 h-3.5" />
              {t('profile')}
            </Link>
            <Link
              href="/dashboard/settings"
              onClick={closeMobileMenu}
              className="flex-1 flex items-center justify-center gap-1.5 px-2 py-2 rounded-xl text-mn-ink-soft hover:bg-mn-elevated/[0.02] transition-all text-xs font-medium"
            >
              <Settings className="w-3.5 h-3.5" />
              {t('settings')}
            </Link>
            {isAdmin && (
              <Link
                href="/dashboard/admin"
                onClick={closeMobileMenu}
                className="flex-1 flex items-center justify-center gap-1.5 px-2 py-2 rounded-xl text-mn-ink-soft hover:bg-mn-elevated/[0.02] transition-all text-xs font-medium"
              >
                <Shield className="w-3.5 h-3.5" />
                {t('adminShort')}
              </Link>
            )}
          </div>
        </div>

        {/* Language + Footer */}
        <div className="flex-shrink-0 border-t border-white/5 px-3 py-2 space-y-1">
          <div className="flex items-center justify-between px-1 py-1">
            <div className="flex items-center gap-2 text-xs font-medium text-mn-mute">
              <Globe className="w-3.5 h-3.5" />
              {t('language')}
            </div>
            <LanguageSwitcher dropUp />
          </div>
          <button
            onClick={handleLogout}
            className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-mn-herzrot hover:bg-mn-surface transition-all"
          >
            <LogOut className="w-5 h-5" />
            <span className="text-sm font-medium">{t('logout')}</span>
          </button>
        </div>
      </div>
    </>
  )
}
