import Link from 'next/link'
import Image from 'next/image'
import { ArrowLeft } from 'lucide-react'

interface LegalPageShellProps {
  index: string
  eyebrow: string
  title: string
  intro?: string
  children: React.ReactNode
}

/**
 * LegalPageShell — editorial chrome for legal/static pages
 * (Impressum, Datenschutz, AGB, Nutzungsbedingungen, Kontakt, ...).
 *
 * Cinematic premium edition: layered ambient orbs, depth grid overlay,
 * material card-depth surface for the prose container.
 */
export default function LegalPageShell({
  index,
  eyebrow,
  title,
  intro,
  children,
}: LegalPageShellProps) {
  return (
    <div className="min-h-dvh bg-mn-void relative overflow-hidden">
      {/* ── Cinematic ambient depth ── */}
      <div
        className="hero-orb-1 absolute pointer-events-none"
        style={{ top: '-15%', left: '-12%', width: '55vw', height: '55vw' }}
        aria-hidden="true"
      />
      <div
        className="hero-orb-2 absolute pointer-events-none"
        style={{ top: '20%', right: '-15%', width: '45vw', height: '45vw' }}
        aria-hidden="true"
      />
      <div
        className="hero-orb-3 absolute pointer-events-none"
        style={{ bottom: '-10%', left: '20%', width: '38vw', height: '38vw' }}
        aria-hidden="true"
      />

      {/* ── Depth grid overlay ── */}
      <div
        className="absolute inset-0 depth-grid-overlay pointer-events-none opacity-60"
        aria-hidden="true"
      />

      {/* ── Film grain ── */}
      <div className="mesh-grain absolute inset-0 pointer-events-none" aria-hidden="true" />

      {/* ── Edge vignette (dark fade for cinematic framing) ── */}
      <div
        className="absolute inset-x-0 top-0 h-40 pointer-events-none"
        style={{ background: 'linear-gradient(to bottom, rgba(10,20,32,0.60) 0%, transparent 100%)' }}
        aria-hidden="true"
      />

      <div className="relative max-w-3xl mx-auto px-4 sm:px-6 py-12 md:py-20">
        {/* Logo lockup */}
        <Link
          href="/"
          className="group inline-flex items-center gap-2.5 mb-12 reveal is-visible"
          aria-label="Zurück zur Startseite"
        >
          <Image
            src="/mensaena-logo.png"
            alt="Mensaena Logo"
            width={72}
            height={48}
            className="h-12 w-auto object-contain transition-transform duration-500 group-hover:rotate-[-4deg]"
            priority
          />
          <span className="font-display text-2xl font-medium text-mn-ink tracking-tight">
            Mensaena<span className="text-mn-bronze">.</span>
          </span>
        </Link>

        {/* Editorial header */}
        <header className="mb-10 md:mb-14">
          <div className="meta-label meta-label--subtle mb-5">
            {index} / {eyebrow}
          </div>
          <h1 className="page-title">{title}</h1>
          {intro && (
            <p className="page-subtitle mt-4 max-w-2xl">{intro}</p>
          )}
          <div
            className="mt-7 h-px"
            style={{
              background:
                'linear-gradient(90deg, rgba(30,170,166,0.35) 0%, rgba(30,170,166,0.12) 40%, transparent 100%)',
            }}
          />
        </header>

        {/* Prose card — premium cinematic depth surface */}
        <article className="card-depth p-7 md:p-12">
          <div className="prose prose-sm md:prose-base max-w-none text-mn-ink-soft prose-headings:font-display prose-headings:font-medium prose-headings:text-mn-ink prose-headings:tracking-tight prose-a:text-mn-bronze prose-a:no-underline hover:prose-a:text-primary-800 prose-strong:text-mn-ink">
            {children}
          </div>
        </article>

        {/* Back link */}
        <div className="mt-12 text-center">
          <Link
            href="/"
            className="link-sweep inline-flex items-center gap-2 text-xs font-semibold tracking-[0.14em] uppercase text-mn-mute hover:text-mn-ink-soft transition-colors"
          >
            <ArrowLeft className="w-3 h-3" />
            Zurück zur Startseite
          </Link>
        </div>
      </div>
    </div>
  )
}
