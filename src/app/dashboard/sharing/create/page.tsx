'use client'

import { Repeat } from 'lucide-react'
import CreatePostPage from '@/components/shared/CreatePostPage'

/** Full-Page Create-Formular für das Teilen-Modul */
export default function SharingCreatePage() {
  return (
    <CreatePostPage
      moduleKey="sharing"
      moduleTitle="Neuer Teilen-Beitrag"
      moduleDescription="Biete Gegenstände an, suche etwas oder tausche."
      gradientFrom="from-mn-teal/10"
      gradientTo="to-mn-teal-soft/8"
      ringColor="ring-teal-400"
      iconComponent={<Repeat className="w-6 h-6" />}
      createTypes={[
        { value: 'sharing', label: '🎁 Anbieten' },
        { value: 'rescue',  label: '🔍 Suchen' },
      ]}
      categories={[
        { value: 'sharing',  label: 'Teilen' },
        { value: 'everyday', label: 'Alltag' },
        { value: 'general',  label: 'Allgemein' },
      ]}
      returnRoute="/dashboard/sharing"
    />
  )
}
