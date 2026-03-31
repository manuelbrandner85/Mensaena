import ModulePageLayout from '@/components/modules/ModulePageLayout'
export default function SharingPage() {
  return (
    <ModulePageLayout
      title="Teilen & Tauschen"
      subtitle="Gemeinsam nutzen statt wegwerfen"
      emoji="🧺"
      description="Im Bereich Teilen & Tauschen findest du alles, was du brauchst – oder gibst weiter, was du nicht mehr benötigst. Nachhaltig, kostenlos und gemeinschaftlich."
      accentColor="bg-lime-100 text-lime-700"
      createHref="/dashboard/create"
      createLabel="Angebot erstellen"
      features={[
        { icon: '🔌', title: 'Geräte teilen', desc: 'Werkzeuge, Geräte und Elektronik verleihen.' },
        { icon: '👗', title: 'Kleidung tauschen', desc: 'Kleider-Tauschbörsen lokal organisieren.' },
        { icon: '📚', title: 'Bücher tauschen', desc: 'Bücher weitergeben und neue entdecken.' },
        { icon: '🧸', title: 'Spielzeug teilen', desc: 'Kinderspielzeug sinnvoll weitergeben.' },
        { icon: '🪴', title: 'Pflanzen teilen', desc: 'Ableger, Saatgut und Pflanzen tauschen.' },
        { icon: '🛋️', title: 'Möbel & Haushalt', desc: 'Möbel und Haushaltsgegenstände weitergeben.' },
      ]}
    />
  )
}
