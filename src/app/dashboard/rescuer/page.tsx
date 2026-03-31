import ModulePageLayout from '@/components/modules/ModulePageLayout'
export default function RescuerPage() {
  return (
    <ModulePageLayout
      title="Retter-System"
      subtitle="Ressourcen retten, teilen und verteilen"
      emoji="📦"
      description="Das Retter-System verbindet Menschen, die Lebensmittel, Kleidung und andere Ressourcen retten und verteilen möchten. Erstelle Boxen, melde Bedarf oder biete Abholmöglichkeiten an."
      accentColor="bg-orange-100 text-orange-700"
      createHref="/dashboard/create"
      createLabel="Retter-Angebot erstellen"
      features={[
        { icon: '🍎', title: 'Lebensmittel retten', desc: 'Überschüssige Lebensmittel vor dem Wegwerfen retten und teilen.' },
        { icon: '👕', title: 'Kleidung anbieten', desc: 'Kleidung, die du nicht mehr brauchst, weitergeben.' },
        { icon: '📦', title: 'Boxen erstellen', desc: 'Erstelle eine Retterbox mit allem, was du abgeben möchtest.' },
        { icon: '🚗', title: 'Abholung organisieren', desc: 'Koordiniere Abholzeiten und Treffpunkte einfach.' },
        { icon: '📋', title: 'Bedarf melden', desc: 'Teile mit, was du benötigst – andere können helfen.' },
        { icon: '🤝', title: 'Netzwerk aufbauen', desc: 'Vernetze dich mit anderen Rettern in deiner Region.' },
      ]}
    />
  )
}
