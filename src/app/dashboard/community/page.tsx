import ModulePageLayout from '@/components/modules/ModulePageLayout'
export default function CommunityPage() {
  return (
    <ModulePageLayout
      title="Community & Abstimmung"
      subtitle="Gemeinsam entscheiden, gemeinsam gestalten"
      emoji="📢"
      description="Die Community ist der Ort für lokale Abstimmungen, gemeinsame Projekte und demokratische Entscheidungen. Gestalte deine Nachbarschaft aktiv mit."
      accentColor="bg-indigo-100 text-indigo-700"
      createHref="/dashboard/create"
      createLabel="Thema erstellen"
      features={[
        { icon: '🗳️', title: 'Lokale Abstimmungen', desc: 'Abstimme über Themen in deiner Nachbarschaft.' },
        { icon: '🚩', title: 'Probleme melden', desc: 'Melde Probleme in deiner Region öffentlich.' },
        { icon: '💡', title: 'Lösungen vorschlagen', desc: 'Bringe deine Ideen ein und finde Mitstreiter.' },
        { icon: '👥', title: 'Projekte gründen', desc: 'Initiiere lokale Projekte mit anderen.' },
        { icon: '📰', title: 'Lokale Nachrichten', desc: 'Teile relevante Informationen aus der Region.' },
        { icon: '🌐', title: 'Netzwerk aufbauen', desc: 'Verbinde dich mit aktiven Nachbarn.' },
      ]}
    />
  )
}
