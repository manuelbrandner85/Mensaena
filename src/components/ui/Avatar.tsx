'use client'

import { cn } from '@/lib/design-system'

// ── Sizes ───────────────────────────────────────────────────
const sizeStyles = {
  xs: 'w-6 h-6 text-[9px]',
  sm: 'w-8 h-8 text-[10px]',
  md: 'w-10 h-10 text-xs',
  lg: 'w-14 h-14 text-sm',
  xl: 'w-20 h-20 text-lg',
} as const

// ── Props ───────────────────────────────────────────────────
export interface AvatarProps {
  src?: string | null
  alt?: string
  name?: string | null
  size?: keyof typeof sizeStyles
  interactive?: boolean
  online?: boolean
  className?: string
}

// ── Component ───────────────────────────────────────────────
export default function Avatar({
  src,
  alt = '',
  name,
  size = 'md',
  interactive = false,
  online,
  className,
}: AvatarProps) {
  const initials = name
    ? name
        .split(' ')
        .map((w) => w[0])
        .join('')
        .toUpperCase()
        .slice(0, 2)
    : '?'

  return (
    <div className={cn('relative inline-flex flex-shrink-0', className)}>
      {src ? (
        <img
          src={src}
          alt={alt || name || ''}
          className={cn(
            'rounded-full object-cover flex-shrink-0',
            sizeStyles[size],
            interactive && 'avatar-interactive',
          )}
          loading="lazy"
        />
      ) : (
        <div
          className={cn(
            'rounded-full bg-primary-100 flex items-center justify-center text-primary-700 font-bold flex-shrink-0',
            sizeStyles[size],
            interactive && 'avatar-interactive',
          )}
          aria-label={name || 'Nutzer'}
        >
          {initials}
        </div>
      )}

      {/* Online indicator */}
      {online !== undefined && (
        <span
          className={cn(
            'absolute -bottom-0.5 -right-0.5 border-2 border-white rounded-full',
            online ? 'online-dot' : 'offline-dot',
          )}
          aria-label={online ? 'Online' : 'Offline'}
        />
      )}
    </div>
  )
}
