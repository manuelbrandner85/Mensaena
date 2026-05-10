import { cn } from '@/lib/design-system'
import GlowButton from './GlowButton'

interface CinemaEmptyStateProps {
  icon?: React.ReactNode
  title: string
  description?: string
  action?: { label: string; href?: string; onClick?: () => void }
  className?: string
}

export default function CinemaEmptyState({ icon, title, description, action, className }: CinemaEmptyStateProps) {
  return (
    <div className={cn('flex flex-col items-center justify-center py-16 px-6 text-center', className)}>
      {icon && (
        <div className="mb-5 text-mn-mute/30" style={{ fontSize: 48 }}>
          {icon}
        </div>
      )}
      <h3 className="text-base font-semibold text-mn-ink-soft mb-2">{title}</h3>
      {description && <p className="text-sm text-mn-mute max-w-sm">{description}</p>}
      {action && (
        <div className="mt-6">
          {action.href ? (
            <GlowButton href={action.href} variant="secondary" size="sm">{action.label}</GlowButton>
          ) : (
            <GlowButton variant="secondary" size="sm" onClick={action.onClick}>{action.label}</GlowButton>
          )}
        </div>
      )}
    </div>
  )
}
