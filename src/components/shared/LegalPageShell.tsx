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
 * Provides a paper background with aurora backdrop, a logo lockup, an
 * editorial header (meta label + Fraunces title + intro), and an
 * editorial-card wrapper for the prose content.
 */
export default function LegalPageShell({
  index,
  eyebrow,
  title,
  intro,
  children,
}: LegalPageShellProps) {
  return (
    <div className="min-h-dvh bg-paper aurora-bg relative overflow-hidden">
      {/* Decorative mesh + grain */}
      <div className="mesh-gradient" aria-hidden="true" />
      <div className="mesh-grain absolute inset-0 pointer-events-none" aria-hidden="true" />

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
          <span className="font-display text-2xl font-medium text-ink-800 tracking-tight">
            Mensaena<span className="text-primary-500">.</span>
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
          <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
        </header>

        {/* Prose card */}
        <article className="editorial-card spotlight p-6 md:p-10">
          <div className="prose prose-sm md:prose-base max-w-none text-ink-700 prose-headings:font-display prose-headings:font-medium prose-headings:text-ink-800 prose-headings:tracking-tight prose-a:text-primary-700 prose-a:no-underline hover:prose-a:text-primary-800 prose-strong:text-ink-800">
            {children}
          </div>
        </article>

        {/* Back link */}
        <div className="mt-10 text-center">
          <Link
            href="/"
            className="link-sweep inline-flex items-center gap-2 text-xs font-semibold tracking-[0.14em] uppercase text-ink-400 hover:text-ink-700 transition-colors"
          >
            <ArrowLeft className="w-3 h-3" />
            Zurück zur Startseite
          </Link>
        </div>
      </div>
    </div>
  )
}
