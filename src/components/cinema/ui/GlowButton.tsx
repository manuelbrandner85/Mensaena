'use client'

import { useRef, type MouseEvent, type ButtonHTMLAttributes, type AnchorHTMLAttributes } from 'react'
import Link from 'next/link'
import { cn } from '@/lib/design-system'

type Variant = 'primary' | 'secondary' | 'ghost' | 'teal' | 'crisis' | 'danger'
type Size    = 'sm' | 'md' | 'lg'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  size?: Size
  href?: undefined
  pulse?: boolean
}
interface LinkProps extends AnchorHTMLAttributes<HTMLAnchorElement> {
  variant?: Variant
  size?: Size
  href: string
  pulse?: boolean
}
type GlowButtonProps = ButtonProps | LinkProps

const base = 'relative inline-flex items-center justify-center font-body font-medium tracking-wide transition-all duration-200 select-none focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-mn-amber focus-visible:ring-offset-2 focus-visible:ring-offset-mn-void active:scale-[0.96] disabled:opacity-40 disabled:pointer-events-none overflow-hidden'

const variants: Record<Variant, string> = {
  primary:   'glow-btn-cinema-primary',
  secondary: 'border border-mn-amber/50 text-mn-amber bg-mn-amber/5 hover:bg-mn-amber/12 hover:border-mn-amber/70 hover:shadow-[0_0_24px_rgba(245,158,11,0.20)]',
  ghost:     'text-mn-ink-soft bg-white/[0.04] border border-white/8 hover:bg-white/8 hover:text-mn-ink hover:border-white/15',
  teal:      'bg-gradient-to-br from-mn-teal to-mn-teal-soft text-mn-void font-semibold shadow-[0_4px_18px_rgba(14,165,233,0.35),0_0_40px_rgba(14,165,233,0.12)] hover:shadow-[0_6px_24px_rgba(14,165,233,0.50),0_0_60px_rgba(14,165,233,0.22)]',
  crisis:    'bg-gradient-to-br from-mn-herzrot to-mn-herzrot-warm text-white font-semibold shadow-[0_4px_18px_rgba(239,68,68,0.40),0_0_40px_rgba(239,68,68,0.15)] animate-pulse hover:animate-none',
  danger:    'border border-mn-herzrot/50 text-mn-herzrot bg-mn-herzrot/5 hover:bg-mn-herzrot/12 hover:shadow-[0_0_24px_rgba(239,68,68,0.20)]',
}

const sizes: Record<Size, string> = {
  sm: 'h-8  px-4  text-xs  gap-1.5 rounded-button',
  md: 'h-10 px-6  text-sm  gap-2   rounded-button',
  lg: 'h-12 px-8  text-base gap-2.5 rounded-button',
}

export default function GlowButton({ variant = 'primary', size = 'md', pulse, ...props }: GlowButtonProps) {
  const ref = useRef<HTMLElement>(null)

  function trackMouse(e: MouseEvent) {
    const el = ref.current
    if (!el || variant !== 'primary') return
    const rect = el.getBoundingClientRect()
    const x = ((e.clientX - rect.left) / rect.width) * 100
    const y = ((e.clientY - rect.top) / rect.height) * 100
    ;(el as HTMLElement).style.setProperty('--mx', `${x}%`)
    ;(el as HTMLElement).style.setProperty('--my', `${y}%`)
  }

  const cls = cn(base, variants[variant], sizes[size], (props as ButtonProps).className)

  if ((props as LinkProps).href !== undefined) {
    const { href, className: _c, ...rest } = props as LinkProps
    return (
      <Link href={href} ref={ref as React.Ref<HTMLAnchorElement>} className={cls} onMouseMove={trackMouse} {...rest}>
        {variant === 'primary' && (
          <span
            className="pointer-events-none absolute inset-0 opacity-0 group-hover:opacity-100"
            style={{ background: 'radial-gradient(circle at var(--mx,50%) var(--my,50%), rgba(255,255,255,0.15) 0%, transparent 60%)' }}
            aria-hidden
          />
        )}
        {rest.children}
      </Link>
    )
  }

  const { className: _c, ...rest } = props as ButtonProps
  return (
    <button ref={ref as React.Ref<HTMLButtonElement>} className={cls} onMouseMove={trackMouse} {...rest}>
      {variant === 'primary' && (
        <span
          className="pointer-events-none absolute inset-0"
          style={{ background: 'radial-gradient(circle at var(--mx,50%) var(--my,50%), rgba(255,255,255,0.12) 0%, transparent 60%)' }}
          aria-hidden
        />
      )}
      {rest.children}
    </button>
  )
}
