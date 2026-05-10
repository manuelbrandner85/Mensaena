'use client'

import { Home } from 'lucide-react'
import CreatePostPage from '@/components/shared/CreatePostPage'

/** Full-Page Create-Formular für das Wohn-Modul */
export default function HousingCreatePage() {
  return (
    <CreatePostPage
      moduleKey="housing"
      moduleTitle="Neuer Wohn-Beitrag"
      moduleDescription="Biete Wohnraum an oder suche Unterstützung."
      gradientFrom="from-mn-teal"
      gradientTo="to-mn-teal-soft/8"
      ringColor="ring-mn-teal/30"
      iconComponent={<Home className="w-6 h-6" />}
      createTypes={[
        { value: 'housing', label: '🏠 Wohnung anbieten' },
        { value: 'rescue',  label: '🆘 Wohnungsnot' },
        { value: 'crisis',  label: '⚠️ Krisenwohnung' },
      ]}
      categories={[
        { value: 'housing', label: 'Wohnen' },
        { value: 'general', label: 'Allgemein' },
      ]}
      returnRoute="/dashboard/housing"
    />
  )
}
