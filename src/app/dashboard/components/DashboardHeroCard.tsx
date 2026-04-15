'use client'

import { useEffect, useState } from 'react'
import { MapPin, Calendar, Edit3, ArrowRight } from 'lucide-react'
import Link from 'next/link'
import type { DashboardProfile } from '../types'

interface Props {
  profile: DashboardProfile | null
  memberSinceDays: number
}

const MONTHS_DE = [
  'Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni',
  'Juli', 'Aug.', 'Sep.', 'Okt.', 'Nov.', 'Dez.',
]

function memberSinceLabel(created_at?: string | null): string {
  if (!created_at) return 'heute'
  const d = new Date(created_at)
  return `${MONTHS_DE[d.getMonth()]} ${d.getFullYear()}`
}

export default function DashboardHeroCard({ profile, memberSinceDays }: Props) {
  const [greeting, setGreeting] = useState({ text: 'Hallo', accent: 'Tag' })
  const [dateStr, setDateStr] = useState('')

  useEffect(() => {
    const h = new Date().getHours()
    if (h < 12) setGreeting({ text: 'Guten', accent: 'Morgen' })
    else if (h < 18) setGreeting({ text: 'Guten', accent: 'Tag' })
    else setGreeting({ text: 'Guten', accent: 'Abend' })
    // Native Intl replaces date-fns (~14 kB bundle savings)
    const now = new Date()
    const weekday = new Intl.DateTimeFormat('de-DE', { weekday: 'long' }).format(now)
    const dayMonthYear = new Intl.DateTimeFormat('de-DE', {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    }).format(now)
    setDateStr(`${weekday} · ${dayMonthYear}`)
  }, [])

  const displayName = profile?.name?.trim() || profile?.nickname?.trim() || 'Nutzer'
  const nickname = profile?.nickname?.trim() || null
  const initials = displayName
    .split(' ')
    .map((n) => n[0])
    .filter(Boolean)
    .join('')
    .toUpperCase()
    .slice(0, 2)

  return (
    <header className="mb-2">
      {/* Date label */}
      {dateStr && (
        <div className="meta-label meta-label--subtle mb-5">{dateStr}</div>
      )}

      {/* Hero row */}
      <div className="flex items-start gap-5">
        {/* Avatar */}
        <div className="relative flex-shrink-0">
          <div className="w-16 h-16 sm:w-20 sm:h-20 rounded-2xl bg-primary-50 border-2 border-paper ring-1 ring-stone-200 shadow-soft overflow-hidden flex items-center justify-center">
            {profile?.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={profile.avatar_url}
                alt={displayName}
                className="w-full h-full object-cover"
              />
            ) : (
              <span className="text-xl sm:text-2xl font-bold text-primary-700 select-none">
                {initials || 'N'}
              </span>
            )}
          </div>
          {/* Online dot */}
          <span className="absolute -bottom-0.5 -right-0.5 h-3.5 w-3.5 rounded-full bg-green-500 ring-2 ring-paper" />
        </div>

        {/* Identity */}
        <div className="flex-1 min-w-0">
          <h1 className="page-title leading-tight">
            {greeting.text}{' '}
            <span className="text-accent">{greeting.accent}</span>,{' '}
            {displayName}.
          </h1>

          {/* Meta row */}
          <div className="flex flex-wrap items-center gap-x-4 gap-y-1 mt-2 text-xs text-ink-400 tracking-wide">
            {nickname && (
              <span className="font-mono text-ink-500">@{nickname}</span>
            )}
            {profile?.location && (
              <span className="inline-flex items-center gap-1">
                <MapPin className="w-3 h-3" />
                {profile.location}
              </span>
            )}
            <span className="inline-flex items-center gap-1">
              <Calendar className="w-3 h-3" />
              Dabei seit {memberSinceLabel(profile?.created_at)}
              {memberSinceDays >= 7 && (
                <span className="ml-1 font-serif italic text-ink-700">
                  · Tag <span className="tabular-nums">{memberSinceDays}</span>
                </span>
              )}
            </span>
          </div>

          {/* Bio */}
          {profile?.bio && profile.bio.trim().length > 0 && (
            <p className="mt-3 text-sm text-ink-600 leading-relaxed line-clamp-2 max-w-lg">
              {profile.bio}
            </p>
          )}
        </div>

        {/* Actions — desktop */}
        <div className="hidden sm:flex flex-col gap-2 flex-shrink-0 mt-1">
          <Link
            href="/dashboard/settings?tab=profile"
            className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-paper border border-stone-200 text-xs font-medium text-ink-700 hover:bg-stone-50 hover:border-stone-300 transition-colors shadow-soft"
          >
            <Edit3 className="w-3.5 h-3.5" />
            Bearbeiten
          </Link>
          <Link
            href="/dashboard/profile"
            className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-paper border border-stone-200 text-xs font-medium text-ink-500 hover:text-ink-700 hover:border-stone-300 transition-colors shadow-soft"
          >
            Vollprofil
            <ArrowRight className="w-3 h-3" />
          </Link>
        </div>
      </div>

      {/* Mobile actions */}
      <div className="flex sm:hidden items-center gap-2 mt-4">
        <Link
          href="/dashboard/settings?tab=profile"
          className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-paper border border-stone-200 text-xs font-medium text-ink-700 hover:bg-stone-50 transition-colors shadow-soft"
        >
          <Edit3 className="w-3.5 h-3.5" />
          Bearbeiten
        </Link>
        <Link
          href="/dashboard/profile"
          className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-paper border border-stone-200 text-xs font-medium text-ink-500 hover:text-ink-700 transition-colors shadow-soft"
        >
          Vollprofil
          <ArrowRight className="w-3 h-3" />
        </Link>
      </div>

      {/* Divider */}
      <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
    </header>
  )
}
