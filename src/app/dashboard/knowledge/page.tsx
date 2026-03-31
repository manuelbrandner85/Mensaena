import ModulePageLayout from '@/components/modules/ModulePageLayout'
export default function KnowledgePage() {
  return (
    <ModulePageLayout
      title="Bildung & Wissen"
      subtitle="Wissen teilen, voneinander lernen"
      emoji="🧠"
      description="Teile dein Wissen, finde Guides und Tutorials oder trage mit eigenen Beiträgen zur Community-Wissensbasis bei. Von Naturwissen bis Selbstversorgung."
      accentColor="bg-indigo-100 text-indigo-700"
      createHref="/dashboard/create"
      createLabel="Beitrag verfassen"
      features={[
        { icon: '📚', title: 'Guides & Tutorials', desc: 'Schritt-für-Schritt Anleitungen von der Community.' },
        { icon: '🌿', title: 'Naturwissen', desc: 'Pflanzen, Wildkräuter, Naturheilkunde und mehr.' },
        { icon: '🏡', title: 'Selbstversorgung', desc: 'Tipps zur Eigenversorgung und nachhaltigem Leben.' },
        { icon: '🎓', title: 'Workshops anbieten', desc: 'Biete lokale Workshops und Kurse an.' },
        { icon: '🔬', title: 'Forschung & Natur', desc: 'Wissenschaftliche Erkenntnisse zugänglich machen.' },
        { icon: '✏️', title: 'Eigenes Wissen teilen', desc: 'Schreibe Artikel und teile deine Erfahrungen.' },
      ]}
    />
  )
}
