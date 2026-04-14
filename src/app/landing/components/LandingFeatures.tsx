'use client'

import { MapPin, HandHeart, Shield, MessageCircle, Heart, Zap } from 'lucide-react'
import LandingSection from './LandingSection'

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
    title: 'Gemeinnützig',
    description:
      'Mensaena ist kostenlos, werbefrei und gehört der Gemeinschaft. Keine versteckten Kosten, keine Datenverkäufe, kein Profit.',
  },
  {
    Icon: Zap,
    title: 'Krisenhilfe',
    description:
      'Bei Naturkatastrophen, Stromausfällen oder anderen Krisen aktiviert Mensaena den Krisenmodus für schnelle Nachbarschaftshilfe.',
  },
]

export default function LandingFeatures() {
  return (
    <LandingSection
      id="features"
      background="stone"
      index="03"
      label="Was Mensaena auszeichnet"
      title={
        <>
          Sechs Prinzipien, die den Unterschied
          <br />
          zwischen Plattform und <span className="text-accent">Gemeinschaft</span> machen.
        </>
      }
    >
      <div className="grid grid-cols-1 md:grid-cols-2 gap-x-12 gap-y-16">
        {features.map((feature, i) => (
          <FeatureItem key={i} {...feature} index={i} />
        ))}
      </div>
    </LandingSection>
  )
}

function FeatureItem({
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
  const num = String(index + 1).padStart(2, '0')
  return (
    <article
      className={`reveal reveal-delay-${Math.min(index + 1, 5)} border-t border-stone-300 pt-8`}
    >
      <div className="flex items-baseline justify-between mb-5">
        <div className="meta-label meta-label--subtle">{num}</div>
        <Icon className="w-5 h-5 text-primary-600" aria-hidden="true" />
      </div>
      <h3 className="font-display text-2xl md:text-3xl text-ink-800 leading-tight tracking-tight">
        {title}
      </h3>
      <p className="text-ink-500 text-[0.95rem] leading-relaxed mt-4 max-w-md">
        {description}
      </p>
    </article>
  )
}
