import ModulePageLayout from '@/components/modules/ModulePageLayout'
export default function MentalSupportPage() {
  return (
    <ModulePageLayout
      title="Mentale Unterstützung"
      subtitle="Zuhören, begleiten, stärken"
      emoji="🧘"
      description="Finde Menschen, die einfach zuhören. Mentale Gesundheit ist genauso wichtig wie körperliche. Hier findest du Gesprächspartner, anonyme Unterstützung und lokale Treffen in der Natur."
      accentColor="bg-teal-100 text-teal-700"
      createHref="/dashboard/create"
      createLabel="Unterstützung anbieten"
      features={[
        { icon: '👂', title: 'Gesprächspartner finden', desc: 'Menschen, die einfach zuhören und begleiten.' },
        { icon: '🔒', title: 'Anonyme Hilfe', desc: 'Unterstützung ohne Identitätspreisgabe möglich.' },
        { icon: '🌳', title: 'Natur-Treffen', desc: 'Gemeinsame Spaziergänge und Naturerlebnisse.' },
        { icon: '🤝', title: 'Selbsthilfegruppen', desc: 'Lokale Gruppen für gegenseitige Unterstützung.' },
        { icon: '📖', title: 'Ressourcen & Tipps', desc: 'Geprüfte Informationen zu mentaler Gesundheit.' },
        { icon: '☎️', title: 'Professionelle Hilfe', desc: 'Verweise zu lokalen Beratungsstellen und Hilfen.' },
      ]}
    />
  )
}
