'use client'

import { MapPin, Edit3, Calendar } from 'lucide-react'
import { cn } from '@/lib/utils'

export interface ProfileHeaderData {
  id: string
  name?: string | null
  nickname?: string | null
  bio?: string | null
  location?: string | null
  avatar_url?: string | null
  created_at?: string | null
}

interface Props {
  profile: ProfileHeaderData
  onEdit: () => void
}

const MONTHS_DE = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
]

function formatMemberSince(created_at?: string | null): string {
  if (!created_at) return 'heute'
  const d = new Date(created_at)
  return `${MONTHS_DE[d.getMonth()]} ${d.getFullYear()}`
}

export default function ProfileHeader({ profile, onEdit }: Props) {
  const displayName = profile.name?.trim() || 'Nutzer'
  const username = profile.nickname?.trim() || null
  const initials = displayName
    .split(' ')
    .map((n) => n[0])
    .filter(Boolean)
    .join('')
    .toUpperCase()
    .slice(0, 2)

  return (
    <div className="relative">
      {/* Banner: Gradient-Placeholder mit sanfter Textur */}
      <div
        className={cn(
          'relative h-40 sm:h-56 w-full overflow-hidden rounded-2xl sm:rounded-3xl',
          'bg-gradient-to-br from-primary-400 via-primary-500 to-primary-700',
          'shadow-card',
        )}
      >
        {/* Noise grain */}
        <div className="bg-noise absolute inset-0 opacity-25 pointer-events-none" />
        {/* dekorative Blobs */}
        <div className="absolute -top-10 -left-10 h-48 w-48 rounded-full bg-white/10 blur-3xl float-idle" />
        <div className="absolute -bottom-16 -right-10 h-56 w-56 rounded-full bg-primary-200/20 blur-3xl float-idle" style={{ animationDelay: '1.2s' }} />
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top,rgba(255,255,255,0.22),transparent_60%)]" />

        {/* Edit-Button */}
        <button
          onClick={onEdit}
          className={cn(
            'shine absolute top-4 right-4 inline-flex items-center gap-1.5 rounded-full px-4 py-2',
            'bg-white/95 backdrop-blur-sm text-sm font-medium text-gray-800',
            'shadow-card hover:bg-white hover:shadow-glow-teal active:scale-95 transition-all',
          )}
        >
          <Edit3 className="w-4 h-4" />
          <span className="hidden sm:inline">Profil bearbeiten</span>
          <span className="sm:hidden">Bearbeiten</span>
        </button>
      </div>

      {/* Avatar + Identität */}
      <div className="px-4 sm:px-8">
        <div className="flex flex-col items-center sm:flex-row sm:items-end sm:gap-6 -mt-16 sm:-mt-20">
          {/* Avatar */}
          <div className="relative flex-shrink-0">
            <div className="h-32 w-32 sm:h-36 sm:w-36 rounded-full bg-white p-1.5 shadow-glow-teal ring-2 ring-primary-100">
              <div className="h-full w-full overflow-hidden rounded-full bg-gradient-to-br from-primary-100 to-primary-50 flex items-center justify-center">
                {profile.avatar_url ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={profile.avatar_url}
                    alt={displayName}
                    className="h-full w-full object-cover"
                  />
                ) : (
                  <span className="display-numeral text-3xl font-bold text-primary-700">
                    {initials || 'N'}
                  </span>
                )}
              </div>
            </div>
            {/* Online-Indikator */}
            <span className="absolute bottom-2 right-2 h-4 w-4 rounded-full bg-primary-500 ring-2 ring-white shadow-glow" />
          </div>

          {/* Name & Meta */}
          <div className="mt-4 sm:mt-0 sm:mb-2 flex-1 text-center sm:text-left">
            <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 leading-tight">
              {displayName}
            </h1>
            {username && (
              <p className="text-sm text-gray-500 mt-0.5">@{username}</p>
            )}
            <div className="mt-2 flex flex-wrap items-center justify-center sm:justify-start gap-x-4 gap-y-1 text-xs text-gray-500">
              {profile.location && (
                <span className="inline-flex items-center gap-1">
                  <MapPin className="w-3.5 h-3.5" />
                  {profile.location}
                </span>
              )}
              <span className="inline-flex items-center gap-1">
                <Calendar className="w-3.5 h-3.5" />
                Dabei seit {formatMemberSince(profile.created_at)}
              </span>
            </div>
          </div>
        </div>

        {/* Bio */}
        {profile.bio && profile.bio.trim().length > 0 && (
          <p className="mt-4 text-sm sm:text-base text-gray-700 leading-relaxed max-w-2xl text-center sm:text-left mx-auto sm:mx-0">
            {profile.bio}
          </p>
        )}
      </div>
    </div>
  )
}
