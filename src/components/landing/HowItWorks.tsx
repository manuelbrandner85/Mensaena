import { UserPlus, FileEdit, Search, Zap } from 'lucide-react'

const steps = [
  {
    step: '01',
    icon: <UserPlus className="w-6 h-6" />,
    title: 'Registrieren',
    description:
      'Erstelle deinen kostenlosen Account in weniger als 2 Minuten. Keine Kreditkarte, kein Abo.',
    color: 'bg-primary-100 text-primary-700',
  },
  {
    step: '02',
    icon: <FileEdit className="w-6 h-6" />,
    title: 'Profil anlegen',
    description:
      'Füge deinen Standort, deine Fähigkeiten und Interessen hinzu, damit andere dich finden können.',
    color: 'bg-trust-100 text-trust-400',
  },
  {
    step: '03',
    icon: <Search className="w-6 h-6" />,
    title: 'Inhalte entdecken',
    description:
      'Durchsuche die interaktive Karte, finde Hilfe-Angebote oder erstelle deinen eigenen Beitrag.',
    color: 'bg-warm-200 text-amber-700',
  },
  {
    step: '04',
    icon: <Zap className="w-6 h-6" />,
    title: 'Aktiv werden',
    description:
      'Schreibe Nachrichten, helf anderen, teile Ressourcen und gestalte deine Gemeinschaft aktiv mit.',
    color: 'bg-green-100 text-green-700',
  },
]

export default function HowItWorks() {
  return (
    <section id="how-it-works" className="py-24 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="text-center max-w-2xl mx-auto mb-16">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 bg-primary-100 text-primary-700 rounded-full text-sm font-medium mb-4">
            So einfach geht es
          </div>
          <h2 className="section-title">
            In 4 Schritten zur{' '}
            <span className="text-primary-600">aktiven Gemeinschaft</span>
          </h2>
          <p className="section-subtitle">
            Mensaena ist bewusst einfach gehalten. Kein Kompliziertes Setup, keine langen Lernphasen.
          </p>
        </div>

        {/* Steps */}
        <div className="relative">
          {/* Connector Line (Desktop) */}
          <div className="absolute top-12 left-[12.5%] right-[12.5%] h-0.5 bg-gradient-to-r from-primary-200 via-primary-400 to-green-300 hidden lg:block" />

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8">
            {steps.map((step, i) => (
              <div key={i} className="relative text-center">
                {/* Step Number + Icon */}
                <div className="flex flex-col items-center mb-5">
                  <div className="relative">
                    <div className={`w-16 h-16 rounded-2xl ${step.color} flex items-center justify-center shadow-soft relative z-10`}>
                      {step.icon}
                    </div>
                    <span className="absolute -top-2 -right-2 w-6 h-6 bg-primary-600 text-white text-xs font-bold rounded-full flex items-center justify-center z-20">
                      {step.step}
                    </span>
                  </div>
                </div>

                {/* Content */}
                <h3 className="text-base font-semibold text-gray-900 mb-2">{step.title}</h3>
                <p className="text-sm text-gray-600 leading-relaxed">{step.description}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}
