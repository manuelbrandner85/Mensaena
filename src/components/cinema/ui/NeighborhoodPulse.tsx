import { cn } from '@/lib/design-system'

interface NeighborhoodPulseProps {
  className?: string
  color?: 'amber' | 'herzrot' | 'teal'
}

const colors = {
  amber:  'rgba(199,147,99,0.15)',
  herzrot:'rgba(239,68,68,0.15)',
  teal:   'rgba(14,165,233,0.12)',
}

export default function NeighborhoodPulse({ className, color = 'amber' }: NeighborhoodPulseProps) {
  const c = colors[color]
  return (
    <div className={cn('absolute inset-0 pointer-events-none overflow-hidden', className)} aria-hidden>
      {[0, 1, 2].map(i => (
        <div
          key={i}
          className="absolute rounded-full"
          style={{
            top: '50%',
            left: '50%',
            transform: 'translate(-50%, -50%)',
            width: 200,
            height: 200,
            border: `1px solid ${c}`,
            animation: `pulseWarm 6s ease-out ${i * 2}s infinite`,
          }}
        />
      ))}
    </div>
  )
}
