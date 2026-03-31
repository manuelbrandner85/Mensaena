import ModulePageLayout from '@/components/modules/ModulePageLayout'
export default function HousingPage() {
  return (
    <ModulePageLayout
      title="Wohnen & Alltag"
      subtitle="Wohnraum und Alltagshilfe vermitteln"
      emoji="🏡"
      description="Der Wohnbereich hilft Menschen, Wohnraum zu finden, Umzugshilfe zu erhalten oder Notunterkünfte zu koordinieren. Wohnen gegen Hilfe oder einfach menschliche Unterstützung im Alltag."
      accentColor="bg-blue-100 text-blue-700"
      createHref="/dashboard/create"
      createLabel="Wohn-Angebot erstellen"
      features={[
        { icon: '🔑', title: 'Wohnung suchen/anbieten', desc: 'Finde oder biete Wohnraum in deiner Region.' },
        { icon: '🛏️', title: 'Notunterkünfte', desc: 'Kurzfristige Unterkünfte für Menschen in Not.' },
        { icon: '🌿', title: 'Wohnen gegen Hilfe', desc: 'Tausche Wohnraum gegen Unterstützung.' },
        { icon: '🚚', title: 'Umzugshilfe', desc: 'Finde oder biete Hilfe beim Umzug.' },
        { icon: '🧹', title: 'Haushaltshilfe', desc: 'Unterstützung im Alltag – Reinigung, Einkauf, mehr.' },
        { icon: '🔧', title: 'Handwerker-Hilfe', desc: 'Kleine Reparaturen und handwerkliche Unterstützung.' },
      ]}
    />
  )
}
