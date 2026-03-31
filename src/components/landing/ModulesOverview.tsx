const modules = [
  { emoji: '🗺️', title: 'Interaktive Karte', desc: 'Alle Angebote & Anfragen in deiner Umgebung auf einen Blick' },
  { emoji: '🆘', title: 'Retter-System', desc: 'Lebensmittel, Kleidung und mehr retten und verteilen' },
  { emoji: '🐾', title: 'Tierbereich', desc: 'Tierheime, Vermittlung, Gassi-Hilfe und Tierhilfe' },
  { emoji: '🏡', title: 'Wohnen & Alltag', desc: 'Wohnungssuche, Notunterkünfte und Haushaltshilfe' },
  { emoji: '🌾', title: 'Regionale Versorgung', desc: 'Bauernhöfe, regionale Produkte und Erntehilfe' },
  { emoji: '🧠', title: 'Bildung & Wissen', desc: 'Guides, Tutorials und Community-Wissen teilen' },
  { emoji: '🧘', title: 'Mentale Unterstützung', desc: 'Gesprächspartner, anonyme Hilfe und lokale Treffen' },
  { emoji: '🛠️', title: 'Skill-Netzwerk', desc: 'Fähigkeiten anbieten, lernen und voneinander profitieren' },
  { emoji: '🚗', title: 'Mobilität', desc: 'Mitfahrgelegenheiten und Transporthilfe koordinieren' },
  { emoji: '🧺', title: 'Teilen & Tauschen', desc: 'Geräte, Kleidung und Bücher tauschen oder verschenken' },
  { emoji: '📢', title: 'Community', desc: 'Lokale Abstimmungen, Projekte und gemeinsame Lösungen' },
  { emoji: '🚑', title: 'Krisensystem', desc: 'Schnelle Hilfe im Notfall – direkt und koordiniert' },
]

export default function ModulesOverview() {
  return (
    <section className="py-24 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 bg-primary-100 text-primary-700 rounded-full text-sm font-medium mb-4">
            Alle Bereiche
          </div>
          <h2 className="section-title">
            16 Bereiche für{' '}
            <span className="text-primary-600">jede Lebenssituation</span>
          </h2>
          <p className="section-subtitle">
            Von Alltagshilfe bis Krisenunterstützung – Mensaena bietet für jeden Bedarf 
            den richtigen Bereich.
          </p>
        </div>

        {/* Modules Grid */}
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
          {modules.map((mod, i) => (
            <div
              key={i}
              className="group p-4 rounded-2xl bg-warm-50 border border-warm-100 hover:bg-primary-50 hover:border-primary-200 transition-all duration-200 cursor-pointer text-center hover:-translate-y-0.5 hover:shadow-card"
            >
              <div className="text-3xl mb-2 group-hover:scale-110 transition-transform duration-200">
                {mod.emoji}
              </div>
              <h3 className="text-xs font-semibold text-gray-900 mb-1 leading-tight">{mod.title}</h3>
              <p className="text-xs text-gray-500 leading-relaxed hidden sm:block">{mod.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
