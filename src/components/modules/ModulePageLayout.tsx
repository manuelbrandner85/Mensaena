import Link from 'next/link'
import { ArrowRight, Plus } from 'lucide-react'

interface ModulePageProps {
  title: string
  subtitle: string
  emoji: string
  description: string
  features: { icon: string; title: string; desc: string; href?: string }[]
  createHref?: string
  createLabel?: string
  accentColor?: string
  index?: string
}

export default function ModulePageLayout({
  title,
  subtitle,
  emoji,
  description,
  features,
  createHref,
  createLabel = 'Neuen Eintrag erstellen',
  accentColor = 'bg-primary-50 text-primary-700 border border-primary-100',
  index = '§',
}: ModulePageProps) {
  return (
    <div className="max-w-6xl mx-auto">
      {/* Editorial header */}
      <header className="mb-10 md:mb-14">
        <div className="meta-label meta-label--subtle mb-5">
          {index} / {subtitle}
        </div>
        <div className="flex flex-col md:flex-row md:items-end md:justify-between gap-6">
          <div className="flex items-start gap-5 min-w-0">
            <div className={`w-16 h-16 rounded-2xl ${accentColor} flex items-center justify-center text-3xl flex-shrink-0 float-idle`}>
              {emoji}
            </div>
            <div className="min-w-0">
              <h1 className="page-title">{title}</h1>
              <p className="page-subtitle mt-3 max-w-2xl">{description}</p>
            </div>
          </div>
          {createHref && (
            <Link
              href={createHref}
              className="magnetic shine inline-flex items-center justify-center gap-2 bg-ink-800 hover:bg-ink-700 text-paper px-5 py-3 rounded-full text-sm font-medium tracking-wide transition-colors flex-shrink-0"
            >
              <Plus className="w-4 h-4" />
              {createLabel}
            </Link>
          )}
        </div>
        <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
      </header>

      {/* Features grid */}
      <section className="mb-12">
        <div className="meta-label meta-label--subtle mb-5">Funktionen</div>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {features.map((feature, i) => {
            const body = (
              <>
                <div className="text-2xl mb-3 transition-transform duration-500 group-hover:scale-110 group-hover:rotate-[-4deg] origin-left">{feature.icon}</div>
                <h3 className="font-display text-lg font-medium text-ink-800 mb-1.5 tracking-tight">{feature.title}</h3>
                <p className="text-[13px] text-ink-500 leading-relaxed">{feature.desc}</p>
                {feature.href && (
                  <div className="inline-flex items-center gap-1 text-xs tracking-[0.14em] uppercase text-primary-700 font-semibold mt-4 opacity-0 -translate-x-1 group-hover:opacity-100 group-hover:translate-x-0 transition-all duration-300">
                    Öffnen <ArrowRight className="w-3 h-3" />
                  </div>
                )}
              </>
            )
            const classes = 'editorial-card editorial-card-hover tilt spotlight p-6 group block'
            return feature.href ? (
              <Link key={i} href={feature.href} className={classes}>
                {body}
              </Link>
            ) : (
              <div key={i} className={classes}>
                {body}
              </div>
            )
          })}
        </div>
      </section>

      {/* Empty state */}
      <section className="editorial-card spotlight p-12 md:p-16 text-center border-dashed">
        <div className="text-6xl mb-5 float-idle inline-block">{emoji}</div>
        <div className="meta-label meta-label--subtle justify-center mb-3">Noch leer</div>
        <h3 className="font-display text-2xl md:text-3xl font-medium text-ink-800 mb-3 tracking-tight">
          Sei der <span className="text-accent">Erste</span> in deiner Region
        </h3>
        <p className="text-sm text-ink-500 mb-6 max-w-md mx-auto leading-relaxed">
          Hier entsteht gerade etwas Neues. Erstelle den ersten Eintrag und setze den Ton für deine Nachbarschaft.
        </p>
        {createHref && (
          <Link
            href={createHref}
            className="magnetic shine inline-flex items-center justify-center gap-2 bg-ink-800 hover:bg-ink-700 text-paper px-6 py-3 rounded-full text-sm font-medium tracking-wide transition-colors"
          >
            <Plus className="w-4 h-4" />
            {createLabel}
          </Link>
        )}
      </section>
    </div>
  )
}
