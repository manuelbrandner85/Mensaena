'use client'

import { PawPrint } from 'lucide-react'
import CreatePostPage from '@/components/shared/CreatePostPage'

/** Full-Page Create-Formular für das Tierhilfe-Modul */
export default function AnimalsCreatePage() {
  return (
    <CreatePostPage
      moduleKey="animals"
      moduleTitle="Neuer Tierhilfe-Beitrag"
      moduleDescription="Melde ein vermisstes Tier, ein Fundtier oder biete Hilfe an."
      gradientFrom="from-amber-500"
      gradientTo="to-orange-400"
      ringColor="ring-amber-400"
      iconComponent={<PawPrint className="w-6 h-6" />}
      createTypes={[
        { value: 'community', label: '🐾 Tier vermisst', cat: 'animals' },
        { value: 'rescue',    label: '🔍 Tier gefunden', cat: 'animals' },
        { value: 'sharing',   label: '🏠 Tierheim/Pflege', cat: 'animals' },
      ]}
      categories={[
        { value: 'animals', label: 'Tiere' },
        { value: 'general', label: 'Allgemein' },
      ]}
      returnRoute="/dashboard/animals"
    />
  )
}
