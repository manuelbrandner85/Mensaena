'use client'

import { MapPin, HandHeart, Shield, MessageCircle, Heart, Zap } from 'lucide-react'
import LandingSection from './LandingSection'
import { useScrollAnimation } from '../hooks/useScrollAnimation'

const features = [
  {
    Icon: MapPin,
    title: 'Hyperlokal',
    description:
      'Finde Hilfe und Angebote direkt in deiner Straße. Mit der interaktiven Karte siehst du auf einen Blick, was in deiner Nachbarschaft passiert.',
  },
  {
    Icon: HandHeart,
    title: 'Hilfe geben & nehmen',
    description:
      'Ob Einkaufshilfe, Werkzeug leihen oder Nachhilfe – biete an was du kannst und finde Unterstützung wenn du sie brauchst.',
  },
  {
    Icon: Shield,
    title: 'Vertrauen & Sicherheit',
    description:
      'Unser Bewertungssystem hilft dir, vertrauenswürdige Nachbarn zu erkennen. Melde- und Blockier-Funktionen sorgen für ein sicheres Miteinander.',
  },
  {
    Icon: MessageCircle,
    title: 'Direkter Kontakt',
    description:
      'Schreib deinen Nachbarn direkt über unseren Chat. Privat, sicher und ohne deine Telefonnummer teilen zu müssen.',
  },
  {
    Icon: Heart,
    title: '100% Gemeinnützig',
    description:
      'Mensaena ist kostenlos, werbefrei und gehört der Gemeinschaft. Keine versteckten Kosten, keine Datenverkäufe, kein Profit.',
  },
  {
    Icon: Zap,
    title: 'Krisenhilfe',
    description:
      'Bei Naturkatastrophen, Stromausfällen oder anderen Krisen: Mensaena aktiviert den Krisenmodus für schnelle Nachbarschaftshilfe.',
  },
]

export default function LandingFeatures() {
  return (
    <LandingSection id="features" background="gray">
      <h2
        id="features-heading"
        className="text-3xl md:text-4xl font-bold text-center text-gray-900"
      >
        Was Mensaena besonders macht
      </h2>
      <p className="text-gray-600 text-center mt-4 max-w-2xl mx-auto">
        Alles was du brauchst, um deine Nachbarschaft zu stärken
      </p>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mt-12">
        {features.map((feature, i) => (
          <FeatureCard key={i} {...feature} index={i} />
        ))}
      </div>
    </LandingSection>
  )
}

function FeatureCard({
  Icon,
  title,
  description,
  index,
}: {
  Icon: React.ComponentType<{ className?: string }>
  title: string
  description: string
  index: number
}) {
  const { ref, isVisible } = useScrollAnimation()

  return (
    <div
      ref={ref}
      className={`bg-white rounded-2xl p-6 md:p-8 shadow-sm hover:shadow-md hover:-translate-y-1 transition-all duration-300 border border-warm-100 ${
        isVisible ? 'animate-fade-up' : 'opacity-0'
      }`}
      style={{ animationDelay: `${index * 100}ms` }}
    >
      <div className="w-14 h-14 bg-primary-50 rounded-xl flex items-center justify-center">
        <Icon className="w-7 h-7 text-primary-500" aria-hidden="true" />
      </div>
      <h3 className="text-lg font-semibold text-gray-900 mt-4">{title}</h3>
      <p className="text-gray-600 text-sm mt-2 leading-relaxed">{description}</p>
    </div>
  )
}
