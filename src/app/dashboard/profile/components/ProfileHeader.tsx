'use client'

import { MapPin, Edit3, Calendar } from 'lucide-react'
import { cn } from '@/lib/utils'
import NeighborhoodPulse from '@/components/cinema/ui/NeighborhoodPulse'

export interface ProfileHeaderData {
  id: string
  name?: string | null
  nickname?: string | null
  bio?: string | null
  location?: string | null
  avatar_url?: string | null
  cover_url?: string | null
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
          'bg-mn-deep border border-white/5',
          'shadow-cinema-raised',
        )}
      >
        {/* Cover-Foto wenn vorhanden, sonst Atmospheric Cinema Layer */}
        {profile.cover_url ? (
          <img
            src={profile.cover_url}
            alt=""
            className="absolute inset-0 w-full h-full object-cover opacity-90"
            onError={(e) => { e.currentTarget.style.display = 'none' }}
          />
        ) : (
          <>
            {/* Amber lantern orb */}
            <div
              className="absolute -top-20 -left-16 h-72 w-72 rounded-full blur-3xl"
              style={{ background: 'radial-gradient(circle, rgba(245,158,11,0.18), transparent 70%)' }}
            />
            {/* Teal night-air orb */}
            <div
              className="absolute -bottom-24 -right-16 h-80 w-80 rounded-full blur-3xl"
              style={{
                background: 'radial-gradient(circle, rgba(125,211,252,0.10), transparent 70%)',
                animationDelay: '1.2s',
              }}
            />
            {/* Pulsing concentric rings (NeighborhoodPulse) */}
            <NeighborhoodPulse color="amber" />
            {/* Subtle vignette */}
            <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top,rgba(245,158,11,0.06),transparent_60%)]" />
          </>
        )}

        {/* Edit-Button */}
        <button
          onClick={onEdit}
          className={cn(
            'shine absolute top-4 right-4 inline-flex items-center gap-1.5 rounded-full px-4 py-2',
            'bg-mn-elevated/95 backdrop-blur-sm text-sm font-medium text-mn-ink',
            'shadow-cinema-card hover:bg-mn-elevated hover:shadow-glow-teal active:scale-95 transition-all',
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
          {/* Avatar — Cinema ProfilOrb-style with amber glow ring */}
          <div className="relative flex-shrink-0">
            <div
              className="h-32 w-32 sm:h-36 sm:w-36 rounded-full bg-mn-raised p-1.5 ring-2 ring-mn-amber/40"
              style={{ boxShadow: '0 0 24px 0 rgba(245,158,11,0.25), 0 0 48px 0 rgba(245,158,11,0.10)' }}
            >
              <div className="h-full w-full overflow-hidden rounded-full bg-gradient-to-br from-mn-amber/15 to-mn-deep flex items-center justify-center">
                {profile.avatar_url ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={profile.avatar_url}
                    alt={displayName}
                    className="h-full w-full object-cover"
                  />
                ) : (
                  <span className="display-numeral text-3xl font-bold text-mn-amber">
                    {initials || 'N'}
                  </span>
                )}
              </div>
            </div>
            {/* Online-Indikator (mn-leben green) */}
            <span
              className="absolute bottom-2 right-2 h-4 w-4 rounded-full bg-mn-leben ring-2 ring-mn-deep"
              style={{ boxShadow: '0 0 12px rgba(34,197,94,0.55)' }}
            />
          </div>

          {/* Name & Meta */}
          <div className="mt-4 sm:mt-0 sm:mb-2 flex-1 text-center sm:text-left">
            <h1 className="text-2xl sm:text-3xl font-bold text-mn-ink leading-tight">
              {displayName}
            </h1>
            {username && (
              <p className="text-sm text-mn-mute mt-0.5">@{username}</p>
            )}
            <div className="mt-2 flex flex-wrap items-center justify-center sm:justify-start gap-x-4 gap-y-1 text-xs text-mn-mute">
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
          <p className="mt-4 text-sm sm:text-base text-mn-ink-soft leading-relaxed max-w-2xl text-center sm:text-left mx-auto sm:mx-0">
            {profile.bio}
          </p>
        )}
      </div>
    </div>
  )
}
