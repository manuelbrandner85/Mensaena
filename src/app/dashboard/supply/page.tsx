import ModulePageLayout from '@/components/modules/ModulePageLayout'
export default function SupplyPage() {
  return (
    <ModulePageLayout
      title="Regionale Versorgung"
      subtitle="Lokale Produkte und Ernte direkt vermitteln"
      emoji="🌾"
      description="Verbinde dich mit regionalen Bauern und Erzeugern. Kaufe frische Produkte direkt, biete Erntehilfe an oder koordiniere Lieferungen in deiner Region."
      accentColor="bg-yellow-100 text-yellow-700"
      createHref="/dashboard/create"
      createLabel="Angebot einstellen"
      features={[
        { icon: '👨‍🌾', title: 'Bauernprofile', desc: 'Finde lokale Landwirte und ihre Angebote.' },
        { icon: '🥦', title: 'Produkte anbieten', desc: 'Biete frische regionale Produkte direkt an.' },
        { icon: '🚜', title: 'Abholung / Lieferung', desc: 'Koordiniere Abholpunkte oder lokale Lieferungen.' },
        { icon: '🌻', title: 'Erntehilfe', desc: 'Hilf bei der Ernte und erhalte Produkte als Dank.' },
        { icon: '🫙', title: 'Einmachen & Konservieren', desc: 'Tausche Wissen über Konservierung und Lagerung.' },
        { icon: '🌱', title: 'Garten teilen', desc: 'Teile Gartenparzellen oder Saatgut mit anderen.' },
      ]}
    />
  )
}
