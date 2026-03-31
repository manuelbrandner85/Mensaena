import { CheckCircle2 } from 'lucide-react'

const benefits = [
  {
    title: 'Vertrauenswürdig',
    points: [
      'Verifizierte Profile mit Bewertungssystem',
      'Transparente Nutzungshistorie',
      'Community-basiertes Vertrauen',
    ],
    icon: '🛡️',
    color: 'from-trust-50 to-trust-100/50',
    border: 'border-trust-200',
  },
  {
    title: 'Einfach & übersichtlich',
    points: [
      'Intuitive Navigation ohne Lernkurve',
      'Klare Kategorien und Filter',
      'Moderne, aufgeräumte Oberfläche',
    ],
    icon: '✨',
    color: 'from-primary-50 to-sage-50',
    border: 'border-primary-200',
  },
  {
    title: 'Lokal & persönlich',
    points: [
      'Interaktive Karte für deine Region',
      'Ortsbezogene Suche und Angebote',
      'Direkte Kontaktmöglichkeiten',
    ],
    icon: '📍',
    color: 'from-warm-100 to-warm-50',
    border: 'border-warm-300',
  },
  {
    title: 'Soziale Wirkung',
    points: [
      'Sichtbare Impact-Scores',
      'Community-Projekte und Abstimmungen',
      'Positiver Beitrag für die Gesellschaft',
    ],
    icon: '🌱',
    color: 'from-green-50 to-primary-50',
    border: 'border-green-200',
  },
]

export default function WhyMensaena() {
  return (
    <section id="why-mensaena" className="py-24 section-gradient-alt">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 bg-warm-200 text-gray-700 rounded-full text-sm font-medium mb-4">
            Warum Mensaena?
          </div>
          <h2 className="section-title">
            Eine Plattform, der du{' '}
            <span className="text-primary-600">wirklich vertrauen</span> kannst
          </h2>
          <p className="section-subtitle">
            Mensaena wurde mit einem klaren Ziel entwickelt: Menschen zusammenbringen, 
            ohne Ablenkung, ohne Lärm, ohne Kommerz.
          </p>
        </div>

        {/* Benefits Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {benefits.map((benefit, i) => (
            <div
              key={i}
              className={`p-6 rounded-2xl bg-gradient-to-br ${benefit.color} border ${benefit.border} hover:shadow-card transition-all duration-200`}
            >
              <div className="flex items-start gap-4">
                <span className="text-3xl">{benefit.icon}</span>
                <div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-3">{benefit.title}</h3>
                  <ul className="space-y-2">
                    {benefit.points.map((point, j) => (
                      <li key={j} className="flex items-center gap-2 text-sm text-gray-700">
                        <CheckCircle2 className="w-4 h-4 text-primary-600 flex-shrink-0" />
                        {point}
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* Stats Row */}
        <div className="mt-16 grid grid-cols-2 md:grid-cols-4 gap-6">
          {[
            { value: '100%', label: 'Kostenlos', sub: 'für alle Nutzer' },
            { value: '16+', label: 'Bereiche', sub: 'in einer Plattform' },
            { value: '🗺️', label: 'Interaktive Karte', sub: 'als Herzstück' },
            { value: '0€', label: 'Keine Werbung', sub: 'kein Kommerz' },
          ].map((stat, i) => (
            <div key={i} className="text-center p-5 bg-white rounded-2xl shadow-soft border border-warm-100">
              <div className="text-2xl md:text-3xl font-bold text-primary-600 mb-1">{stat.value}</div>
              <div className="text-sm font-semibold text-gray-800">{stat.label}</div>
              <div className="text-xs text-gray-500 mt-0.5">{stat.sub}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
