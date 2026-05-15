'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'

/**
 * CinemaAppBar — sticky top nav für Cinema-Routes.
 *
 * Glassmorphism mit backdrop-blur und backdrop-saturate.
 * Untere Kante: amber Gradient-Linie via ::after.
 * Logo-Tracking 5px mit text-shadow amber Glow.
 */
type Link = { label: string; href: string }

const DEFAULT_LINKS: Link[] = [
  { label: 'So funktioniert’s', href: '#wie-es-funktioniert' },
  { label: 'Prinzipien',           href: '#prinzipien'           },
  { label: 'Stimmen',              href: '#stimmen'              },
  { label: 'Spenden',              href: '/spenden'              },
]

export default function CinemaAppBar({
  links = DEFAULT_LINKS,
  ctaLabel = 'Anmelden',
  ctaHref = '/auth',
}: {
  links?: Link[]
  ctaLabel?: string
  ctaHref?: string
}) {
  const [scrolled, setScrolled] = useState(false)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12)
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <header
      className="cinema-appbar sticky top-0 z-50 transition-all duration-300"
      style={{
        background:    scrolled ? 'rgba(10,15,28,0.78)' : 'rgba(10,15,28,0.55)',
        backdropFilter: 'blur(18px) saturate(1.4)',
        WebkitBackdropFilter: 'blur(18px) saturate(1.4)',
      }}
    >
      <div className="relative max-w-7xl mx-auto px-5 sm:px-8 h-16 flex items-center justify-between">
        {/* Logo */}
        <Link
          href="/"
          className="font-sans font-bold text-mn-ink tracking-[5px] text-sm sm:text-base"
          style={{
            textShadow:
              '0 0 20px rgba(199,147,99,0.30), 0 0 60px rgba(199,147,99,0.10)',
          }}
        >
          MENSAENA
        </Link>

        {/* Desktop links */}
        <nav className="hidden md:flex items-center gap-7">
          {links.map((l) => (
            <a
              key={l.href}
              href={l.href}
              className="text-sm text-mn-ink-soft hover:text-mn-ink transition-colors"
            >
              {l.label}
            </a>
          ))}
        </nav>

        {/* CTA */}
        <Link
          href={ctaHref}
          className="text-sm font-medium px-4 py-2 rounded-full text-mn-ink border border-white/10 hover:border-mn-bronze/40 hover:text-mn-bronze transition-colors"
        >
          {ctaLabel}
        </Link>

        {/* Bottom amber gradient line */}
        <span
          aria-hidden="true"
          className="absolute left-0 right-0 bottom-0 h-px"
          style={{
            background:
              'linear-gradient(to right, transparent, rgba(199,147,99,0.20), transparent)',
            opacity: scrolled ? 1 : 0.4,
            transition: 'opacity 0.3s ease',
          }}
        />
      </div>
    </header>
  )
}
