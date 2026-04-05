import { cn } from '@/lib/utils'

interface LandingSectionProps {
  children: React.ReactNode
  className?: string
  id?: string
  background?: 'white' | 'gray' | 'teal' | 'gradient'
}

const bgMap = {
  white: 'bg-white',
  gray: 'bg-gray-50',
  teal: 'bg-primary-50',
  gradient: 'bg-gradient-to-br from-primary-50 via-white to-primary-50',
}

export default function LandingSection({
  children,
  className,
  id,
  background = 'white',
}: LandingSectionProps) {
  return (
    <section
      id={id}
      className={cn('py-16 md:py-24 px-4', bgMap[background], className)}
      aria-labelledby={id ? `${id}-heading` : undefined}
    >
      <div className="max-w-7xl mx-auto">{children}</div>
    </section>
  )
}
