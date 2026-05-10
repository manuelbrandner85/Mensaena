import Image from 'next/image'
import { cn } from '@/lib/design-system'

type OrbSize = 'xs' | 'sm' | 'md' | 'lg' | 'xl'
type OnlineStatus = 'online' | 'available' | 'offline' | 'none'

const sizeMap: Record<OrbSize, { px: number; ring: string; dot: string; text: string }> = {
  xs: { px: 24, ring: 'ring-1',   dot: 'w-1.5 h-1.5 -bottom-0 -right-0',   text: 'text-[9px]' },
  sm: { px: 32, ring: 'ring-1',   dot: 'w-2   h-2   -bottom-0  -right-0',   text: 'text-[11px]' },
  md: { px: 40, ring: 'ring-[2px]',dot: 'w-2.5 h-2.5 bottom-0  right-0',   text: 'text-xs' },
  lg: { px: 56, ring: 'ring-2',   dot: 'w-3   h-3   bottom-0.5 right-0.5', text: 'text-sm' },
  xl: { px: 80, ring: 'ring-2',   dot: 'w-3.5 h-3.5 bottom-1   right-1',   text: 'text-base' },
}

const ringColors: Record<OnlineStatus, string> = {
  online:    'ring-mn-leben shadow-[0_0_12px_rgba(34,197,94,0.45)]',
  available: 'ring-mn-amber shadow-[0_0_12px_rgba(245,158,11,0.35)]',
  offline:   'ring-white/10',
  none:      '',
}

const dotColors: Record<OnlineStatus, string> = {
  online:    'bg-mn-leben',
  available: 'bg-mn-amber',
  offline:   'bg-mn-mute',
  none:      'hidden',
}

interface ProfilOrbProps {
  src?: string | null
  name?: string | null
  size?: OrbSize
  status?: OnlineStatus
  className?: string
}

function initials(name?: string | null) {
  if (!name) return '?'
  return name.split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase()
}

export default function ProfilOrb({ src, name, size = 'md', status = 'none', className }: ProfilOrbProps) {
  const { px, ring, dot, text } = sizeMap[size]
  const ringCls = status !== 'none' ? ringColors[status] : ''

  return (
    <div
      className={cn('relative inline-flex shrink-0 rounded-full overflow-visible', className)}
      style={{ width: px, height: px }}
    >
      <div
        className={cn('w-full h-full rounded-full overflow-hidden bg-mn-surface', ring, ringCls)}
      >
        {src ? (
          <Image src={src} alt={name ?? 'Avatar'} width={px} height={px} className="object-cover w-full h-full" />
        ) : (
          <div className={cn('w-full h-full flex items-center justify-center bg-mn-surface text-mn-mute font-medium', text)}>
            {initials(name)}
          </div>
        )}
      </div>
      {status !== 'none' && (
        <span
          className={cn('absolute rounded-full border-2 border-mn-void', dot, dotColors[status])}
          aria-hidden
        />
      )}
    </div>
  )
}
