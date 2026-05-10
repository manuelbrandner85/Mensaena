import { cn } from '@/lib/utils'

interface CinemaSectionProps {
  children: React.ReactNode
  className?: string
  id?: string
  index?: string
  label?: string
  title?: React.ReactNode
  subtitle?: React.ReactNode
  align?: 'left' | 'center'
}

export default function CinemaSection({
  children,
  className,
  id,
  index,
  label,
  title,
  subtitle,
  align = 'left',
}: CinemaSectionProps) {
  const hasHeader = label || title || subtitle
  const headingStyle = {
    fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
    fontWeight: 400,
    fontSize: 'clamp(2.25rem, 5vw, 3.75rem)',
    lineHeight: 1.05,
    letterSpacing: '-0.025em',
    color: '#F5F0E8',
  } as React.CSSProperties

  return (
    <section
      id={id}
      className={cn(
        'cinema-section relative py-24 md:py-36 px-6 md:px-10 scroll-mt-24',
        className,
      )}
      aria-labelledby={id ? `${id}-heading` : undefined}
    >
      <div className="max-w-6xl mx-auto">
        {hasHeader && (
          <header className={cn('mb-16 md:mb-20 max-w-3xl', align === 'center' && 'mx-auto text-center')}>
            {label && (
              <div className="reveal cinema-meta-label mb-7">
                {index ? `${index} / ${label}` : label}
              </div>
            )}
            {title && (
              <h2
                id={id ? `${id}-heading` : undefined}
                className="reveal reveal-delay-1"
                style={headingStyle}
              >
                {title}
              </h2>
            )}
            {subtitle && (
              <p
                className="reveal reveal-delay-2 mt-6 text-lg leading-relaxed"
                style={{ color: 'rgba(245,240,232,0.50)' }}
              >
                {subtitle}
              </p>
            )}
          </header>
        )}
        {children}
      </div>
    </section>
  )
}
