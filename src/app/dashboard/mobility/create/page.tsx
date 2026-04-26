'use client'

import { Car } from 'lucide-react'
import CreatePostPage from '@/components/shared/CreatePostPage'

/** Full-Page Create-Formular für das Mobilitäts-Modul */
export default function MobilityCreatePage() {
  return (
    <CreatePostPage
      moduleKey="mobility"
      moduleTitle="Neuer Mobilitäts-Beitrag"
      moduleDescription="Biete Mitfahrgelegenheiten an oder suche eine Fahrt."
      gradientFrom="from-sky-500"
      gradientTo="to-blue-400"
      ringColor="ring-sky-400"
      iconComponent={<Car className="w-6 h-6" />}
      createTypes={[
        { value: 'mobility', label: '🚗 Fahrt anbieten' },
        { value: 'rescue',   label: '🙋 Fahrt gesucht' },
      ]}
      categories={[
        { value: 'mobility', label: 'Mobilität' },
        { value: 'general',  label: 'Allgemein' },
      ]}
      returnRoute="/dashboard/mobility"
    />
  )
}
