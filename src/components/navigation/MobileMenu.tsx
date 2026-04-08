'use client'

import { useEffect } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { X, LogOut, Zap } from 'lucide-react'
import { useRouter, usePathname } from 'next/navigation'
import toast from 'react-hot-toast'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import { useNavigationStore } from '@/store/useNavigationStore'
import { useNavigation } from '@/hooks/useNavigation'
import { mainNavItems, navGroups } from './navigationConfig'

interface MobileMenuProps {
  unreadMessages: number
  unreadNotifications: number
  activeCrises: number
  suggestedMatches: number
  interactionRequests?: number
  isAdmin: boolean
  displayName: string
  email: string
}

export default function MobileMenu({ unreadMessages, unreadNotifications, activeCrises, suggestedMatches, interactionRequests = 0, isAdmin, displayName, email }: MobileMenuProps) {
  const { mobileMenuOpen, closeMobileMenu } = useNavigationStore()
  const { isActive } = useNavigation()
  const router = useRouter()
  const pathname = usePathname()

  // Close menu on route change
  useEffect(() => { closeMobileMenu() }, [pathname, closeMobileMenu])

  // Lock body scroll
  useEffect(() => {
    document.body.style.overflow = mobileMenuOpen ? 'hidden' : ''
    return () => { document.body.style.overflow = '' }
  }, [mobileMenuOpen])

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
    toast.success('Erfolgreich abgemeldet')
    router.push('/')
    router.refresh()
  }

  const handleComingSoon = (e: React.MouseEvent) => {
    e.preventDefault()
    toast('Diese Funktion kommt bald! 🚀', { icon: '🔜' })
  }

  return (
    <>
      {/* Overlay */}
      {mobileMenuOpen && (
        <div
          className="lg:hidden fixed inset-0 z-50 bg-black/60 backdrop-blur-sm animate-fade-in"
          onClick={closeMobileMenu}
        />
      )}

      {/* Slide-in drawer */}
      <div
        className={cn(
          'lg:hidden fixed top-0 left-0 bottom-0 z-50 w-[300px] bg-white shadow-2xl transition-transform duration-300 ease-out overflow-y-auto',
          mobileMenuOpen ? 'translate-x-0' : '-translate-x-full',
        )}
      >
        {/* Header */}
        <div
          className="flex items-center justify-between px-4 h-16 flex-shrink-0"
          style={{ background: 'linear-gradient(135deg, #1EAAA6 0%, #38a169 100%)' }}
        >
          <Link href="/dashboard" onClick={closeMobileMenu}>
            <Image
              src="/mensaena-logo.png"
              alt="Mensaena"
              width={160}
              height={48}
              className="h-9 w-auto object-contain brightness-0 invert"
              priority
            />
          </Link>
          <button
            onClick={closeMobileMenu}
            className="p-1.5 rounded-lg bg-white/15 hover:bg-white/25 text-white transition-all"
            aria-label="Menü schließen"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* User info */}
        <div className="px-4 py-3 bg-gray-50 border-b border-gray-100">
          <p className="text-sm font-semibold text-gray-900 truncate">{displayName}</p>
          <p className="text-xs text-gray-500 truncate">{email}</p>
        </div>

        {/* SOS */}
        <div className="px-3 py-2 border-b border-gray-100">
          <Link
            href="/dashboard/crisis"
            onClick={closeMobileMenu}
            className="flex items-center gap-2 px-3 py-2 bg-red-50 border border-red-200 rounded-xl hover:bg-red-100 transition-all w-full"
          >
            <Zap className="w-4 h-4 text-red-500" />
            <span className="text-sm font-bold text-red-700">SOS Krisenhilfe</span>
          </Link>
        </div>

        {/* Navigation */}
        <nav className="py-2 px-3">
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
                      ? 'bg-primary-50 text-primary-800 font-semibold border border-primary-200'
                      : 'text-gray-700 hover:bg-gray-50 border border-transparent',
                  )}
                >
                  <Icon className={cn('w-5 h-5', active ? 'text-primary-600' : 'text-gray-500')} />
                  <span className="flex-1 text-sm">{item.label}</span>
                  {badge !== undefined && badge > 0 && (
                    <span className="min-w-[20px] h-5 bg-red-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center px-1">
                      {badge > 99 ? '99+' : badge}
                    </span>
                  )}
                </Link>
              )
            })}
          </div>

          {/* Groups */}
          {navGroups
            .filter((group) => !group.adminOnly || isAdmin)
            .map((group) => (
              <div key={group.id} className="mt-4">
                <div className="flex items-center gap-2 px-3 mb-1">
                  <span className="text-[10px] font-black uppercase tracking-wider text-gray-400">
                    {group.title}
                  </span>
                  <div className="flex-1 h-px bg-gray-200" />
                </div>
                <div className="space-y-0.5">
                  {group.items.map((item) => {
                    const Icon = item.icon
                    const active = isActive(item.path)
                    const isCrisis = item.variant === 'crisis'
                    const isComingSoon = item.comingSoon

                    return isComingSoon ? (
                      <button
                        key={item.id}
                        onClick={handleComingSoon}
                        className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-gray-500 opacity-60 border border-transparent text-left"
                      >
                        <Icon className="w-5 h-5" />
                        <span className="flex-1 text-sm">{item.label}</span>
                        <span className="text-[9px] font-bold uppercase text-gray-400 bg-gray-100 px-1.5 py-0.5 rounded">
                          Bald
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
                              ? 'bg-red-50 text-red-700 font-semibold border border-red-200'
                              : 'bg-primary-50 text-primary-800 font-semibold border border-primary-200'
                            : cn(
                                'text-gray-700 hover:bg-gray-50 border border-transparent',
                                isCrisis && 'text-red-600',
                              ),
                        )}
                      >
                        <Icon className={cn('w-5 h-5', active ? (isCrisis ? 'text-red-600' : 'text-primary-600') : isCrisis ? 'text-red-500' : 'text-gray-500')} />
                        <span className="flex-1 text-sm">{item.label}</span>
                        {isCrisis && !active && <span className="w-2 h-2 bg-red-400 rounded-full animate-pulse" />}
                      </Link>
                    )
                  })}
                </div>
              </div>
            ))}
        </nav>

        {/* Footer */}
        <div className="border-t border-gray-100 px-3 py-3 mt-2">
          <button
            onClick={handleLogout}
            className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-red-600 hover:bg-red-50 transition-all"
          >
            <LogOut className="w-5 h-5" />
            <span className="text-sm font-medium">Abmelden</span>
          </button>
        </div>
      </div>
    </>
  )
}
