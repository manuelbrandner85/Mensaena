import ModulePageLayout from '@/components/modules/ModulePageLayout'
export default function SkillsPage() {
  return (
    <ModulePageLayout
      title="Skill-Netzwerk"
      subtitle="Fähigkeiten teilen und voneinander lernen"
      emoji="🛠️"
      description="Im Skill-Netzwerk verbindest du dich mit Menschen, die deine Fähigkeiten suchen oder die dir etwas beibringen können. Mentoring, Lernen und gegenseitige Unterstützung."
      accentColor="bg-orange-100 text-orange-700"
      createHref="/dashboard/create"
      createLabel="Skill anbieten"
      features={[
        { icon: '💡', title: 'Fähigkeiten anbieten', desc: 'Teile dein Wissen und deine Expertise.' },
        { icon: '🎯', title: 'Hilfe suchen', desc: 'Finde jemanden mit der gesuchten Kompetenz.' },
        { icon: '👨‍🏫', title: 'Mentoring', desc: 'Werde Mentor oder finde einen Mentor.' },
        { icon: '🔄', title: 'Skills tauschen', desc: 'Tausche deine Fähigkeiten gegen andere.' },
        { icon: '📜', title: 'Skill-Profil', desc: 'Präsentiere deine Kompetenzen der Community.' },
        { icon: '🌐', title: 'Online & Vor Ort', desc: 'Lernen digital oder in persönlichen Treffen.' },
      ]}
    />
  )
}
