import { cn } from '@/lib/design-system'

interface SkeletonProps {
  className?: string
  lines?: number
}

export function CinemaSkeleton({ className }: { className?: string }) {
  return (
    <div
      className={cn('rounded bg-mn-surface relative overflow-hidden', className)}
      aria-hidden
    >
      <div
        className="absolute inset-0 -translate-x-full"
        style={{
          background: 'linear-gradient(90deg, transparent 0%, rgba(245,158,11,0.04) 40%, rgba(28,42,66,0.8) 60%, transparent 100%)',
          animation: 'shimmer 1.8s linear infinite',
        }}
      />
    </div>
  )
}

export function CinemaCardSkeleton({ lines = 3 }: SkeletonProps) {
  return (
    <div className="bg-mn-elevated rounded-card border border-white/5 p-5 space-y-3">
      <div className="flex items-center gap-3">
        <CinemaSkeleton className="w-10 h-10 rounded-full" />
        <div className="flex-1 space-y-2">
          <CinemaSkeleton className="h-4 w-32" />
          <CinemaSkeleton className="h-3 w-20" />
        </div>
      </div>
      {Array.from({ length: lines }).map((_, i) => (
        <CinemaSkeleton key={i} className={cn('h-3.5', i === lines - 1 ? 'w-3/5' : 'w-full')} />
      ))}
    </div>
  )
}
