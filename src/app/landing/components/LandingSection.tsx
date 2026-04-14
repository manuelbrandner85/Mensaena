import { cn } from '@/lib/utils'

/**
 * LandingSection – editorial magazine-style section container.
 *
 * Supports an optional numbered meta label ("— 01 / DEIN VIERTEL") that
 * sits above the heading, establishing rhythm and hierarchy across the
 * landing page.
 */
interface LandingSectionProps {
  children: React.ReactNode
  className?: string
  id?: string
  background?: 'paper' | 'stone' | 'white' | 'ink' | 'gradient'
  /**
   * Optional zero-padded index rendered as the first part of the meta
   * label, e.g. "01" → "— 01 / {label}". Pass explicitly so sections
   * don't accidentally re-number when reordered.
   */
  index?: string
  /** Section meta label shown as uppercase mono tag. */
  label?: string
  /** Headline rendered as editorial display serif. */
  title?: React.ReactNode
  /** Optional subtitle below the headline. */
  subtitle?: React.ReactNode
  /** Alignment for the section header block. */
  align?: 'left' | 'center'
}

const bgMap = {
  paper:    'bg-paper',
  stone:    'bg-stone-100',
  white:    'bg-white',
  ink:      'bg-ink-900 text-stone-100',
  gradient: 'bg-gradient-to-b from-paper to-stone-100',
}

export default function LandingSection({
  children,
  className,
  id,
  background = 'paper',
  index,
  label,
  title,
  subtitle,
  align = 'left',
}: LandingSectionProps) {
  const hasHeader = label || title || subtitle

  return (
    <section
      id={id}
      className={cn(
        'relative py-24 md:py-36 px-6 md:px-10 scroll-mt-24',
        bgMap[background],
        className,
      )}
      aria-labelledby={id ? `${id}-heading` : undefined}
    >
      <div className="max-w-6xl mx-auto">
        {hasHeader && (
          <header
            className={cn(
              'mb-16 md:mb-20 max-w-3xl',
              align === 'center' && 'mx-auto text-center',
            )}
          >
            {label && (
              <div className="reveal meta-label mb-7">
                {index ? `${index} / ${label}` : label}
              </div>
            )}
            {title && (
              <h2
                id={id ? `${id}-heading` : undefined}
                className="reveal reveal-delay-1 display-lg"
              >
                {title}
              </h2>
            )}
            {subtitle && (
              <p className="reveal reveal-delay-2 section-subtitle">{subtitle}</p>
            )}
          </header>
        )}
        {children}
      </div>
    </section>
  )
}
