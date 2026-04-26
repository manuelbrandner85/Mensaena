'use client'

import { ShieldAlert } from 'lucide-react'
import CreatePostPage from '@/components/shared/CreatePostPage'

/** Full-Page Create-Formular für das Retter-Modul */
export default function RescuerCreatePage() {
  return (
    <CreatePostPage
      moduleKey="rescuer"
      moduleTitle="Neuer Retter-Beitrag"
      moduleDescription="Rette Lebensmittel, Kleidung oder Gegenstände vor der Verschwendung."
      gradientFrom="from-orange-500"
      gradientTo="to-red-400"
      ringColor="ring-orange-400"
      iconComponent={<ShieldAlert className="w-6 h-6" />}
      createTypes={[
        { value: 'rescue',  label: '♻️ Ressource retten', cat: 'food' },
        { value: 'sharing', label: '👕 Kleidung/Gegenstände', cat: 'everyday' },
      ]}
      categories={[
        { value: 'food',     label: 'Lebensmittel' },
        { value: 'everyday', label: 'Alltag' },
        { value: 'sharing',  label: 'Teilen' },
        { value: 'general',  label: 'Allgemein' },
      ]}
      returnRoute="/dashboard/rescuer"
    />
  )
}
