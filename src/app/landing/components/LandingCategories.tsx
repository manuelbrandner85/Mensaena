'use client'

import {
  HandHeart,
  HelpCircle,
  Wrench,
  Calendar,
  Repeat,
  Car,
  AlertTriangle,
} from 'lucide-react'
import LandingSection from './LandingSection'

const categories = [
  { Icon: HandHeart,     label: 'Hilfe anbieten',     example: 'Ich kann beim Einkaufen helfen.' },
  { Icon: HelpCircle,    label: 'Hilfe suchen',        example: 'Wer kann mir beim Umzug helfen?' },
  { Icon: Wrench,        label: 'Werkzeug leihen',     example: 'Bohrmaschine für zwei Tage.' },
  { Icon: Calendar,      label: 'Veranstaltungen',     example: 'Straßenfest am Samstag.' },
  { Icon: Repeat,        label: 'Tausch & Schenk',     example: 'Kinderbücher zu verschenken.' },
  { Icon: Car,           label: 'Mitfahrgelegenheit',  example: 'Fahre Freitag nach München.' },
  { Icon: AlertTriangle, label: 'Krisenhilfe',         example: 'Hochwasser — Sandsäcke nötig.' },
]

export default function LandingCategories() {
  return (
    <LandingSection
      id="categories"
      background="stone"
      index="05"
      label="Kategorien"
      title={
        <>
          Für jede Situation die passende <span className="text-accent">Form</span> der Hilfe.
        </>
      }
    >
      <div className="divide-y divide-stone-300 border-t border-b border-stone-300">
        {categories.map((cat, i) => (
          <CategoryRow key={i} {...cat} index={i} />
        ))}
      </div>
    </LandingSection>
  )
}

function CategoryRow({
  Icon,
  label,
  example,
  index,
}: {
  Icon: React.ComponentType<{ className?: string }>
  label: string
  example: string
  index: number
}) {
  const num = String(index + 1).padStart(2, '0')
  return (
    <div
      className={`reveal reveal-delay-${Math.min(index + 1, 5)} group flex items-center gap-6 md:gap-12 py-8 md:py-10 transition-colors duration-500 hover:bg-paper/60`}
    >
      <div className="meta-label meta-label--subtle w-12 shrink-0">{num}</div>
      <div className="flex-1 min-w-0">
        <h3 className="font-display text-2xl md:text-3xl text-ink-800 tracking-tight leading-tight group-hover:text-primary-700 transition-colors duration-500">
          {label}
        </h3>
        <p className="text-ink-500 text-sm md:text-base italic mt-2">„{example}"</p>
      </div>
      <Icon
        className="w-6 h-6 md:w-7 md:h-7 text-ink-300 group-hover:text-primary-600 transition-colors duration-500"
        aria-hidden="true"
      />
    </div>
  )
}
