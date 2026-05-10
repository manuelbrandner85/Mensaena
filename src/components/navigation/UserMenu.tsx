'use client'

import { useState, useRef, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { User, Settings, LogOut, Shield } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { useTranslations } from 'next-intl'
import { cn } from '@/lib/utils'

interface UserMenuProps {
  displayName: string
  email: string
  avatarUrl?: string | null
  isAdmin: boolean
}

export default function UserMenu({ displayName, email, avatarUrl, isAdmin }: UserMenuProps) {
  const t = useTranslations('nav')
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)
  const router = useRouter()

  const initials = displayName
    .split(' ')
    .map((n) => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2) || '?'

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [])

  const handleLogout = async () => {
    setOpen(false)
    const supabase = createClient()
    await supabase.auth.signOut()
    toast.success(t('logoutSuccess'))
    router.push('/')
  }

  const menuItems = [
    { href: '/dashboard/profile', label: t('myProfile'), icon: User },
    { href: '/dashboard/settings', label: t('settings'), icon: Settings },
    ...(isAdmin ? [{ href: '/dashboard/admin', label: t('adminDashboard'), icon: Shield }] : []),
  ]

  return (
    <div ref={ref} className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex items-center gap-2.5 pl-3 border-l border-white/8 hover:opacity-80 transition-opacity"
        aria-label={t('userMenu')}
        aria-expanded={open}
      >
        {avatarUrl ? (
          <img
            src={avatarUrl}
            alt={displayName}
            className="w-8 h-8 rounded-full object-cover border-2 border-mn-amber/20"
          />
        ) : (
          <div
            className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold shadow-sm"
            style={{ background: 'linear-gradient(135deg, #1EAAA6 0%, #38a169 100%)' }}
          >
            {initials}
          </div>
        )}
        <div className="hidden xl:block text-left">
          <p className="text-sm font-medium text-mn-ink leading-none">{displayName}</p>
          <p className="text-xs text-mn-mute mt-0.5">{email}</p>
        </div>
      </button>

      {open && (
        <div className="absolute right-0 top-full mt-2 w-56 bg-mn-elevated rounded-2xl shadow-cinema-card-2xl border border-white/8 z-50 overflow-hidden animate-scale-in">
          {/* User info header */}
          <div className="px-4 py-3 border-b border-white/8">
            <p className="text-sm font-semibold text-mn-ink truncate">{displayName}</p>
            <p className="text-xs text-mn-mute truncate">{email}</p>
          </div>

          {/* Menu items */}
          <div className="py-1">
            {menuItems.map((item) => {
              const Icon = item.icon
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={() => setOpen(false)}
                  className="flex items-center gap-3 px-4 py-2.5 text-sm text-mn-ink-soft hover:bg-mn-elevated/[0.02] hover:text-mn-ink transition-colors"
                >
                  <Icon className="w-4 h-4 text-mn-mute" />
                  {item.label}
                </Link>
              )
            })}
          </div>

          {/* Logout */}
          <div className="border-t border-white/8 py-1">
            <button
              onClick={handleLogout}
              className="w-full flex items-center gap-3 px-4 py-2.5 text-sm text-mn-herzrot hover:bg-mn-surface transition-colors"
            >
              <LogOut className="w-4 h-4" />
              {t('logout')}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
