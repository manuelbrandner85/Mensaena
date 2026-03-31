import { Leaf, Users, MapPin, Recycle, Shield, MessageCircle } from 'lucide-react'

const features = [
  {
    icon: <Users className="w-6 h-6" />,
    title: 'Hilfe organisieren',
    description:
      'Suche oder biete konkrete Hilfe in deiner Nachbarschaft. Von Arztbegleitung bis Umzugshilfe – direkt und unkompliziert.',
    color: 'bg-primary-100 text-primary-700',
    href: '/dashboard',
  },
  {
    icon: <Recycle className="w-6 h-6" />,
    title: 'Ressourcen teilen',
    description:
      'Verschenke, tausche oder verleihe Dinge. Gemeinsam nutzen statt wegwerfen – nachhaltig und sinnvoll.',
    color: 'bg-sage-100 text-sage-500',
    href: '/dashboard/sharing',
  },
  {
    icon: <MapPin className="w-6 h-6" />,
    title: 'Lokale Angebote finden',
    description:
      'Die interaktive Karte zeigt alle Angebote und Anfragen in deiner Umgebung. Filtere nach Kategorie und Entfernung.',
    color: 'bg-trust-100 text-trust-400',
    href: '/dashboard/map',
  },
  {
    icon: <Leaf className="w-6 h-6" />,
    title: 'Nachhaltige Unterstützung',
    description:
      'Regionale Produkte, Erntehilfe, Selbstversorgung – Mensaena fördert eine nachhaltige, gemeinschaftliche Lebensweise.',
    color: 'bg-green-100 text-green-700',
    href: '/dashboard/supply',
  },
  {
    icon: <Shield className="w-6 h-6" />,
    title: 'Vertrauensvolles Profil',
    description:
      'Baue dein Vertrauens-Profil auf. Bewertungen, Fähigkeiten und Erfahrungen machen Interaktionen sicherer.',
    color: 'bg-blue-100 text-blue-700',
    href: '/dashboard/profile',
  },
  {
    icon: <MessageCircle className="w-6 h-6" />,
    title: 'Direkte Kommunikation',
    description:
      'Schreibe direkte Nachrichten, nutze Gruppenchats oder kontaktiere Nutzer per WhatsApp und Telefon.',
    color: 'bg-purple-100 text-purple-700',
    href: '/dashboard/chat',
  },
]

export default function FeaturesSection() {
  return (
    <section id="features" className="py-24 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 bg-primary-100 text-primary-700 rounded-full text-sm font-medium mb-4">
            Was Mensaena kann
          </div>
          <h2 className="section-title">
            Alle wichtigen Funktionen auf{' '}
            <span className="text-primary-600">einem Blick</span>
          </h2>
          <p className="section-subtitle">
            Mensaena bündelt alle Werkzeuge für ein aktives, vernetztes und nachhaltiges Miteinander 
            in einer übersichtlichen Plattform.
          </p>
        </div>

        {/* Features Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((feature, i) => (
            <FeatureCard key={i} {...feature} />
          ))}
        </div>
      </div>
    </section>
  )
}

function FeatureCard({
  icon, title, description, color,
}: {
  icon: React.ReactNode
  title: string
  description: string
  color: string
  href: string
}) {
  return (
    <div className="group card p-6 hover:shadow-hover hover:-translate-y-0.5 transition-all duration-200 cursor-pointer">
      {/* Icon */}
      <div className={`w-12 h-12 rounded-xl ${color} flex items-center justify-center mb-4 group-hover:scale-110 transition-transform duration-200`}>
        {icon}
      </div>

      {/* Content */}
      <h3 className="text-lg font-semibold text-gray-900 mb-2">{title}</h3>
      <p className="text-sm text-gray-600 leading-relaxed">{description}</p>
    </div>
  )
}
