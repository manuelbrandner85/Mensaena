'use client'

import { HandHeart, HelpCircle, Wrench, Calendar, Repeat, Car, AlertTriangle } from 'lucide-react'
import LandingSection from './LandingSection'
import { useScrollAnimation } from '../hooks/useScrollAnimation'

const categories = [
  {
    Icon: HandHeart,
    label: 'Hilfe anbieten',
    color: 'teal',
    example: '„Ich kann beim Einkaufen helfen"',
  },
  {
    Icon: HelpCircle,
    label: 'Hilfe suchen',
    color: 'blue',
    example: '„Wer kann mir beim Umzug helfen?"',
  },
  {
    Icon: Wrench,
    label: 'Werkzeug leihen',
    color: 'amber',
    example: '„Bohrmaschine für 2 Tage"',
  },
  {
    Icon: Calendar,
    label: 'Veranstaltungen',
    color: 'purple',
    example: '„Straßenfest am Samstag!"',
  },
  {
    Icon: Repeat,
    label: 'Tausch & Schenk',
    color: 'pink',
    example: '„Kinderbücher zu verschenken"',
  },
  {
    Icon: Car,
    label: 'Mitfahrgelegenheit',
    color: 'cyan',
    example: '„Fahre Freitag nach München"',
  },
  {
    Icon: AlertTriangle,
    label: 'Krisenhilfe',
    color: 'red',
    example: '„Hochwasser: Sandsäcke nötig!"',
  },
]

const colorMap: Record<string, { bg: string; icon: string; border: string }> = {
  teal:   { bg: 'bg-primary-100', icon: 'text-primary-600', border: 'hover:border-primary-300' },
  blue:   { bg: 'bg-trust-100', icon: 'text-trust-400', border: 'hover:border-trust-200' },
  amber:  { bg: 'bg-amber-100', icon: 'text-amber-600', border: 'hover:border-amber-300' },
  purple: { bg: 'bg-purple-100', icon: 'text-purple-600', border: 'hover:border-purple-300' },
  pink:   { bg: 'bg-pink-100', icon: 'text-pink-600', border: 'hover:border-pink-300' },
  cyan:   { bg: 'bg-cyan-100', icon: 'text-cyan-600', border: 'hover:border-cyan-300' },
  red:    { bg: 'bg-red-100', icon: 'text-red-600', border: 'hover:border-red-300' },
}

export default function LandingCategories() {
  return (
    <LandingSection id="categories" background="gradient">
      <h2
        id="categories-heading"
        className="text-3xl md:text-4xl font-bold text-center text-gray-900"
      >
        Für jede Situation die richtige Kategorie
      </h2>

      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mt-12">
        {categories.map((cat, i) => (
          <CategoryCard key={i} {...cat} index={i} />
        ))}
      </div>

      <p className="text-gray-600 text-center mt-8 text-sm">
        ...und es kommen ständig neue dazu.
      </p>
    </LandingSection>
  )
}

function CategoryCard({
  Icon,
  label,
  color,
  example,
  index,
}: {
  Icon: React.ComponentType<{ className?: string }>
  label: string
  color: string
  example: string
  index: number
}) {
  const { ref, isVisible } = useScrollAnimation()
  const colors = colorMap[color] ?? colorMap.teal

  return (
    <div
      ref={ref}
      className={`bg-white rounded-xl p-5 border border-warm-100 ${colors.border} transition-colors duration-200 ${
        isVisible ? 'animate-fade-up' : 'opacity-0'
      }`}
      style={{ animationDelay: `${index * 80}ms` }}
    >
      <div
        className={`w-10 h-10 ${colors.bg} rounded-lg flex items-center justify-center`}
      >
        <Icon className={`w-5 h-5 ${colors.icon}`} aria-hidden="true" />
      </div>
      <p className="font-semibold text-gray-900 mt-3 text-sm">{label}</p>
      <p className="text-sm text-gray-500 italic mt-1">{example}</p>
    </div>
  )
}
