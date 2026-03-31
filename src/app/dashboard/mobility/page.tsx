import ModulePageLayout from '@/components/modules/ModulePageLayout'
export default function MobilityPage() {
  return (
    <ModulePageLayout
      title="Mobilität"
      subtitle="Mitfahren, transportieren, gemeinsam bewegen"
      emoji="🚗"
      description="Koordiniere Mitfahrten, Transporthilfe und Fahrgemeinschaften in deiner Region. Spare Kosten, schone die Umwelt und verbinde dich mit anderen."
      accentColor="bg-sky-100 text-sky-700"
      createHref="/dashboard/create"
      createLabel="Fahrt anbieten"
      features={[
        { icon: '🚗', title: 'Mitfahrgelegenheiten', desc: 'Biete oder finde Mitfahrten in deiner Region.' },
        { icon: '🚚', title: 'Transporthilfe', desc: 'Hilfe beim Transport von Gütern und Möbeln.' },
        { icon: '🛒', title: 'Einkaufsfahrten', desc: 'Gemeinsam einkaufen und Wege teilen.' },
        { icon: '🏥', title: 'Arztfahrten', desc: 'Begleitung zu Arztbesuchen und Terminen.' },
        { icon: '🚲', title: 'Fahrrad teilen', desc: 'Fahrräder ausleihen oder weitergeben.' },
        { icon: '📍', title: 'Routenplanung', desc: 'Koordiniere Routen und Treffpunkte einfach.' },
      ]}
    />
  )
}
