'use client'

interface Props {
  progress: number
  status: 'loading' | 'success' | 'error'
  label: string
  sublabel?: string
}

export default function DownloadProgressBar({ progress, status, label, sublabel }: Props) {
  const clampedProgress = Math.min(100, Math.max(0, progress))

  const trackColor =
    status === 'success' ? 'bg-green-100' :
    status === 'error'   ? 'bg-amber-100' :
    'bg-primary-100'

  const barColor =
    status === 'success'
      ? 'bg-green-500'
      : status === 'error'
        ? 'bg-amber-500'
        : 'bg-gradient-to-r from-primary-500 to-primary-400'

  const shimmer = status === 'loading'
    ? 'after:absolute after:inset-0 after:bg-gradient-to-r after:from-transparent after:via-white/30 after:to-transparent after:animate-shimmer after:bg-[length:400px_100%]'
    : ''

  return (
    <div className="w-full space-y-2">
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2 min-w-0">
          {status === 'loading' && (
            <span className="flex-shrink-0 w-4 h-4 rounded-full border-2 border-primary-500 border-t-transparent animate-spin" aria-hidden="true" />
          )}
          {status === 'success' && (
            <span className="flex-shrink-0 text-green-600" aria-hidden="true">✓</span>
          )}
          {status === 'error' && (
            <span className="flex-shrink-0 text-amber-600" aria-hidden="true">⚠</span>
          )}
          <span className="text-sm font-medium text-ink-700 truncate">{label}</span>
        </div>
        <span className="flex-shrink-0 text-xs text-ink-400 tabular-nums">
          {clampedProgress}%
        </span>
      </div>

      <div
        role="progressbar"
        aria-valuenow={clampedProgress}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={label}
        className={`relative h-2.5 rounded-full overflow-hidden ${trackColor}`}
      >
        <div
          className={`h-full rounded-full relative overflow-hidden transition-all duration-500 ease-out ${barColor} ${shimmer}`}
          style={{ width: `${clampedProgress}%` }}
        />
      </div>

      {sublabel && (
        <p className="text-xs text-ink-500 animate-fade-in">{sublabel}</p>
      )}
    </div>
  )
}
