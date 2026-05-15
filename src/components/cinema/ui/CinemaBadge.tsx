import { cn } from '@/lib/design-system'

type BadgeVariant = 'amber' | 'teal' | 'herzrot' | 'leben' | 'trust' | 'mute'

const styles: Record<BadgeVariant, string> = {
  amber:  'bg-mn-bronze/10  text-mn-bronze       border-mn-bronze/20',
  teal:   'bg-mn-teal/10   text-mn-teal-soft   border-mn-teal/20',
  herzrot:'bg-mn-herzrot/10 text-mn-herzrot-warm border-mn-herzrot/20',
  leben:  'bg-mn-leben/10  text-mn-leben-soft  border-mn-leben/20',
  trust:  'bg-mn-trust/10  text-mn-trust-soft  border-mn-trust/20',
  mute:   'bg-mn-elevated/5      text-mn-mute        border-white/8',
}

interface CinemaBadgeProps {
  variant?: BadgeVariant
  children: React.ReactNode
  icon?: React.ReactNode
  className?: string
}

export default function CinemaBadge({ variant = 'amber', children, icon, className }: CinemaBadgeProps) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full',
        'text-[11px] font-medium uppercase tracking-wide border',
        styles[variant],
        className,
      )}
    >
      {icon && <span className="w-3 h-3 shrink-0">{icon}</span>}
      {children}
    </span>
  )
}
