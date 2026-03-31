import ModulePageLayout from '@/components/modules/ModulePageLayout'
export default function CrisisPage() {
  return (
    <ModulePageLayout
      title="Krisensystem"
      subtitle="Schnelle Hilfe in Notfallsituationen"
      emoji="🚑"
      description="Das Krisensystem ermöglicht schnelle Hilfe bei Notfällen. Koordiniere Helfer, melde dringende Bedarfe und stelle sicher, dass niemand allein gelassen wird."
      accentColor="bg-red-100 text-red-700"
      createHref="/dashboard/create"
      createLabel="Notfall melden"
      features={[
        { icon: '🆘', title: 'Notfall-Hilfe', desc: 'Sofortige Hilfe bei dringenden Notfällen.' },
        { icon: '⚡', title: 'Schnelle Zuweisung', desc: 'Automatische Benachrichtigung naher Helfer.' },
        { icon: '🍽️', title: 'Essensversorgung', desc: 'Notfall-Versorgung mit Lebensmitteln sicherstellen.' },
        { icon: '🏠', title: 'Notunterkunft', desc: 'Kurzfristige Unterkunftslösungen koordinieren.' },
        { icon: '📞', title: 'Notruf-Koordination', desc: 'Verbindung zu professionellen Helfern.' },
        { icon: '🤲', title: 'Helfer-Netzwerk', desc: 'Aktive Helfer für schnelle Einsätze registrieren.' },
      ]}
    />
  )
}
