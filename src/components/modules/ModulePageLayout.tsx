import Link from 'next/link'
import { ArrowRight, Plus } from 'lucide-react'
import type { LucideIcon } from 'lucide-react'

interface ModulePageProps {
  title: string
  subtitle: string
  emoji: string
  description: string
  features: { icon: string; title: string; desc: string; href?: string }[]
  createHref?: string
  createLabel?: string
  accentColor?: string
}

export default function ModulePageLayout({
  title,
  subtitle,
  emoji,
  description,
  features,
  createHref,
  createLabel = 'Neuen Eintrag erstellen',
  accentColor = 'bg-primary-100 text-primary-700',
}: ModulePageProps) {
  return (
    <div className="max-w-5xl">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4 mb-8">
        <div className="flex items-start gap-4">
          <div className={`w-14 h-14 rounded-2xl ${accentColor} flex items-center justify-center text-2xl flex-shrink-0`}>
            {emoji}
          </div>
          <div>
            <h1 className="text-2xl font-bold text-gray-900">{title}</h1>
            <p className="text-sm text-gray-500 mt-0.5">{subtitle}</p>
          </div>
        </div>
        {createHref && (
          <Link href={createHref} className="btn-primary flex-shrink-0">
            <Plus className="w-4 h-4" />
            {createLabel}
          </Link>
        )}
      </div>

      {/* Description */}
      <div className="card p-6 mb-6 bg-gradient-to-br from-warm-50 to-white border-warm-100">
        <p className="text-gray-700 leading-relaxed">{description}</p>
      </div>

      {/* Features Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
        {features.map((feature, i) => (
          <div
            key={i}
            className="card p-5 hover:shadow-hover hover:-translate-y-0.5 transition-all duration-200 group"
          >
            <div className="text-2xl mb-3">{feature.icon}</div>
            <h3 className="font-semibold text-gray-900 text-sm mb-1.5">{feature.title}</h3>
            <p className="text-xs text-gray-600 leading-relaxed">{feature.desc}</p>
            {feature.href && (
              <Link
                href={feature.href}
                className="inline-flex items-center gap-1 text-xs text-primary-600 font-medium mt-3 opacity-0 group-hover:opacity-100 transition-opacity"
              >
                Öffnen <ArrowRight className="w-3 h-3" />
              </Link>
            )}
          </div>
        ))}
      </div>

      {/* Empty State */}
      <div className="card p-12 text-center border-dashed border-2 border-warm-200">
        <div className="text-5xl mb-4">{emoji}</div>
        <h3 className="text-lg font-semibold text-gray-800 mb-2">Noch keine Einträge</h3>
        <p className="text-sm text-gray-500 mb-5">
          Sei der Erste in deiner Region und erstelle einen Eintrag für diesen Bereich.
        </p>
        {createHref && (
          <Link href={createHref} className="btn-primary justify-center">
            <Plus className="w-4 h-4" />
            {createLabel}
          </Link>
        )}
      </div>
    </div>
  )
}
