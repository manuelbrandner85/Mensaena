import ModulePageLayout from '@/components/modules/ModulePageLayout'
export default function AnimalsPage() {
  return (
    <ModulePageLayout
      title="Tierbereich"
      subtitle="Tiere vermitteln, helfen und versorgen"
      emoji="🐾"
      description="Der Tierbereich verbindet Tierheime, Tierbesitzer und Tierfreunde. Finde Gassi-Helfer, vermittle Tiere oder melde vermisste Tiere."
      accentColor="bg-pink-100 text-pink-700"
      createHref="/dashboard/create"
      createLabel="Tier-Beitrag erstellen"
      features={[
        { icon: '🏠', title: 'Tierheime anzeigen', desc: 'Finde Tierheime und ihre Bewohner in deiner Nähe.' },
        { icon: '🐕', title: 'Tiere vermitteln', desc: 'Hilf Tieren, ein liebevolles Zuhause zu finden.' },
        { icon: '🆘', title: 'Tierhilfe anbieten', desc: 'Biete Hilfe für Tiere in Not an – Futter, Pflege, Vet.' },
        { icon: '🔍', title: 'Vermisste Tiere', desc: 'Melde vermisste oder gefundene Tiere in deiner Region.' },
        { icon: '🌳', title: 'Gassi-Helfer finden', desc: 'Finde zuverlässige Menschen für Spaziergänge.' },
        { icon: '💊', title: 'Tierarzthilfe', desc: 'Koordiniere Tierarztbesuche und medizinische Hilfe.' },
      ]}
    />
  )
}
